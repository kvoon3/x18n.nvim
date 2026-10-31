--[[ Self-contained playground: no user config, no installed plugin.

    From the repository root:

        cd playground && npm install
        nvim -u playground/init.lua

    The local x18n-lsp from playground/node_modules/.bin is put on PATH, the
    repository itself is prepended to 'runtimepath', and the plugin is set up
    with the defaults you are developing. Use `:X18nDisplayLocale ja` and `K`
    to explore. ]]
local here = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
local repo = vim.fn.fnamemodify(here, ':h')

vim.opt.runtimepath:prepend(repo)
vim.env.PATH = here .. '/node_modules/.bin:' .. vim.env.PATH

vim.o.background = 'dark'
vim.o.termguicolors = true
vim.o.number = true
vim.o.signcolumn = 'yes'

pcall(vim.cmd.colorscheme, 'habamax')

if vim.fn.executable 'x18n-lsp' == 0 then
  vim.notify('[playground] x18n-lsp not found — run `npm install` in playground/', vim.log.levels.WARN)
end

require('x18n').setup {}

-- Uncomment to print protocol traffic in the command line.
-- vim.g.x18n_debug = true

--[[ Open the demo after startup: editing inside init.lua runs before filetype
  detection is registered, which leaves the buffer without a filetype and the
  language server is never enabled. ]]
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.cmd.edit(vim.fn.fnameescape(here .. '/src/main.ts'))
    vim.cmd('filetype detect')
  end,
})
