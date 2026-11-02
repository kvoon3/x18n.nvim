-- gh keymap: bound per buffer on x18n attach (scheduled, so it wins the
-- ordering race with a plain gh from other LspAttach hooks), opens the
-- translations popup on a key and falls back to the previous binding
-- elsewhere.
local ctx = ...

-- The schedule needs one event-loop pass after attach.
assert(ctx.wait_for(function()
  local m = vim.fn.maparg('gh', 'n', false, true)
  return m ~= nil and m.callback ~= nil
end, 5000), 'gh not bound on x18n buffers')

-- On the key.
vim.api.nvim_win_set_cursor(0, { 11, 30 })
local maps = vim.fn.maparg('gh', 'n', false, true)
maps.callback()
local function close_hover()
  local win = vim.b[ctx.buf].lsp_floating_preview
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end
local function hover_buf()
  local win = vim.b[ctx.buf].lsp_floating_preview
  if win and vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_get_buf(win)
  end
end
assert(ctx.wait_for(function()
  return hover_buf() ~= nil
end, 5000), 'popup never opened from gh')
local first = vim.api.nvim_buf_get_lines(hover_buf(), 0, 1, false)[1]
assert(first:find('app%.title', 1, false), 'popup missing key: ' .. first)
close_hover()

-- Off a key: falls back to the hover that was there before (here: the default
-- vim.lsp.buf.hover captured at bind time).
local hovered = {}
local orig_hover = vim.lsp.buf.hover
vim.lsp.buf.hover = function()
  hovered[#hovered + 1] = true
end
maps = vim.fn.maparg('gh', 'n', false, true)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
maps.callback()
vim.lsp.buf.hover = orig_hover
assert(#hovered == 1, 'gh off-key did not fall back to hover')

-- A later client's LspAttach rebinds gh plain (as the user's own config does
-- when the TS server attaches); the x18n re-chain must reclaim it and keep the
-- original fallback, not wrap the clobbered map.
vim.keymap.set('n', 'gh', orig_hover, { buffer = ctx.buf, desc = 'plain clobber' })
require('x18n.actions').default_keymaps(ctx.buf)
hovered = {}
local orig_hover2 = vim.lsp.buf.hover
vim.lsp.buf.hover = function()
  hovered[#hovered + 1] = true
end
maps = vim.fn.maparg('gh', 'n', false, true)
assert(maps.desc and maps.desc:find('x18n', 1, true), 're-chain did not reclaim gh: ' .. tostring(maps.desc))

-- On a key again after the clobber: popup, not hover.
vim.api.nvim_win_set_cursor(0, { 11, 30 })
maps.callback()
assert(ctx.wait_for(function()
  return hover_buf() ~= nil
end, 5000), 'popup did not survive the clobber')
close_hover()

-- Off a key after the clobber: exactly one hover call, no chain stacking.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
maps = vim.fn.maparg('gh', 'n', false, true)
maps.callback()
vim.lsp.buf.hover = orig_hover2
assert(#hovered == 1, 'fallback chained twice after clobber: ' .. #hovered)
print('gh ok')
