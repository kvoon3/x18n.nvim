local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()
decorations.setup { mode = 'conceal', debounce_ms = 100, show_locale_file_eol_usage = true }

local client = vim.lsp.get_clients({ name = 'x18n' })[1]
assert(client, 'no x18n client after the harness warm-up')

local uri = vim.uri_from_fname(ctx.playground .. '/locales/ja.json')
local stubbed = false
local original = client.request
client.request = function(self, method, params, handler, bufnr)
  if method == 'x18n/fileKeys' and not stubbed and params and params.uri == uri then
    stubbed = true
    vim.schedule(function()
      handler(nil, { keys = {}, hardStrings = {} })
    end)
    return true
  end
  return original(self, method, params, handler, bufnr)
end

vim.cmd('edit ' .. ctx.playground .. '/locales/ja.json')
vim.cmd 'filetype detect'
local lbuf = vim.api.nvim_get_current_buf()

assert(
  ctx.wait_for(function()
    return #vim.api.nvim_buf_get_extmarks(lbuf, ns, 0, -1, {}) >= 2
  end, 15000),
  'a stale empty x18n/fileKeys reply hid the locale file permanently'
)
assert(stubbed, 'the empty reply was never exercised')
client.request = original
print 'locale-file warm-up ok'
