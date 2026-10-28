local M = {}

function M.check()
  vim.health.start 'x18n.nvim'

  if vim.fn.has 'nvim-0.11' == 1 then
    vim.health.ok 'Neovim 0.11 or newer'
  else
    vim.health.error 'Neovim 0.11 or newer is required (vim.lsp.config)'
  end

  if vim.fn.executable 'x18n-lsp' == 1 then
    vim.health.ok '`x18n-lsp` found on PATH'
  else
    vim.health.warn '`x18n-lsp` not found — install it with `npm install -g @x18n/lsp`'
  end

  local clients = vim.lsp.get_clients { name = 'x18n' }
  if #clients > 0 then
    vim.health.ok(('x18n-lsp is running (%d instance)'):format(#clients))
  else
    vim.health.info 'not attached in this session — open a buffer in a project x18n recognizes'
  end
end

return M
