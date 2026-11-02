-- Diagnostics: false clears and suppresses the server's diagnostics, which
-- brings the missing-key arrow back; a table is forwarded to the namespace.
local ctx = ...
local init = require 'x18n'
local lsp = require 'x18n.lsp'
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

local function client()
  return vim.lsp.get_clients({ name = 'x18n' })[1]
end

local function diags()
  local out = {}
  for _, d in ipairs(vim.diagnostic.get(ctx.buf)) do
    if d.source == 'x18n' then
      out[#out + 1] = d
    end
  end
  return out
end

local function missing_arrow()
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })) do
    local vt = m[4].virt_text
    if vt and vt[1][1]:find('missing', 1, true) then
      return true
    end
  end
  return false
end

assert(ctx.wait_for(function() return #diags() > 0 end, 8000), 'baseline diagnostic missing')
assert(not missing_arrow(), 'missing arrow doubled the diagnostic at baseline')

init.config.diagnostic = false
lsp.apply_diagnostics(client())
assert(#diags() == 0, 'diagnostic=false did not clear diagnostics')
decorations.refresh_attached()
assert(ctx.wait_for(function() return missing_arrow() end, 8000), 'missing arrow did not return with diagnostics off')

-- A later publish is filtered too. Count publishes so the assertion cannot
-- pass just because the server never answered.
local active = client()
local original_handler = active.handlers['textDocument/publishDiagnostics']
local publishes = 0
active.handlers['textDocument/publishDiagnostics'] = function(err, result, context, config)
  publishes = publishes + 1
  return original_handler(err, result, context, config)
end
vim.api.nvim_buf_set_lines(ctx.buf, 0, 0, false, { '// poke diagnostics' })
assert(ctx.wait_for(function() return publishes > 0 end, 8000), 'no later publish arrived')
assert(#diags() == 0, 'diagnostic=false let a later publish through')
active.handlers['textDocument/publishDiagnostics'] = original_handler

init.config.diagnostic = true
lsp.apply_diagnostics(client())
vim.api.nvim_buf_set_lines(ctx.buf, 0, 0, false, { '// poke again' })
assert(ctx.wait_for(function() return #diags() > 0 end, 8000), 'diagnostic=true did not restore diagnostics')
decorations.refresh_attached()
assert(ctx.wait_for(function() return not missing_arrow() end, 8000), 'arrow did not yield to the restored diagnostic')

-- A table forwards to the diagnostic namespace.
init.config.diagnostic = { virtual_text = false, signs = false }
lsp.apply_diagnostics(client())
local shown = vim.diagnostic.config(nil, vim.lsp.diagnostic.get_namespace(client().id))
assert(shown.virtual_text == false, 'virtual_text option not applied')
assert(shown.signs == false, 'signs option not applied')
print('diagnostics ok')
