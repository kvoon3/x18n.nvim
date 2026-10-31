-- Smoke: server attaches, decorations render for t('app.title') and the missing
-- key, and once the missing-key diagnostic lands the arrow yield to it.
local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

local function mark_texts()
  local out = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })) do
    out[#out + 1] = m[4].virt_text[1][1]
  end
  return out
end

assert(ctx.wait_for(function()
  local texts = mark_texts()
  return #texts >= 2 and table.concat(texts, '\n'):find('Hello x18n', 1, true)
end, 15000), 'decorations missing: ' .. table.concat(mark_texts(), '|'))

-- The missing key is flagged by the arrow until the diagnostic lands, then the
-- arrow yields. Either state is correct; both silent states are not.
local texts = mark_texts()
local joined = table.concat(texts, '\n')
local diag_landed = ctx.wait_for(function()
  for _, diag in ipairs(vim.diagnostic.get(ctx.buf)) do
    if diag.source == 'x18n' and diag.code == 'missing-key' then
      return true
    end
  end
  return false
end, 8000)
assert(diag_landed, 'x18n missing-key diagnostic never arrived')
texts = mark_texts()
joined = table.concat(texts, '\n')
assert(joined:find('missing', 1, true) or #texts == 2, ('missing key invisible and no diagnostic coverage: %s'):format(joined))
print('smoke ok: ' .. #texts .. ' decorations')
