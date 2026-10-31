-- Conceal mode: translated keys render as their value; missing keys keep the
-- arrow form; the conceallevel we raise comes back on toggle-off.
local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

-- Re-setup with conceal mode on the live plugin instance.
decorations.setup { mode = 'conceal', debounce_ms = 100 }
decorations.refresh_attached()

assert(ctx.wait_for(function()
  local marks = vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })
  for _, m in ipairs(marks) do
    if m[4].conceal ~= nil then
      return true
    end
  end
  return false
end, 10000), 'no conceal extmark appeared')

local concealed, arrowed, values = 0, 0, {}
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })) do
  local d = m[4]
  if d.conceal ~= nil then
    concealed = concealed + 1
    assert(d.virt_text_pos == 'inline', 'conceal mark not inline')
    assert(d.virt_text[1][2] == 'X18nValue', 'conceal highlight wrong')
    values[#values + 1] = d.virt_text[1][1]
  elseif d.virt_text and d.virt_text[1][1]:find('→', 1, true) then
    arrowed = arrowed + 1
  end
end
assert(concealed >= 2, ('expected the translated keys concealed, got %d'):format(concealed))
assert(vim.tbl_contains(values, 'Hello x18n'), 'app.title value missing from ' .. table.concat(values, '|'))
-- app.missing.key must stay visible as an arrow.
assert(arrowed >= 1, 'missing key lost its arrow decoration')

-- The quoted literal is fully covered: the conceal range starts at the quote.
local line = vim.api.nvim_buf_get_lines(ctx.buf, 10, 11, false)[1]
local quote_at = line:find("'", 1, true)
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })) do
  if m[4].conceal ~= nil and m[2] == 10 then
    assert(m[3] == quote_at - 1, ('conceal start %d does not cover the opening quote at %d'):format(m[3], quote_at - 1))
  end
end

-- conceallevel was raised in our window, and restored after toggle-off.
assert(vim.wo.conceallevel == 2, 'conceallevel not raised: ' .. vim.wo.conceallevel)
decorations.toggle()
assert(vim.wo.conceallevel == 0, 'conceallevel not restored: ' .. vim.wo.conceallevel)

-- Back to inline mode: arrow decorations return, no conceal marks remain.
decorations.setup { mode = 'inline', debounce_ms = 100 }
decorations.refresh_attached()
assert(ctx.wait_for(function()
  local marks = vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })
  local arrows, concealed = 0, 0
  for _, m in ipairs(marks) do
    if m[4].conceal ~= nil then
      concealed = concealed + 1
    elseif m[4].virt_text and m[4].virt_text[1][1]:find('→', 1, true) then
      arrows = arrows + 1
    end
  end
  return arrows >= 2 and concealed == 0
end, 10000), 'inline mode did not come back after re-setup')
assert(vim.wo.conceallevel == 0, 'inline mode left the conceallevel raised')
print('conceal ok')
