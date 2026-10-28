local M = {}

local defaults = {
  --[[ false opts out of the built-in lsp setup entirely (manage vim.lsp.config yourself). ]]
  lsp = {
    cmd = { 'x18n-lsp', '--stdio' },
    filetypes = {
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
      'vue',
      'svelte',
      'json',
      'yaml',
    },
    root_markers = { 'x18n.config.ts', 'x18n.config.yml', 'x18n.config.json', 'package.json', '.git' },
    init_options = { showFlags = true },
  },
  decorations = {
    enabled = true,
    --[[ 'inline' shows the translation right after the t('key') call, VS Code style;
      'eol' keeps code alignment intact by parking it at the end of the line. ]]
    virt_text_pos = 'inline',
    debounce_ms = 400,
  },
}

M.config = vim.deepcopy(defaults)

---@param msg string
---@param level integer?
function M.notify(msg, level)
  vim.notify('[x18n] ' .. msg, level or vim.log.levels.INFO)
end

--- Debug logging, enabled with `vim.g.x18n_debug = true`.
function M.debug(...)
  if vim.g.x18n_debug then
    print('[x18n]', ...)
  end
end

--- The client attached to a buffer, falling back to any x18n client.
--- Usage report, search and tree are workspace-level, so the commands also
--- work from buffers the server never attached to (e.g. plain Markdown).
---@param bufnr integer?
---@return vim.lsp.Client?
function M.client(bufnr)
  bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'x18n' })
  if #clients == 0 then
    clients = vim.lsp.get_clients({ name = 'x18n' })
  end
  return clients[1]
end

--- Like M.client but notifies (and returns nil) when the server is not running.
---@param bufnr integer?
---@return vim.lsp.Client?
function M.get_client(bufnr)
  local client = M.client(bufnr)
  if not client then
    M.notify('x18n-lsp is not running in this session', vim.log.levels.WARN)
  end
  return client
end

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts)

  if M.config.lsp then
    require('x18n.lsp').setup(M.config.lsp, function()
      require('x18n.decorations').refresh_attached()
    end)
  end
  if type(M.config.decorations) == 'table' and M.config.decorations.enabled then
    require('x18n.decorations').setup(M.config.decorations)
  end
end

return M
