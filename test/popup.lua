-- ShowTranslations popup (all locales for the key) and explain float.
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

-- The native float records itself on the parent buffer.
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
assert(ctx.wait_for(function()
  return hover_buf() ~= nil
end, 5000), 'popup never opened')
local text = table.concat(vim.api.nvim_buf_get_lines(hover_buf(), 0, -1, false), '\n')
assert(text:find('app%.title', 1, false), 'popup lost the key: ' .. text)
assert(text:find('Hello x18n', 1, true) and text:find('你好 x18n', 1, true), 'popup lacks both locale values')
-- The reformatted hover: no markdown table pipes, no URL-encoded links.
assert(not text:find('|', 1, true), 'raw markdown pipes leaked: ' .. text)
assert(not text:find('%5B', 1, true), 'encoded command link leaked: ' .. text)
assert(text:find('usage', 1, true), 'usage line missing')
-- The native float stays open until the cursor moves in the parent window.
assert(hover_buf() ~= nil, 'hover float missing before the move')
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = ctx.buf })
assert(ctx.wait_for(function()
  return hover_buf() == nil
end, 3000), 'hover float did not close on cursor move')

-- Off a key: returns false so a keymap can fall through.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert(actions.show_translations() == false, 'show_translations true off-key')

-- A key preceded on its own line by multibyte text: the request column must be
-- UTF-16, not a byte offset.
assert(cursor_onto(ctx.buf, 'app%.description'), 'lost app.description call')
assert(actions.show_translations() == true, 'UTF-16 position missed the key after CJK text')
assert(ctx.wait_for(function()
  return hover_buf() ~= nil
end, 5000), 'CJK popup never opened')
close_hover()

actions.explain()
assert(ctx.wait_for(function()
  return vim.api.nvim_buf_get_name(0):find('x18n explain') ~= nil
end, 5000), 'explain float never opened')
local explained = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false), '\n')
assert(#explained > 0, 'explain float empty')

-- A second float in the same session must not trip over the first buffer's name.
vim.cmd 'close'
require('x18n.status').show()
assert(vim.api.nvim_buf_get_name(0):find('x18n status') ~= nil, 'second float failed to open')
print('popup/explain ok')
