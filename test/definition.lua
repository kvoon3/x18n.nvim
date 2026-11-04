-- Definition: the key's locale definitions open the quickfix, the same list
-- as grr, and the chosen entry jumps. A single definition jumps directly.
-- Off a key or without a client nothing is jumped.
local ctx = ...
local actions = require 'x18n.actions'

-- -l mode does not source plugin/ scripts.
vim.cmd 'runtime! plugin/x18n.lua'

local function cursor_onto(pattern)
  local buf = vim.api.nvim_get_current_buf()
  for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = l:find(pattern, 1, false)
    if col then
      vim.api.nvim_win_set_cursor(0, { i, col - 1 })
      return true
    end
  end
  return false
end

local function qf()
  return vim.fn.getqflist { title = 1, items = 1 }
end

local function close_qf()
  pcall(vim.cmd, 'cclose')
end

local function select_qf(index)
  vim.cmd('cc ' .. index)
  close_qf()
end

local main = ctx.playground .. '/src/main.js'

-- Display locale en, but pick fr from the list.
vim.cmd('edit ' .. main)
vim.cmd 'filetype detect'
--[[ A root_dir function resolves after the buffer reload; wait for the client
  to re-attach instead of racing the scheduled start. ]]
assert(
  ctx.wait_for(function()
    return #vim.lsp.get_clients { bufnr = 0, name = 'x18n' } > 0
  end, 5000),
  'no x18n client after re-editing main.js'
)
assert(cursor_onto 'app%.title', 'lost app.title call')
assert(actions.definition() == true, 'definition returned false on a key')
local list = qf()
assert(list.title == 'x18n definitions', 'quickfix title wrong: ' .. tostring(list.title))
assert(#list.items == 4, 'quickfix did not list four definitions: ' .. #list.items)
local function item_name(item)
  return vim.api.nvim_buf_get_name(item.bufnr)
end
assert(list.items[1].text:find('[en (source, display)]', 1, true), 'en item missed its markers: ' .. list.items[1].text)
assert(list.items[2].text:find('[fr]', 1, true), 'fr item missed: ' .. list.items[2].text)
assert(list.items[3].text:find('[ja]', 1, true), 'ja item missed: ' .. list.items[3].text)
assert(list.items[4].text:find('[zh-CN]', 1, true), 'zh-CN item missed: ' .. list.items[4].text)
for i, code in ipairs { 'en', 'fr', 'ja', 'zh-CN' } do
  assert(
    item_name(list.items[i]):find(code .. '.json', 1, true),
    'quickfix item ' .. i .. ' points at ' .. item_name(list.items[i])
  )
end
assert(list.items[4].lnum == 3 and list.items[4].col > 0, 'quickfix lost the entry position')
select_qf(2)
assert(
  vim.api.nvim_buf_get_name(0):find('fr.json', 1, true),
  'definition ignored the chosen entry: ' .. vim.api.nvim_buf_get_name(0)
)
assert(vim.api.nvim_get_current_line():find('Bonjour x18n', 1, true), 'definition landed on the wrong fr value')

-- Display locale ja, but pick zh-CN: the list does not follow the display.
vim.cmd('edit ' .. main)
actions.set_display_locale 'ja'
assert(
  ctx.wait_for(function()
    return require('x18n.locales').display_locale() == 'ja'
  end, 3000),
  'display locale did not switch to ja'
)
assert(cursor_onto 'app%.title', 'lost app.title call after the locale switch')
assert(actions.definition() == true, 'definition returned false after the locale switch')
list = qf()
assert(#list.items == 4, 'quickfix lost locales after the switch')
assert(list.items[3].text:find('[ja (display)]', 1, true), 'ja item missed the display marker: ' .. list.items[3].text)
assert(list.items[1].text:find('[en (source)]', 1, true), 'en item missed the source marker: ' .. list.items[1].text)
assert(list.items[4].text:find('display', 1, true) == nil, 'zh-CN item wrongly claims display: ' .. list.items[4].text)
select_qf(4)
assert(
  vim.api.nvim_buf_get_name(0):find('zh-CN.json', 1, true),
  'definition ignored the chosen entry: ' .. vim.api.nvim_buf_get_name(0)
)
assert(vim.api.nvim_get_current_line():find('你好 x18n', 1, true), 'definition landed on the wrong zh-CN value')

-- The key after CJK text exercises the UTF-16 request column.
vim.cmd('edit ' .. main)
vim.cmd 'filetype detect'
assert(cursor_onto 'app%.description', 'lost app.description call')
assert(actions.definition() == true, 'definition failed after CJK text')
list = qf()
assert(#list.items == 4, 'CJK quickfix did not list four definitions')
select_qf(2)
assert(
  vim.api.nvim_buf_get_name(0):find('fr.json', 1, true),
  'CJK definition ignored the chosen entry: ' .. vim.api.nvim_buf_get_name(0)
)
assert(
  vim.api.nvim_get_current_line():find('Un terrain de jeu pour x18n.nvim', 1, true),
  'CJK definition landed on the wrong value'
)

-- A key present in one locale only skips the quickfix. The cursor lives in a
-- code file, so the jump has to move it to en.json for real.
local client = vim.lsp.get_clients({ name = 'x18n' })[1]
local set_err, set_done = nil, false
client:request('workspace/executeCommand', {
  command = 'x18n.set',
  arguments = { {
    project = 'playground',
    key = 'app.only_en',
    locale = 'en',
    value = 'Only EN',
  } },
}, function(err)
  set_err, set_done = err, true
end)
assert(
  ctx.wait_for(function()
    return set_done
  end, 5000),
  'x18n.set never answered'
)
assert(not set_err, set_err and set_err.message)
local temp = ctx.playground .. '/src/only_en.js'
vim.fn.writefile({
  'export function t(key) { return key }',
  "export const x = t('app.only_en')",
}, temp)
vim.cmd('edit ' .. temp)
vim.cmd 'filetype detect'
local tempbuf = vim.api.nvim_get_current_buf()
assert(
  ctx.wait_for(function()
    return vim.lsp.get_clients({ bufnr = tempbuf, name = 'x18n' })[1] ~= nil
  end, 8000),
  'server did not attach to the one-locale usage'
)
assert(cursor_onto 'app%.only_en', 'could not reach the one-locale usage')
assert(
  ctx.wait_for(function()
    local indexed, done = false, false
    client:request('x18n/fileKeys', { uri = vim.uri_from_bufnr(tempbuf) }, function(_, result)
      for _, key in ipairs(result and result.keys or {}) do
        if key.key == 'app.only_en' then
          indexed = true
        end
      end
      done = true
    end)
    vim.wait(500, function()
      return done
    end, 25)
    return indexed
  end, 8000),
  'server did not index the one-locale usage'
)
vim.fn.setqflist {}
assert(actions.definition() == true, 'one-definition key did not jump')
assert(#vim.fn.getqflist() == 0, 'one-definition key opened the quickfix')
assert(
  vim.api.nvim_buf_get_name(0):find('en.json', 1, true),
  'one-definition jump stayed in ' .. vim.api.nvim_buf_get_name(0)
)
assert(vim.api.nvim_get_current_line():find('only_en', 1, true), 'one-definition jump landed on the wrong line')
vim.fn.delete(temp)
pcall(vim.cmd, 'bwipeout! ' .. tempbuf)

-- Off a key, and without a client, the action declines so gd can fall back.
vim.cmd('edit ' .. main)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.fn.setqflist {}
assert(actions.definition() == false, 'definition returned true off a key')
assert(#vim.fn.getqflist() == 0, 'definition opened the quickfix off a key')

client:stop(true)
assert(
  ctx.wait_for(function()
    return #vim.lsp.get_clients { name = 'x18n' } == 0
  end, 3000),
  'client did not stop'
)
vim.fn.setqflist {}
assert(actions.definition() == false, 'definition returned true without a client')
assert(#vim.fn.getqflist() == 0, 'definition opened the quickfix without a client')

assert(vim.fn.exists ':X18nDefinition' == 2, 'X18nDefinition command missing')
print 'definition ok'
