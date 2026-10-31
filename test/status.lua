-- Status: float lists project, locales with progress, display locale.
local ctx = ...
require('x18n.status').show()

local buf = vim.api.nvim_get_current_buf()
local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
assert(text:find('playground', 1, true), 'project name missing: ' .. text)
assert(text:find('en', 1, true) and text:find('zh', 1, true), 'locales missing: ' .. text)
assert(text:find('source', 1, true), 'source locale marker missing: ' .. text)
-- zh lacks nothing in the fixture (both keys translated); missing count appears when >0.
assert(text:find('display locale', 1, true), 'display locale missing: ' .. text)
print('status ok')
