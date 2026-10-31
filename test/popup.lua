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

assert(cursor_onto(ctx.buf, 'app%.title'), 'lost app.title call')
assert(actions.show_translations() == true, 'show_translations returned false on a key')
local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false), '\n')
assert(text:find('app%.title', 1, false), 'popup lost the key: ' .. text)
assert(text:find('Hello x18n', 1, true) and text:find('你好 x18n', 1, true), 'popup lacks both locale values')
vim.cmd 'close'

-- Off a key: returns false so a keymap can fall through.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert(actions.show_translations() == false, 'show_translations true off-key')

-- A key preceded on its own line by multibyte text: the request column must be
-- UTF-16, not a byte offset.
assert(cursor_onto(ctx.buf, 'app%.description'), 'lost app.description call')
assert(actions.show_translations() == true, 'UTF-16 position missed the key after CJK text')
vim.cmd 'close'

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
