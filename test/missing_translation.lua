local ctx = ...

local mirror = require 'x18n.mirror'
local WARN = vim.diagnostic.severity.WARN
local function mirrored()
  return vim.diagnostic.get(ctx.buf, { namespace = mirror.namespace() })
end

--- Neovim 0.12's vim.diagnostic.get ignores the `code` filter; filter here.
local function has_code(bufnr, code)
  for _, d in ipairs(vim.diagnostic.get(bufnr)) do
    if d.code == code then
      return true
    end
  end
  return false
end

assert(
  ctx.wait_for(function()
    return has_code(ctx.buf, 'missing-key')
  end, 8000),
  'missing-key error never arrived'
)
assert(#mirrored() == 0, 'mirror fired before the key existed in the source')

vim.cmd('edit ' .. ctx.playground .. '/locales/en.json')
vim.cmd 'filetype detect'
local en = vim.api.nvim_get_current_buf()
local original = vim.api.nvim_buf_get_lines(en, 0, -1, false)
local lines = vim.deepcopy(original)
for i, line in ipairs(lines) do
  if line:find('"greeting"', 1, true) then
    lines[i] = line .. ','
    table.insert(lines, i + 1, '    "missing": {')
    table.insert(lines, i + 2, '      "key": "Source title"')
    table.insert(lines, i + 3, '    }')
    break
  end
end
vim.api.nvim_buf_set_lines(en, 0, -1, false, lines)

local function code_of(d)
  return tostring(d.code)
end
assert(
  ctx.wait_for(function()
    return not has_code(ctx.buf, 'missing-key')
  end, 8000),
  'missing-key error stayed after adding the source value: '
    .. vim.inspect(vim.tbl_map(code_of, vim.diagnostic.get(ctx.buf)))
)
assert(
  ctx.wait_for(function()
    local d = mirrored()[1]
    return d and d.severity == WARN and d.code == 'missing-translation'
  end, 8000),
  'mirrored warning never reached the code usage'
)

local warning = mirrored()[1]
assert(#mirrored() == 1, 'expected one mirrored warning, got ' .. #mirrored())
assert(warning.lnum == 11, 'mirror landed on the wrong line: ' .. (warning.lnum + 1))
assert(warning.col > 20, 'mirror landed on the wrong column: ' .. warning.col)
for _, locale in ipairs { 'fr', 'ja', 'zh-CN' } do
  assert(warning.message:find(locale, 1, true), 'mirror lost locale ' .. locale .. ': ' .. warning.message)
end
assert(warning.message:find('app.missing.key', 1, true), 'mirror lost the key: ' .. warning.message)

local source_warning
for _, d in ipairs(vim.diagnostic.get(en)) do
  if d.code == 'missing-translation' then
    source_warning = d
  end
end
assert(source_warning and source_warning.severity == WARN, 'server warning missing in en.json')

vim.api.nvim_buf_set_lines(en, 0, -1, false, original)
assert(
  ctx.wait_for(function()
    return has_code(ctx.buf, 'missing-key') and #mirrored() == 0
  end, 8000),
  'mirror did not clear after removing the source key'
)
print 'missing-translation mirror ok'
