-- gd keymap: the plugin binds it per x18n buffer, opens the locale
-- definitions quickfix on a key, and keeps the previous definition binding
-- elsewhere. A later client's plain gd is reclaimed without wrapping the chain.
local ctx = ...
local actions = require 'x18n.actions'

local function qf()
  return vim.fn.getqflist({ title = 1, items = 1 })
end

local function close_qf()
  pcall(vim.cmd, 'cclose')
end

local function select_qf(index)
  vim.cmd('cc ' .. index)
  close_qf()
end

assert(ctx.wait_for(function()
  local map = vim.fn.maparg('gd', 'n', false, true)
  return map ~= nil and map.callback ~= nil
end, 5000), 'gd not bound on x18n buffers')
local map = vim.fn.maparg('gd', 'n', false, true)
assert(map.desc and map.desc:find('x18n', 1, true), 'gd desc: ' .. tostring(map.desc))

-- On the key: the locale definitions quickfix, then the chosen jump.
vim.api.nvim_win_set_cursor(0, { 11, 30 })
map.callback()
local list = qf()
assert(list.title == 'x18n definitions', 'gd quickfix title: ' .. tostring(list.title))
assert(#list.items == 4, 'gd did not list four definitions: ' .. #list.items)
select_qf(2)
assert(vim.api.nvim_buf_get_name(0):find('fr.json', 1, true), 'gd did not jump to fr: ' .. vim.api.nvim_buf_get_name(0))
assert(vim.api.nvim_get_current_line():find('Bonjour x18n', 1, true), 'gd landed on the wrong value')

-- Off the key: the captured definition binding.
vim.cmd('edit ' .. ctx.playground .. '/src/main.js')
vim.cmd 'filetype detect'
vim.api.nvim_win_set_cursor(0, { 1, 0 })
local defined = 0
local original = vim.lsp.buf.definition
vim.lsp.buf.definition = function()
  defined = defined + 1
end
map = vim.fn.maparg('gd', 'n', false, true)
map.callback()
vim.lsp.buf.definition = original
assert(defined == 1, 'gd off-key did not fall back to definition: ' .. defined)

-- A later client's LspAttach rebinds gd plain; the x18n re-chain reclaims it
-- and keeps the original fallback instead of wrapping the clobber.
vim.keymap.set('n', 'gd', original, { buffer = ctx.buf, desc = 'plain clobber' })
actions.default_keymaps(ctx.buf)
map = vim.fn.maparg('gd', 'n', false, true)
assert(map.desc and map.desc:find('x18n', 1, true), 're-chain did not reclaim gd: ' .. tostring(map.desc))

vim.api.nvim_win_set_cursor(0, { 11, 30 })
map.callback()
list = qf()
assert(#list.items == 4, 'gd did not list after the clobber: ' .. #list.items)
select_qf(2)
assert(vim.api.nvim_buf_get_name(0):find('fr.json', 1, true), 'gd did not jump after the clobber: ' .. vim.api.nvim_buf_get_name(0))

vim.cmd('edit ' .. ctx.playground .. '/src/main.js')
vim.api.nvim_win_set_cursor(0, { 1, 0 })
defined = 0
vim.lsp.buf.definition = function()
  defined = defined + 1
end
map = vim.fn.maparg('gd', 'n', false, true)
map.callback()
vim.lsp.buf.definition = original
assert(defined == 1, 'gd fallback chained twice after clobber: ' .. defined)
print('gd keymap ok')