-- Navigation: edit, split, vsplit and tabedit change the window layout while
-- landing on the same location, and the configured default is honoured.
local ctx = ...
local util = require 'x18n.util'

local location
local done = false
require('x18n').get_client():request('workspace/symbol', { query = 'app.title' }, function(err, result)
  for _, sym in ipairs(result or {}) do
    if sym.name == 'app.title' then
      location = sym.location
      break
    end
  end
  done = true
end)
vim.wait(5000, function() return done end, 50)
assert(location, 'workspace/symbol did not return app.title')

local main = ctx.playground .. '/src/main.js'
local function back_to_code()
  vim.cmd('edit ' .. main)
  vim.cmd 'only'
end

back_to_code()
assert(#vim.api.nvim_list_wins() == 1, 'expected one window')
assert(util.jump(location, 'vsplit'), 'vsplit jump failed')
assert(#vim.api.nvim_list_wins() == 2, 'vsplit did not split')
assert(vim.api.nvim_buf_get_name(0):find('en.json', 1, true), 'vsplit landed in the wrong buffer')
assert(vim.api.nvim_get_current_line():find('title', 1, true), 'vsplit cursor missed the key')

back_to_code()
assert(util.jump(location, 'split'), 'split jump failed')
assert(#vim.api.nvim_list_wins() == 2, 'split did not split')
assert(vim.api.nvim_buf_get_name(0):find('en.json', 1, true), 'split landed in the wrong buffer')

back_to_code()
local tabs = vim.fn.tabpagenr '$'
assert(util.jump(location, 'tabedit'), 'tabedit jump failed')
assert(vim.fn.tabpagenr '$' == tabs + 1, 'tabedit did not open a tab')
assert(vim.api.nvim_buf_get_name(0):find('en.json', 1, true), 'tabedit landed in the wrong buffer')
vim.cmd 'tabclose'

back_to_code()
require('x18n').config.navigation.open_cmd = 'vsplit'
assert(util.jump(location), 'default jump failed')
assert(#vim.api.nvim_list_wins() == 2, 'navigation.open_cmd was ignored')
require('x18n').config.navigation.open_cmd = 'edit'

back_to_code()
assert(util.jump(location, 'not-a-command'), 'invalid open_cmd jump failed')
assert(#vim.api.nvim_list_wins() == 1, 'invalid open_cmd opened a window')
assert(vim.api.nvim_buf_get_name(0):find('en.json', 1, true), 'invalid open_cmd did not edit')
print('navigation ok')
