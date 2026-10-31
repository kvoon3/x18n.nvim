-- Key picker: entries come from workspace/symbol with key, value, location;
-- the jump action lands in the locale file, copy fills the register.
local ctx = ...
local keys = require 'x18n.keys'

local captured
vim.ui.select = function(items, opts, on_choice)
  captured = { items = items, opts = opts }
  for _, item in ipairs(items) do
    if item.key == 'app.title' then
      on_choice(item)
      return
    end
  end
  on_choice(nil)
end

keys.pick 'copy_key'
assert(ctx.wait_for(function() return captured ~= nil end, 5000), 'picker never received entries')
assert(#captured.items >= 2, 'picker got no entries')
assert(vim.fn.getreg '+' == 'app.title', 'copy_key failed: ' .. vim.fn.getreg '+')
local title_entry
for _, item in ipairs(captured.items) do
  if item.key == 'app.title' then
    title_entry = item
  end
end
assert(title_entry.value:find('Hello', 1, true), 'source value missing from entry: ' .. title_entry.value)

vim.cmd 'enew'
keys.pick 'jump'
assert(ctx.wait_for(function()
  return vim.api.nvim_buf_get_name(0):find('locales' .. '/' .. 'en%.json')
end, 5000), 'jump did not open en.json: ' .. vim.api.nvim_buf_get_name(0))
local line = vim.api.nvim_get_current_line()
assert(line:find('title', 1, true), 'cursor not on the title key: ' .. line)
print('keys ok')
