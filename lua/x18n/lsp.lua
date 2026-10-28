local M = {}

--- Register the x18n language server with the native LSP stack.
---@param opts vim.lsp.Config User overrides merged on top of the plugin defaults.
---@param on_changed function Called on the server's x18n/changed notification.
function M.setup(opts, on_changed)
  opts = vim.deepcopy(opts)
  opts.name = 'x18n'
  opts.handlers = opts.handlers or {}

  --[[ The server pushes locale-file changes as a custom notification; decorations
    subscribe through this hook instead of polling. ]]
  local user_handler = opts.handlers['x18n/changed']
  opts.handlers['x18n/changed'] = function(err, result, ctx)
    if user_handler then
      user_handler(err, result, ctx)
    end
    if on_changed then
      on_changed()
    end
  end

  vim.lsp.config('x18n', opts)
  vim.lsp.enable('x18n')
end

return M
