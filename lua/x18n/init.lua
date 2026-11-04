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
      'html',
      'php',
      'blade',
      'eruby',
      'ruby',
      'json',
      'yaml',
    },
    root_markers = {
      'x18n.config.ts',
      'x18n.config.yml',
      'x18n.config.json',
      'package.json',
      'composer.json',
      'Gemfile',
      '.git',
    },
    init_options = { showFlags = true },
  },
  decorations = {
    enabled = true,
    --[[ 'conceal' (default) reads the key as its value, t(Hello x18n), and the
      cursor's line falls back to the raw key with an end-of-line arrow. The
      i18n.nvim names both, translation, translation_conceal and origin work
      too; 'inline' puts the value after the call and 'eol' parks it at the end
      of the line. ]]
    mode = 'conceal',
    --[[ Locale files show the usage count at the end of each key line. Set
      show_locale_file_eol_translation = true to also show the display-locale
      value. ]]
    show_locale_file_eol_translation = false,
    show_locale_file_eol_usage = true,
    debounce_ms = 400,
    cursor_redraw_ms = 100,
  },
  --[[ How definition, usage and picker jumps open a file. ]]
  navigation = {
    open_cmd = 'edit',
  },
  --[[ Keymaps inside the translations float. copy_key accepts one string or a
    list of strings. ]]
  translation_popup = {
    keys = {
      copy_key = { '<C-y>' },
    },
  },
  --[[ Diagnostic presentation. false suppresses x18n diagnostics and clears the
    ones already shown; a table is forwarded to vim.diagnostic.config for the
    server's namespace. Missing-key arrows return when diagnostics are off. ]]
  diagnostic = true,
  usage = {
    --[[ :X18nKeyUsages warns when the cursor is not on a key; upstream exposes
      the same switch. ]]
    notify_no_key = true,
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
  local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'x18n' }
  if #clients == 0 then
    clients = vim.lsp.get_clients { name = 'x18n' }
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
      require('x18n.locales').warm()
      require('x18n.decorations').refresh_attached()
    end)
    --[[ actions.lua loads lazily (first command); an autocmd registered there
      would miss the attach, so setup wires the default keymaps itself. Every
      attach re-runs the chain, scheduled: another client's LspAttach (the TS
      server attaches after x18n) rebinds `gh`/`gd` plain, and the schedule
      lands after all synchronous hooks, so the x18n chain ends up on top. ]]
    local group = vim.api.nvim_create_augroup('x18n_keymaps', { clear = true })
    vim.api.nvim_create_autocmd('LspAttach', {
      group = group,
      callback = function(a)
        local client = vim.lsp.get_client_by_id(a.data.client_id)
        if client and client.name == 'x18n' then
          require('x18n.lsp').apply_diagnostics(client)
        end
        vim.schedule(function()
          if #vim.lsp.get_clients { bufnr = a.buf, name = 'x18n' } > 0 then
            require('x18n.actions').default_keymaps(a.buf)
          end
        end)
      end,
    })
  end
  if type(M.config.decorations) == 'table' and M.config.decorations.enabled then
    require('x18n.decorations').setup(M.config.decorations)
  end
end

return M
