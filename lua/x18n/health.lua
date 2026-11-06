local M = {}

local lsp = require 'x18n.lsp'

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
    local bufnr
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.lsp.buf_is_attached(buf, clients[1].id) then
        bufnr = buf
        break
      end
    end
    if bufnr then
      local done, supported = false, nil
      lsp.custom_request(clients[1], 'x18n/keyInfo', {
        uri = vim.uri_from_bufnr(bufnr),
        position = { line = 0, character = 0 },
      }, function(err)
        supported = err == nil
        done = true
      end)
      vim.wait(1000, function()
        return done
      end, 25)
      if not done then
        vim.health.warn 'x18n/keyInfo probe timed out'
      elseif supported then
        vim.health.ok 'x18n/keyInfo available (extended UI enabled)'
      else
        vim.health.warn 'x18n/keyInfo not available; the popup, copy translation and per-locale add menu will fall back'
      end
    else
      vim.health.info 'no attached buffer to probe x18n/keyInfo'
    end
  else
    vim.health.info 'not attached in this session — open a buffer in a project x18n recognizes'
  end
end

return M
