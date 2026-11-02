-- Status: float lists project, locales with progress, display locale.
local ctx = ...
require('x18n.status').show()

local function status_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative ~= '' then
      local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false), '\n')
      if text:find('display locale') then
        return w
      end
    end
  end
end
assert(ctx.wait_for(function() return status_win() ~= nil end, 5000), 'status float never opened')
local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(status_win()), 0, -1, false), '\n')
assert(text:find('playground', 1, true), 'project name missing: ' .. text)
assert(text:find('en', 1, true) and text:find('zh', 1, true), 'locales missing: ' .. text)
assert(text:find('source', 1, true), 'source locale marker missing: ' .. text)
-- zh lacks nothing in the fixture (both keys translated); missing count appears when >0.
assert(text:find('display locale', 1, true), 'display locale missing: ' .. text)
print('status ok')
