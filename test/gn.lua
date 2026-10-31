-- gn keymap: bound per buffer on x18n attach, opens the translations popup on
-- a key and replays the original keys elsewhere.
local ctx = ...

-- On the key.
vim.api.nvim_win_set_cursor(0, { 11, 30 })
local maps = vim.fn.maparg('gn', 'n', false, true)
assert(maps and maps.callback, 'gn not bound on x18n buffers')
maps.callback()
assert(ctx.wait_for(function()
  return vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()):find('x18n$') ~= nil
end, 5000), 'popup never opened from gn')
local first = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, 1, false)[1]
assert(first:find('app%.title', 1, false), 'popup missing key: ' .. first)
vim.cmd 'close'

-- Off a key: replays `gn` through feedkeys instead of opening anything.
local fed = {}
local orig_feedkeys = vim.fn.feedkeys
vim.fn.feedkeys = function(keys, mode)
  fed[#fed + 1] = keys
end
vim.api.nvim_win_set_cursor(0, { 1, 0 })
maps.callback()
vim.fn.feedkeys = orig_feedkeys
assert(fed[1] == 'gn', 'gn off-key did not replay the original keys: ' .. vim.inspect(fed))
print('gn ok')
