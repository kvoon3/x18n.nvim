-- Locale pairing: keyInfo reports which locales define the key, so a key
-- present in only some locales is paired with the right file. The server no
-- longer labels implementation locations with a non-standard data field.
local ctx = ...
if ctx.upstream then
  print 'skipped, needs the x18n fork'
  return
end
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
vim.wait(5000, function()
  return done
end, 50)
assert(location, 'workspace/symbol did not return app.title')

local impl_done, impl
client:request('textDocument/implementation', {
  textDocument = { uri = location.uri },
  position = location.range.start,
}, function(_, result)
  impl = result
  impl_done = true
end)
vim.wait(5000, function()
  return impl_done
end, 50)
assert(impl and #impl >= 2, 'expected two implementation locations')
for _, loc in ipairs(impl) do
  assert(loc.data == nil, 'implementation location still carries a data field')
end

local pairs_out
locales.key_locations(client, location.uri, location.range.start, function(result)
  pairs_out = result
end)
vim.wait(5000, function()
  return pairs_out ~= nil
end, 25)
assert(pairs_out and #pairs_out == #impl, 'key_locations lost a definition')
local codes = {}
for _, pair in ipairs(pairs_out) do
  assert(pair.code, 'key_locations did not label a definition')
  codes[pair.code] = true
end
for _, code in ipairs { 'en', 'zh-CN', 'ja', 'fr' } do
  assert(codes[code], 'labels do not cover ' .. code)
end

-- A key that exists in only two locales must not be paired by raw index.
local fake = {
  request = function(_, method, _, on_result)
    if method == 'x18n/keyInfo' then
      on_result(nil, {
        locales = {
          { code = 'en', present = true },
          { code = 'zh-CN', present = false },
          { code = 'ja', present = false },
          { code = 'fr', present = true },
        },
      })
    elseif method == 'textDocument/implementation' then
      on_result(nil, {
        {
          uri = 'file:///en.json',
          range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 1 } },
        },
        {
          uri = 'file:///fr.json',
          range = { start = { line = 1, character = 0 }, ['end'] = { line = 1, character = 1 } },
        },
      })
    end
  end,
}
local fake_pairs
locales.key_locations(fake, 'file:///code.js', { line = 0, character = 0 }, function(result)
  fake_pairs = result
end)
assert(#fake_pairs == 2, 'expected two paired locations, got ' .. #fake_pairs)
assert(fake_pairs[1].code == 'en', 'first location paired with ' .. tostring(fake_pairs[1].code))
assert(fake_pairs[2].code == 'fr', 'second location paired with ' .. tostring(fake_pairs[2].code))

-- A count mismatch leaves every label out instead of guessing.
local mismatched = vim.deepcopy(fake)
mismatched.request = function(_, method, _, on_result)
  if method == 'x18n/keyInfo' then
    on_result(nil, { locales = { { code = 'en', present = true } } })
  elseif method == 'textDocument/implementation' then
    on_result(nil, {
      {
        uri = 'file:///en.json',
        range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 1 } },
      },
      {
        uri = 'file:///fr.json',
        range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 1 } },
      },
    })
  end
end
local unlabeled
locales.key_locations(mismatched, 'file:///code.js', { line = 0, character = 0 }, function(result)
  unlabeled = result
end)
assert(#unlabeled == 2, 'expected two unlabeled locations')
for _, pair in ipairs(unlabeled) do
  assert(pair.code == nil, 'mismatched counts produced a label')
end
print 'locations ok'
