-- Window state: switching between concealed splits must not un-conceal the
-- inactive one, a plain buffer must get the saved level back, and a new split
-- must not inherit the level this module raised.
local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

local main = ctx.playground .. '/src/main.js'
local plain = '/Users/kvoon/i/x18n.nvim/README.md'

local function level(win)
  return vim.wo[win].conceallevel
end

assert(ctx.wait_for(function() return level(vim.api.nvim_get_current_win()) == 2 end, 8000), 'baseline not concealed')

vim.cmd('split ' .. main)
local wins = vim.api.nvim_list_wins()
assert(#wins == 2, 'split did not create two windows')
assert(ctx.wait_for(function()
  for _, win in ipairs(wins) do
    if level(win) ~= 2 then
      return false
    end
  end
  return true
end, 8000), 'both concealed splits are not at level 2')

-- Switching windows leaves the inactive concealed window raised.
vim.cmd 'wincmd w'
assert(ctx.wait_for(function()
  for _, win in ipairs(wins) do
    if level(win) ~= 2 then
      return false
    end
  end
  return true
end, 3000), 'window switch dropped conceal in the inactive window')

-- A plain buffer restores only the window that shows it.
vim.cmd('edit ' .. plain)
vim.cmd 'filetype detect'
assert(ctx.wait_for(function() return level(vim.api.nvim_get_current_win()) == 0 end, 5000), 'plain buffer kept the raised level')
local other
for _, win in ipairs(wins) do
  if win ~= vim.api.nvim_get_current_win() then
    other = win
  end
end
assert(other and level(other) == 2, 'plain edit lowered the other code window')

-- A split from a concealed window starts at the saved level.
vim.cmd('split ' .. main)
assert(ctx.wait_for(function() return level(vim.api.nvim_get_current_win()) == 2 end, 8000), 'new code split not concealed')
vim.cmd('split ' .. plain)
vim.cmd 'filetype detect'
assert(ctx.wait_for(function() return level(vim.api.nvim_get_current_win()) == 0 end, 5000), 'new plain split inherited the raised level')
print('windows ok')
