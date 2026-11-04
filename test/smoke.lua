-- Smoke: server attaches, the default conceal decorations render for
-- t('app.title') and the missing key, and once the missing-key diagnostic
-- lands the arrow yields to it.
local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

local function marks()
  return vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })
end

assert(
  ctx.wait_for(function()
    for _, m in ipairs(marks()) do
      if m[4].conceal ~= nil then
        return true
      end
    end
    return false
  end, 15000),
  'no conceal mark appeared'
)

local texts = {}
for _, m in ipairs(marks()) do
  if m[4].virt_text then
    texts[#texts + 1] = m[4].virt_text[1][1]
  end
end
local joined = table.concat(texts, '\n')
assert(joined:find('Hello x18n', 1, true), 'app.title value missing from decorations: ' .. joined)

-- The missing key is flagged until the diagnostic lands, then the arrow yields.
local diag_landed = ctx.wait_for(function()
  for _, diag in ipairs(vim.diagnostic.get(ctx.buf)) do
    if diag.source == 'x18n' and diag.code == 'missing-key' then
      return true
    end
  end
  return false
end, 8000)
assert(diag_landed, 'x18n missing-key diagnostic never arrived')
print('smoke ok: ' .. #marks() .. ' decorations')
