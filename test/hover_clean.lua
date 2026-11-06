--[[ The hover markdown: the server omits VS Code command links unless the client
  lists them in init_options.hoverCommands (this plugin lists none). Standard
  hover stays upstream's table; the plugin popup uses x18n/keyInfo instead. ]]
local ctx = ...
local client = vim.lsp.get_clients({ name = 'x18n' })[1]
assert(client, 'no client')

local got = nil
client:request('textDocument/hover', {
  textDocument = { uri = vim.uri_from_bufnr(ctx.buf) },
  position = { line = 10, character = 30 },
}, function(err, result)
  got = { err = err, result = result, value = result and result.contents and result.contents.value }
end)
assert(
  ctx.wait_for(function()
    return got ~= nil
  end, 5000),
  'hover never answered'
)
assert(not got.err, got.err and got.err.message)
assert(got.value:find('app%.title', 1, false), 'hover lost the key')
assert(not got.value:find('command:', 1, true), 'command links not stripped')
assert(got.value:find('1 usage', 1, true), 'usage count missing')
assert(got.value:find('| 🇺🇸 en | Hello x18n |', 1, true), 'locale table row missing: ' .. got.value)
assert(not got.value:find('**en**', 1, true), 'legacy bullet format leaked: ' .. got.value)
assert(got.result.x18n == nil, 'standard hover carried the legacy x18n field')
for _, value in ipairs { 'Hello x18n', '你好 x18n', 'こんにちは x18n', 'Bonjour x18n' } do
  assert(got.value:find(value, 1, true), 'hover lost ' .. value .. ': ' .. got.value)
end
print 'hover clean ok'
