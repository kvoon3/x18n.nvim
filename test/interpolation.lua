-- Param interpolation: a statically known call argument fills the message
-- placeholder in the inline preview. `const user = 'Ada'` is in the fixture,
-- so the greeting must read `Hello Ada`, not the raw `Hello {name}`.
if vim.env.X18N_UPSTREAM then
  print 'skipped, needs the x18n fork'
  return
end
local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

local row
for i, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
  if line:find('app.greeting', 1, true) then
    row = i - 1
  end
end
assert(row, 'fixture lost the app.greeting call')

local function rendered()
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })) do
    local details = mark[4]
    if mark[2] == row and details.virt_text then
      return details.virt_text[1][1]
    end
  end
end

assert(
  ctx.wait_for(function()
    return rendered() ~= nil
  end, 10000),
  'greeting decoration never rendered'
)
local text = rendered()
assert(text:find('Hello Ada', 1, true), 'call params not interpolated into the preview: ' .. text)
print('param interpolation ok: ' .. text)
