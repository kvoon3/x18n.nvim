local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

decorations.setup { mode = 'conceal', debounce_ms = 100, cursor_redraw_ms = 20 }
decorations.refresh_attached()

local function marks(buf)
  return vim.api.nvim_buf_get_extmarks(buf or ctx.buf, ns, 0, -1, { details = true })
end

local function row_of(buf, pattern)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(buf or ctx.buf, 0, -1, false)) do
    if l:find(pattern) then
      return i - 1
    end
  end
  error('no row matches ' .. pattern)
end

local greeting = row_of(nil, 'app%.title')
local broken = row_of(nil, 'app%.missing%.key')

local function shape(row)
  local has_conceal, has_eol, has_arrow = false, false, false
  for _, m in ipairs(marks()) do
    if m[2] == row then
      if m[4].virt_text_pos == 'eol' then
        has_eol = true
      end
      if m[4].conceal ~= nil then
        has_conceal = true
      end
      if m[4].virt_text and m[4].virt_text[1][1]:find('→', 1, true) then
        has_arrow = true
      end
    end
  end
  if has_conceal and has_eol then
    return 'cursor'
  end
  if has_conceal then
    return 'concealed'
  end
  if has_arrow then
    return 'arrow'
  end
  return 'none'
end

assert(
  ctx.wait_for(function()
    return shape(greeting) == 'concealed'
  end, 10000),
  'greeting never took the concealed shape: ' .. shape(greeting)
)
assert(vim.wo.conceallevel == 2, 'conceallevel not raised')

local line = vim.api.nvim_buf_get_lines(ctx.buf, greeting, greeting + 1, false)[1]
local quote_at = line:find("'", 1, true)
for _, m in ipairs(marks()) do
  if m[4].conceal ~= nil and m[2] == greeting then
    assert(m[3] == quote_at - 1, ('conceal start %d misses the opening quote at %d'):format(m[3], quote_at - 1))
  end
end

assert(
  ctx.wait_for(function()
    local has_diag = false
    for _, diag in ipairs(vim.diagnostic.get(ctx.buf)) do
      if diag.source == 'x18n' and diag.lnum == broken then
        has_diag = true
      end
    end
    return has_diag and shape(broken) == 'none'
  end, 10000),
  'missing key did not yield to the diagnostic: ' .. shape(broken)
)

vim.api.nvim_win_set_cursor(0, { greeting + 1, 10 })
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = ctx.buf })
assert(
  ctx.wait_for(function()
    return shape(greeting) == 'cursor'
  end, 5000),
  'cursor line did not take the arrow shape: ' .. shape(greeting)
)
local eol_text
for _, m in ipairs(marks()) do
  if m[2] == greeting and m[4].virt_text_pos == 'eol' then
    eol_text = m[4].virt_text[1][1]
  end
end
assert(eol_text == '→ Hello x18n', 'eol arrow text wrong: ' .. tostring(eol_text))

vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = ctx.buf })
assert(
  ctx.wait_for(function()
    return shape(greeting) == 'concealed'
  end, 5000),
  'line did not return to the concealed shape: ' .. shape(greeting)
)

decorations.toggle()
assert(vim.wo.conceallevel == 0, 'conceallevel not restored')

decorations.setup { mode = 'inline', debounce_ms = 100 }
decorations.refresh_attached()
assert(
  ctx.wait_for(function()
    local n = 0
    for _, m in ipairs(marks()) do
      if m[4].conceal ~= nil then
        return false
      end
      if m[4].virt_text and m[4].virt_text[1][1]:find('→', 1, true) then
        n = n + 1
      end
    end
    return n >= 2
  end, 10000),
  'inline mode did not come back'
)
print 'conceal ok'
