-- The hover markdown: the server omits VS Code command links unless the client
-- lists them in init_options.hoverCommands (this plugin lists none), and the
-- client handler strips any that still arrive (upstream servers).
local ctx = ...
local client = vim.lsp.get_clients({ name = 'x18n' })[1]
assert(client, 'no client')

local got = nil
client:request('textDocument/hover', {
  textDocument = { uri = vim.uri_from_bufnr(ctx.buf) },
  position = { line = 10, character = 30 },
}, function(err, result)
  got = { err = err, value = result and result.contents and result.contents.value }
end)
assert(ctx.wait_for(function() return got ~= nil end, 5000), 'hover never answered')
assert(not got.err, got.err and got.err.message)
assert(got.value:find('app%.title', 1, false), 'hover lost the key')
assert(not got.value:find('command:', 1, true), 'command links not stripped')
assert(got.value:find('1 usage', 1, true), 'usage count missing')
-- The fork's hover markdown is a bullet list; no pipe tables anywhere.
assert(not got.value:find('|', 1, true), 'table pipes leaked: ' .. got.value)
assert(got.value:find('%- .*en', 1, false), 'locale bullet missing')
for _, value in ipairs({ 'Hello x18n', '你好 x18n', 'こんにちは x18n', 'Bonjour x18n' }) do
  assert(got.value:find(value, 1, true), 'hover lost ' .. value .. ': ' .. got.value)
end
-- The fork's structured field rides along untouched.
local struct = nil
client:request('textDocument/hover', {
  textDocument = { uri = vim.uri_from_bufnr(ctx.buf) },
  position = { line = 10, character = 30 },
}, function(_, result)
  struct = result and result.x18n and result.x18n.value
end)
assert(ctx.wait_for(function() return struct ~= nil end, 5000), 'structured x18n field never arrived')
assert(struct.key == 'app.title', 'structured key wrong: ' .. tostring(struct.key))
assert(#struct.locales == 4, 'structured locales wrong: ' .. tostring(#struct.locales))
print('hover clean ok')
