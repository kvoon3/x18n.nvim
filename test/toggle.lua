-- Toggle: decorations clear on toggle-off and come back on toggle-on.
local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

local function count()
  return #vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, {})
end
assert(count() >= 2, 'baseline decorations missing')

assert(decorations.toggle() == false, 'toggle should report off')
assert(count() == 0, 'decorations not cleared by toggle-off')

-- An event-driven refresh while disabled must not re-render.
vim.api.nvim_buf_set_lines(ctx.buf, 0, 0, false, { '// poke' })
ctx.wait_for(function() return false end, 600)
assert(count() == 0, 'refresh fired while disabled')

assert(decorations.toggle() == true, 'toggle should report on')
assert(ctx.wait_for(function() return count() >= 2 end), 'decorations did not return after toggle-on')
print('toggle ok')
