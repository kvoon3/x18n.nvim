local ctx = ...

local main_uri = vim.uri_from_fname(ctx.playground .. '/src/main.js')
local en_uri = vim.uri_from_fname(ctx.playground .. '/locales/en.json')

require('x18n.report').show {
  missing = {
    {
      project = 'playground',
      key = 'app.missing',
      locations = {
        { uri = main_uri, range = { start = { line = 11, character = 29 } } },
        { uri = main_uri, range = { start = { line = 12, character = 0 } } },
      },
    },
  },
  unused = {
    {
      project = 'playground',
      key = 'app.unused',
      location = { uri = en_uri, range = { start = { line = 2, character = 4 } } },
    },
  },
}

local items = vim.fn.getqflist()
assert(#items == 3, 'expected 3 quickfix items, got ' .. #items)
local function name(item)
  return item.filename or vim.api.nvim_buf_get_name(item.bufnr)
end
assert(name(items[1]):find('locales/en.json', 1, true), 'unused item lost its file')

local missing = {}
for _, item in ipairs(items) do
  if item.text:find('[missing]', 1, true) then
    missing[#missing + 1] = item
  end
end
assert(#missing == 2, 'missing usage sites collapsed into ' .. #missing)
assert(missing[1].lnum ~= missing[2].lnum, 'missing usage sites share a line')
for _, item in ipairs(missing) do
  assert(name(item):find('src/main.js', 1, true), 'missing item lost its file')
end

vim.fn.setqflist {}
require('x18n.report').run()
assert(
  ctx.wait_for(function()
    return #vim.fn.getqflist() > 0
  end, 8000),
  'usageReport never populated the quickfix'
)

local report_items = vim.fn.getqflist()
local real_missing = 0
for _, item in ipairs(report_items) do
  if item.text:find('[missing]', 1, true) then
    real_missing = real_missing + 1
    assert(name(item) ~= '', 'real missing item has no file')
  end
end
assert(real_missing >= 1, 'real usageReport lost its missing key')
print 'report ok'
