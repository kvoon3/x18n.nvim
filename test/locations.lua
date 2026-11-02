-- Locale pairing: the fork labels implementation locations with their locale,
-- so a key present in only some locales cannot be paired with the wrong file.
local ctx = ...
local locales = require 'x18n.locales'

local client = require('x18n').get_client()
local location
local done = false
client:request('workspace/symbol', { query = 'app.title' }, function(_, result)
  for _, sym in ipairs(result or {}) do
    if sym.name == 'app.title' then
      location = sym.location
    end
  end
  done = true
end)
vim.wait(5000, function() return done end, 50)
assert(location, 'workspace/symbol did not return app.title')

local impl_done, impl
client:request('textDocument/implementation', {
  textDocument = { uri = location.uri },
  position = location.range.start,
}, function(_, result)
  impl = result
  impl_done = true
end)
vim.wait(5000, function() return impl_done end, 50)
assert(impl and #impl >= 2, 'expected two implementation locations')
local codes = {}
for _, loc in ipairs(impl) do
  assert(loc.data and loc.data.locale, 'implementation location has no locale label')
  codes[loc.data.locale] = true
end
for _, code in ipairs({ 'en', 'zh-CN', 'ja', 'fr' }) do
  assert(codes[code], 'labels do not cover ' .. code)
end

-- A labeled fr location must not be paired with en by index.
local fake = {
  request = function(_, method, _, on_result)
    if method == 'textDocument/hover' then
      on_result(nil, {
        x18n = {
          value = {
            locales = {
              { code = 'en', value = 'a' },
              { code = 'fr', value = 'b' },
            },
          },
        },
      })
    elseif method == 'textDocument/implementation' then
      on_result(nil, {
        {
          uri = 'file:///fr.json',
          range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 1 } },
          data = { locale = 'fr' },
        },
      })
    end
  end,
}
local pairs_out
locales.key_locations(fake, 'file:///code.js', { line = 0, character = 0 }, function(result)
  pairs_out = result
end)
assert(#pairs_out == 1, 'expected one paired location, got ' .. #pairs_out)
assert(pairs_out[1].code == 'fr', 'labeled location paired with ' .. pairs_out[1].code)
print('locations ok')
