local source = assert(debug.getinfo(1, 'S').source, 'x18n dev: no source path')
assert(source:sub(1, 1) == '@', 'x18n dev: run this file with -u')

local root = vim.fn.fnamemodify(source:sub(2), ':p:h:h')
vim.opt.runtimepath = { root, vim.env.VIMRUNTIME }
vim.opt.packpath = { vim.env.VIMRUNTIME }
vim.cmd 'filetype plugin indent on'
vim.cmd 'syntax enable'
vim.o.termguicolors = true

local server = root .. '/node_modules/@x18n/lsp/bin.mjs'
local cmd
if vim.uv.fs_stat(server) then
  cmd = { 'node', server, '--stdio' }
else
  cmd = { 'x18n-lsp', '--stdio' }
  vim.notify('x18n dev: node_modules/@x18n/lsp is missing; using x18n-lsp from PATH', vim.log.levels.WARN)
end

require('x18n').setup { lsp = { cmd = cmd } }

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.notify('x18n dev: ' .. root)
  end,
})
