-- Next-locale definition: cycles en.json -> zh.json -> en.json for one key,
-- from both a code file and from inside a locale file.
local ctx = ...
local actions = require 'x18n.actions'

local function cursor_onto(buf, pattern)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = l:find(pattern, 1, false)
    if col then
      vim.api.nvim_win_set_cursor(0, { i, col + 1 })
      return true
    end
  end
  return false
end

local function current_name()
  return (vim.api.nvim_buf_get_name(0):match('[^/]+$'))
end

-- From the code file.
assert(cursor_onto(ctx.buf, 'app%.title'), 'lost app.title call')
actions.next_definition()
assert(ctx.wait_for(function() return current_name() == 'en.json' end, 5000), 'first jump missed en.json: ' .. current_name())
actions.next_definition()
assert(ctx.wait_for(function() return current_name() == 'zh.json' end, 5000), 'second jump missed zh.json: ' .. current_name())
actions.next_definition()
assert(ctx.wait_for(function() return current_name() == 'en.json' end, 5000), 'wrap missed en.json: ' .. current_name())

-- From inside a locale file, onto the key line.
assert(cursor_onto(vim.api.nvim_get_current_buf(), 'title'), 'lost title key in en.json')
actions.next_definition()
assert(ctx.wait_for(function() return current_name() == 'zh.json' end, 5000), 'locale-file jump missed zh.json: ' .. current_name())
print('next_definition ok')
