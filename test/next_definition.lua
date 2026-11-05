local ctx = ...
local actions = require 'x18n.actions'

local titles = {
  en = 'Hello x18n',
  fr = 'Bonjour x18n',
  ja = 'こんにちは x18n',
  ['zh-CN'] = '你好 x18n',
}

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
  return (vim.api.nvim_buf_get_name(0):match '[^/]+$')
end

local order = require('x18n.locales').locales()
assert(#order == 4 and order[1] == 'en', 'unexpected locale order: ' .. table.concat(order, ','))

assert(cursor_onto(ctx.buf, 'app%.title'), 'lost app.title call')
actions.next_definition()
assert(
  ctx.wait_for(function()
    return current_name() == order[1] .. '.json'
  end, 5000),
  'first jump missed ' .. order[1] .. '.json: ' .. current_name()
)
assert(vim.api.nvim_get_current_line():find(titles[order[1]], 1, true), 'first jump landed on the wrong value')
for i = 2, #order do
  actions.next_definition()
  assert(
    ctx.wait_for(function()
      return current_name() == order[i] .. '.json'
    end, 5000),
    ('jump %d missed %s.json: %s'):format(i, order[i], current_name())
  )
  assert(
    vim.api.nvim_get_current_line():find(titles[order[i]], 1, true),
    ('jump %d landed on the wrong value in %s'):format(i, order[i])
  )
end
actions.next_definition()
assert(
  ctx.wait_for(function()
    return current_name() == order[1] .. '.json'
  end, 5000),
  'wrap missed ' .. order[1] .. '.json: ' .. current_name()
)
assert(vim.api.nvim_get_current_line():find(titles[order[1]], 1, true), 'wrap landed on the wrong value')

assert(cursor_onto(vim.api.nvim_get_current_buf(), 'title'), 'lost title key in ' .. order[1] .. '.json')
actions.next_definition()
assert(
  ctx.wait_for(function()
    return current_name() == order[2] .. '.json'
  end, 5000),
  'locale-file jump missed ' .. order[2] .. '.json: ' .. current_name()
)
assert(vim.api.nvim_get_current_line():find(titles[order[2]], 1, true), 'locale-file jump landed on the wrong value')
print 'next_definition ok'
