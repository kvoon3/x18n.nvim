local M = {}

-- The resolved config, kept for manual start after :X18nEnable/:X18nReload.
M.config = nil

--- Build a root_dir function from marker names. An x18n config anywhere upward
--- wins first (a monorepo config must not lose to a nested package.json), then
--- the nearest ancestor containing any marker wins. Native vim.fs.root applies
--- markers in list order, so a repo-root package.json can shadow a closer
--- composer.json or Gemfile.
---@param markers (string|fun(bufnr: integer):boolean)[]
---@return fun(bufnr: integer, on_dir: fun(dir?: string))
function M.root_dir_for(markers)
  local names, configs, has_function = {}, {}, false
  for _, marker in ipairs(markers) do
    if type(marker) == 'string' then
      names[#names + 1] = marker
      if marker:match '^x18n%.config%.' then
        configs[#configs + 1] = marker
      end
    else
      has_function = true
    end
  end
  return function(bufnr, on_dir)
    local path = vim.api.nvim_buf_get_name(bufnr)
    if path == '' or path:match '^%w+://' then
      return
    end
    if #configs > 0 then
      local found = vim.fs.find(configs, { upward = true, path = vim.fs.dirname(path), type = 'file' })[1]
      if found then
        return on_dir(vim.fs.dirname(found))
      end
    end
    if has_function then
      --[[ A marker predicate cannot be stat'ed here; let Neovim resolve the
        whole list. ]]
      local root = vim.fs.root(bufnr, markers)
      if root then
        return on_dir(root)
      end
      return
    end
    for dir in vim.fs.parents(path) do
      for _, marker in ipairs(names) do
        if vim.uv.fs_stat(dir .. '/' .. marker) then
          return on_dir(dir)
        end
      end
    end
  end
end

--- Register the x18n language server with the native LSP stack.
---@param opts vim.lsp.Config User overrides merged on top of the plugin defaults.
---@param on_changed function Called on the server's x18n/changed notification.
function M.setup(opts, on_changed)
  opts = vim.deepcopy(opts)
  opts.name = 'x18n'
  opts.handlers = opts.handlers or {}

  --[[ Resolve the configured markers ourselves (see root_dir_for): native
    vim.fs.root treats the marker list in order, so an ancestor package.json
    wins over a closer composer.json or Gemfile. ]]
  if not opts.root_dir and type(opts.root_markers) == 'table' then
    opts.root_dir = M.root_dir_for(opts.root_markers)
  end

  --[[ Diagnostics are pushed by the server. When the plugin option is false,
    empty every publish and reset what is already on screen. The raw payload
    also feeds the mirror that puts target-locale warnings on code usages. ]]
  local user_diagnostics = opts.handlers['textDocument/publishDiagnostics']
  opts.handlers['textDocument/publishDiagnostics'] = function(err, result, ctx, config)
    local diagnostics = require('x18n').config.diagnostic
    if diagnostics == false and result then
      result = vim.tbl_extend('force', result, { diagnostics = {} })
    end
    if diagnostics ~= false then
      --[[ A publish notification carries its file in the payload; handler
        contexts do not always fill ctx.uri. ]]
      local uri = ctx.uri or (result and result.uri)
      require('x18n.mirror').observe(ctx.client_id, uri, result and result.diagnostics or {})
    end
    if user_diagnostics then
      return user_diagnostics(err, result, ctx, config)
    end
    return vim.lsp.handlers['textDocument/publishDiagnostics'](err, result, ctx, config)
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

  M.config = opts
  vim.lsp.config('x18n', opts)
  vim.lsp.enable 'x18n'
end

--- Apply the plugin's diagnostic option to a client's diagnostic namespace.
---@param client vim.lsp.Client
function M.apply_diagnostics(client)
  local ns = vim.lsp.diagnostic.get_namespace(client.id)
  local mirror = require 'x18n.mirror'
  local opts = require('x18n').config.diagnostic
  if opts == false then
    vim.diagnostic.reset(ns)
    mirror.clear_all()
    vim.diagnostic.config({
      virtual_text = false,
      signs = false,
      underline = false,
      update_in_insert = false,
    }, ns)
  elseif type(opts) == 'table' then
    vim.diagnostic.config(opts, ns)
    --[[ The mirrored warning is a presentation choice too; carry the user's
      diagnostic table over to its namespace. ]]
    vim.diagnostic.config(opts, mirror.namespace())
  end
end

--- Start the client for a buffer, reusing a running client for the same root.
---@param bufnr integer?
---@return integer? client id
function M.start(bufnr)
  if not M.config then
    return nil
  end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root = M.config.root_dir
  if type(root) == 'function' then
    local done, resolved = false, nil
    root(bufnr, function(dir)
      resolved = dir
      done = true
    end)
    vim.wait(100, function()
      return done
    end, 10)
    root = resolved
  end
  root = root or vim.fs.root(bufnr, M.config.root_markers or {})
  if not root then
    return nil
  end
  local cfg = vim.deepcopy(M.config)
  cfg.root_dir = root
  return vim.lsp.start(cfg)
end

--- Stop every x18n client in this session.
function M.stop()
  for _, client in ipairs(vim.lsp.get_clients { name = 'x18n' }) do
    client:stop(true)
  end
end

return M
