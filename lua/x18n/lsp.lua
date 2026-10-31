local M = {}

--- Register the x18n language server with the native LSP stack.
---@param opts vim.lsp.Config User overrides merged on top of the plugin defaults.
---@param on_changed function Called on the server's x18n/changed notification.
function M.setup(opts, on_changed)
  opts = vim.deepcopy(opts)
  opts.name = 'x18n'
  opts.handlers = opts.handlers or {}

  --[[ The server's hover markdown ends in VS Code `command:` links, URL-encoded
    JSON args that wrap across half a float in Neovim. Editors that render the
    markdown (hover, eagle mouse window) get them stripped to their link text;
    the structured x18n field and the raw table stay untouched. ]]
  local user_hover = opts.handlers['textDocument/hover']
  opts.handlers['textDocument/hover'] = function(err, result, ctx, config)
    if result and result.contents and result.contents.kind == 'markdown' then
      result.contents.value = result.contents.value:gsub('%[([^%]]*)%]%((command:[^)]*)%)', '%1')
    end
    if user_hover then
      return user_hover(err, result, ctx, config)
    end
    return vim.lsp.handlers['textDocument/hover'](err, result, ctx, config)
  end

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
