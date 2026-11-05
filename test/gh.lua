local ctx = ...
if ctx.upstream then
  assert(
    ctx.wait_for(function()
      local m = vim.fn.maparg('gh', 'n', false, true)
      return m ~= nil and m.callback ~= nil
    end, 5000),
    'gh not bound on x18n buffers'
  )
  local hovered = false
  local orig_hover = vim.lsp.buf.hover
  vim.lsp.buf.hover = function()
    hovered = true
  end
  local maps = vim.fn.maparg('gh', 'n', false, true)
  vim.api.nvim_win_set_cursor(0, { 11, 30 })
  maps.callback()
  vim.lsp.buf.hover = orig_hover
  assert(hovered, 'gh on a key did not fall back to native hover')
  print 'gh fallback ok'
  return
end

assert(
  ctx.wait_for(function()
    local m = vim.fn.maparg('gh', 'n', false, true)
    return m ~= nil and m.callback ~= nil
  end, 5000),
  'gh not bound on x18n buffers'
)

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
assert(
  ctx.wait_for(function()
    return hover_buf() ~= nil
  end, 5000),
  'popup never opened from gh'
)
local first = vim.api.nvim_buf_get_lines(hover_buf(), 0, 1, false)[1]
assert(first:find('app%.title', 1, false), 'popup missing key: ' .. first)
close_hover()

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

vim.keymap.set('n', 'gh', orig_hover, { buffer = ctx.buf, desc = 'plain clobber' })
require('x18n.actions').default_keymaps(ctx.buf)
hovered = {}
local orig_hover2 = vim.lsp.buf.hover
vim.lsp.buf.hover = function()
  hovered[#hovered + 1] = true
end
maps = vim.fn.maparg('gh', 'n', false, true)
assert(maps.desc and maps.desc:find('x18n', 1, true), 're-chain did not reclaim gh: ' .. tostring(maps.desc))

vim.api.nvim_win_set_cursor(0, { 11, 30 })
maps.callback()
assert(
  ctx.wait_for(function()
    return hover_buf() ~= nil
  end, 5000),
  'popup did not survive the clobber'
)
close_hover()

vim.api.nvim_win_set_cursor(0, { 1, 0 })
maps = vim.fn.maparg('gh', 'n', false, true)
maps.callback()
vim.lsp.buf.hover = orig_hover2
assert(#hovered == 1, 'fallback chained twice after clobber: ' .. #hovered)
print 'gh ok'
