local _ = ...

local reports = {}
local function record(level)
  return function(message)
    reports[#reports + 1] = level .. ': ' .. message
  end
end
vim.health.start = record 'start'
vim.health.ok = record 'ok'
vim.health.warn = record 'warn'
vim.health.error = record 'error'
vim.health.info = record 'info'

require('x18n.health').check()

local client = vim.lsp.get_clients({ name = 'x18n' })[1]
assert(client, 'no x18n client')
local version = client.server_info and client.server_info.version
assert(version, 'server reported no version')
local text = table.concat(reports, '\n')
assert(text:find('x18n-lsp ' .. version, 1, true), 'health did not report the server version: ' .. text)
assert(not text:find('older than', 1, true), 'health flagged the current server as old: ' .. text)
print('health ok: ' .. version)
