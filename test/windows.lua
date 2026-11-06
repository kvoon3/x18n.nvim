local ctx = ...

local main = ctx.playground .. '/src/main.js'
local plain = ctx.plugin_root .. '/README.md'

local function level(win)
  return vim.wo[win].conceallevel
end

assert(
  ctx.wait_for(function()
    return level(vim.api.nvim_get_current_win()) == 2
  end, 8000),
  'baseline not concealed'
)

vim.cmd('split ' .. main)
local wins = vim.api.nvim_list_wins()
assert(#wins == 2, 'split did not create two windows')
assert(
  ctx.wait_for(function()
    for _, win in ipairs(wins) do
      if level(win) ~= 2 then
        return false
      end
    end
    return true
  end, 8000),
  'both concealed splits are not at level 2'
)

vim.cmd 'wincmd w'
assert(
  ctx.wait_for(function()
    for _, win in ipairs(wins) do
      if level(win) ~= 2 then
        return false
      end
    end
    return true
  end, 3000),
  'window switch dropped conceal in the inactive window'
)

vim.cmd('edit ' .. plain)
vim.cmd 'filetype detect'
assert(
  ctx.wait_for(function()
    return level(vim.api.nvim_get_current_win()) == 0
  end, 5000),
  'plain buffer kept the raised level'
)
local other
for _, win in ipairs(wins) do
  if win ~= vim.api.nvim_get_current_win() then
    other = win
  end
end
assert(other and level(other) == 2, 'plain edit lowered the other code window')

vim.cmd('split ' .. main)
assert(
  ctx.wait_for(function()
    return level(vim.api.nvim_get_current_win()) == 2
  end, 8000),
  'new code split not concealed'
)
vim.cmd('split ' .. plain)
vim.cmd 'filetype detect'
assert(
  ctx.wait_for(function()
    return level(vim.api.nvim_get_current_win()) == 0
  end, 5000),
  'new plain split inherited the raised level'
)
print 'windows ok'
