local ctx = ...
local actions = require 'x18n.actions'

local function cursor_onto(buf, pattern)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = l:find(pattern, 1, false)
    if col then
      vim.api.nvim_win_set_cursor(0, { i, col + 1 })
      return true
    end
  end
  return false
end

local function hover_buf()
  local win = vim.b[ctx.buf].lsp_floating_preview
  if win and vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_get_buf(win)
  end
end

local function close_hover()
  local win = vim.b[ctx.buf].lsp_floating_preview
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

assert(cursor_onto(ctx.buf, 'app%.title'), 'lost app.title call')
assert(actions.show_translations() == true, 'show_translations returned false on a key')
assert(
  ctx.wait_for(function()
    return hover_buf() ~= nil
  end, 5000),
  'popup never opened'
)
local text = table.concat(vim.api.nvim_buf_get_lines(hover_buf(), 0, -1, false), '\n')
assert(text:find('app%.title', 1, false), 'popup lost the key: ' .. text)
assert(text:find('Hello x18n', 1, true), 'popup lost Hello x18n')
for _, value in ipairs { '你好 x18n', 'こんにちは x18n', 'Bonjour x18n' } do
  assert(text:find(value, 1, true), 'popup lost ' .. value .. ': ' .. text)
end
assert(not text:find('|', 1, true), 'raw markdown pipes leaked: ' .. text)
assert(not text:find('%5B', 1, true), 'encoded command link leaked: ' .. text)
assert(text:find('usage', 1, true), 'usage line missing')

local fbuf = hover_buf()
assert(
  ctx.wait_for(function()
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(fbuf, 'n')) do
      if m.lhs == '<C-Y>' then
        return true
      end
    end
    return false
  end, 3000),
  'popup copy-key map missing'
)
local parent_win = vim.api.nvim_get_current_win()
local fwin = vim.b[ctx.buf].lsp_floating_preview
assert(fwin and vim.api.nvim_win_is_valid(fwin), 'float window missing')
vim.api.nvim_set_current_win(fwin)
vim.fn.setreg('"', '')
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-y>', true, false, true), 'x', false)
assert(vim.fn.getreg '"' == 'app.title', 'popup copy-key copied: ' .. vim.fn.getreg '"')
vim.api.nvim_set_current_win(parent_win)

assert(hover_buf() ~= nil, 'hover float missing before the move')
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = ctx.buf })
assert(
  ctx.wait_for(function()
    return hover_buf() == nil
  end, 3000),
  'hover float did not close on cursor move'
)

require('x18n').config.translation_popup.keys.copy_key = '<C-g>'
assert(cursor_onto(ctx.buf, 'app%.title'), 'lost app.title call for the custom map')
assert(actions.show_translations() == true, 'custom-map popup did not open')
assert(
  ctx.wait_for(function()
    local fb = hover_buf()
    if not fb then
      return false
    end
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(fb, 'n')) do
      if m.lhs == '<C-G>' then
        return true
      end
    end
    return false
  end, 5000),
  'translation_popup.keys.copy_key was ignored'
)
close_hover()

vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert(actions.show_translations() == false, 'show_translations true off-key')

assert(cursor_onto(ctx.buf, 'app%.description'), 'lost app.description call')
assert(actions.show_translations() == true, 'UTF-16 position missed the key after CJK text')
assert(
  ctx.wait_for(function()
    return hover_buf() ~= nil
  end, 5000),
  'CJK popup never opened'
)
local cjk_text = table.concat(vim.api.nvim_buf_get_lines(hover_buf(), 0, -1, false), '\n')
for _, value in ipairs {
  'A playground for x18n.nvim',
  'x18n.nvim の実験場',
  'x18n.nvim 的试验场',
  'Un terrain de jeu pour x18n.nvim',
} do
  assert(cjk_text:find(value, 1, true), 'description popup lost ' .. value .. ': ' .. cjk_text)
end
close_hover()

local function float_with(content_pattern)
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(w)
    if cfg.relative ~= '' then
      local content = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false), '\n')
      if content:find(content_pattern) then
        return w
      end
    end
  end
end

actions.explain()
assert(
  ctx.wait_for(function()
    return float_with 'presets:' ~= nil or float_with 'finders:' ~= nil
  end, 5000),
  'explain float never opened'
)
vim.api.nvim_win_close(float_with 'presets:' or float_with 'finders:', true)

require('x18n.status').show()
assert(
  ctx.wait_for(function()
    return float_with 'display locale' ~= nil
  end, 5000),
  'status float failed to open'
)
print 'popup/explain ok'
