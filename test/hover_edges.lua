-- keyInfo resolves the whole call, the closing paren, and the end-of-line
-- annotation. Standard hover stays strict to the key literal.
local ctx = ...
if ctx.upstream then
  print 'skipped, needs the x18n fork'
  return
end
local client = require('x18n').get_client()
local util = require 'x18n.util'

local function request(method, params)
  local done, result
  client:request(method, params, function(err, r)
    result = not err and r or nil
    done = true
  end)
  vim.wait(5000, function()
    return done
  end, 25)
  return result
end

local function key_at(target_buf, line0, character)
  local result = request('x18n/keyInfo', {
    uri = vim.uri_from_bufnr(target_buf),
    position = { line = line0, character = character },
  })
  return result and result.key or nil
end

local function hover_at(target_buf, line0, character)
  return request('textDocument/hover', {
    textDocument = { uri = vim.uri_from_bufnr(target_buf) },
    position = { line = line0, character = character },
  }) ~= nil
end

-- main.js line 11 (zero-based 10): export const greeting = t('app.title')
local line = vim.api.nvim_buf_get_lines(ctx.buf, 10, 11, false)[1]
assert(line:find 'app%.title', 'fixture lost the app.title call')
local key_start = line:find "'app%.title'"
assert(key_start, 'fixture lost the quoted key')

assert(hover_at(ctx.buf, 10, key_start), 'key literal hover failed')
assert(not hover_at(ctx.buf, 10, key_start + #"'app.title'"), 'standard hover escaped the key literal')
assert(not hover_at(ctx.buf, 10, #line), 'standard hover resolved the line end')
assert(key_at(ctx.buf, 10, key_start) == 'app.title', 'key literal keyInfo failed')
assert(key_at(ctx.buf, 10, key_start + #"'app.title'") == 'app.title', 'closing paren keyInfo failed')
assert(key_at(ctx.buf, 10, #line) == 'app.title', 'line-end keyInfo failed')
assert(key_at(ctx.buf, 10, key_start - 5) == nil, 'keyInfo before the call resolved a key')
assert(key_at(ctx.buf, 0, 1) == nil, 'plain line resolved a key')

-- A fixture with trailing comments: the expression ends before the line end,
-- so these positions exercise the line-end fallback. The CJK line proves the
-- UTF-16 column conversion; the nested line proves the innermost call wins.
local temp = ctx.playground .. '/src/hover_edges.js'
vim.fn.writefile({
  'export function t(key) { return key }',
  "export const one = t('app.title') // trailing comment",
  "export const cjk = pad('中文前缀') + t('app.description') // 注释",
  "export const nested = t('app.title', { x: t('app.description') }) // two keys",
}, temp)
vim.cmd('edit ' .. temp)
vim.cmd 'filetype detect'
local tbuf = vim.api.nvim_get_current_buf()
assert(
  ctx.wait_for(function()
    return #vim.lsp.get_clients { bufnr = tbuf, name = 'x18n' } > 0
  end, 8000),
  'server did not attach to the hover fixture'
)
assert(
  ctx.wait_for(function()
    local done, found = false, false
    client:request('x18n/fileKeys', { uri = vim.uri_from_bufnr(tbuf) }, function(_, result)
      for _, key in ipairs(result and result.keys or {}) do
        if key.key == 'app.title' then
          found = true
        end
      end
      done = true
    end)
    vim.wait(1000, function()
      return done
    end, 25)
    return found
  end, 8000),
  'hover fixture was not indexed'
)

local l1 = vim.api.nvim_buf_get_lines(tbuf, 1, 2, false)[1]
local l2 = vim.api.nvim_buf_get_lines(tbuf, 2, 3, false)[1]
local l3 = vim.api.nvim_buf_get_lines(tbuf, 3, 4, false)[1]

local one = l1:find "'app%.title'"
assert(key_at(tbuf, 1, one) == 'app.title', 'trailing-comment key keyInfo failed')
assert(key_at(tbuf, 1, #l1) == 'app.title', 'trailing-comment line-end keyInfo failed')
assert(key_at(tbuf, 1, #l1 - 1) == 'app.title', 'trailing-comment last-char keyInfo failed')
assert(key_at(tbuf, 1, 0) == nil, 'keyInfo before the trailing-comment call resolved a key')

local cjk_end = util.to_utf16(tbuf, 2, #l2)
assert(key_at(tbuf, 2, cjk_end) == 'app.description', 'CJK line-end keyInfo failed')

local inner = l3:find "'app%.description'"
local inner_close = inner + #"'app.description'"
local outer_t = l3:find('t(', 1, true)
assert(key_at(tbuf, 3, inner) == 'app.description', 'nested inner key resolved wrong')
assert(key_at(tbuf, 3, inner_close - 1) == 'app.description', 'nested inner paren resolved wrong')
assert(key_at(tbuf, 3, outer_t - 1) == 'app.title', 'outer call start resolved wrong')
assert(key_at(tbuf, 3, #l3) == nil, 'ambiguous line end resolved a key')

-- The plugin popup follows the same keyInfo. The cursor can sit on the last
-- character of the trailing comment, which the line-end fallback covers.
vim.api.nvim_win_set_cursor(0, { 2, #l1 - 1 })
assert(require('x18n.actions').show_translations() == true, 'show_translations missed the line-end key')
assert(
  ctx.wait_for(function()
    local win = vim.b[tbuf].lsp_floating_preview
    return win and vim.api.nvim_win_is_valid(win)
  end, 3000),
  'line-end popup never opened'
)
local popup = vim.b[tbuf].lsp_floating_preview
local popup_text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(popup), 0, -1, false), '\n')
assert(popup_text:find('app%.title', 1, false), 'line-end popup lost the key')
vim.api.nvim_win_close(popup, true)
vim.fn.delete(temp)
pcall(vim.cmd, 'bwipeout! ' .. tbuf)

-- Locale files: the EOL annotation sits after the line, so its column is the
-- line length. The single key on the line answers.
vim.cmd('edit ' .. ctx.playground .. '/locales/en.json')
vim.cmd 'filetype detect'
local lbuf = vim.api.nvim_get_current_buf()
assert(
  ctx.wait_for(function()
    return vim.lsp.get_clients({ bufnr = lbuf, name = 'x18n' })[1] ~= nil
  end, 8000),
  'server did not attach to en.json'
)
local title_line = vim.api.nvim_buf_get_lines(lbuf, 2, 3, false)[1]
assert(title_line:find('title', 1, true), 'fixture lost the title line')
assert(key_at(lbuf, 2, #title_line) == 'app.title', 'locale line-end keyInfo failed')
print 'hover edges ok'
