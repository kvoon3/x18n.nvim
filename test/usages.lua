-- Key usages: zero hits returns false, one hit jumps directly, several go
-- through the picker, and a locale-file parent key queries the subtree.
local ctx = ...
local usages = require 'x18n.usages'

local function cursor_onto(buf, pattern)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = l:find(pattern, 1, false)
    if col then
      vim.api.nvim_win_set_cursor(0, { i, col - 1 })
      return true
    end
  end
  return false
end

local notes = {}
vim.notify = function(msg)
  notes[#notes + 1] = msg
end

-- No key under the cursor: the message must say so, not "no usages".
vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert(usages.jump_under_cursor() == false, 'plain line reported a usage')
assert(notes[#notes] and notes[#notes]:find('no i18n key', 1, true), 'no-key path did not notify')

-- usage.notify_no_key = false suppresses that warning.
for i = #notes, 1, -1 do
  notes[i] = nil
end
require('x18n').config.usage.notify_no_key = false
assert(usages.jump_under_cursor() == false, 'plain line reported a usage with notify off')
assert(#notes == 0, 'notify_no_key=false still notified')
require('x18n').config.usage.notify_no_key = true

-- One hit: app.title is used once and declared in the locale files.
assert(cursor_onto(ctx.buf, 'app%.title'), 'fixture lost app.title')
local picked = 0
vim.ui.select = function(_, _, on_choice)
  picked = picked + 1
  on_choice(nil)
end
assert(usages.jump_under_cursor() == true, 'single usage did not jump')
assert(picked == 0, 'single usage opened the picker')

-- Several hits: the app subtree in en.json gathers usages of every child key.
vim.cmd('edit ' .. ctx.playground .. '/locales/en.json')
vim.cmd 'filetype detect'
assert(ctx.wait_for(function()
  return vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf(), name = 'x18n' })[1] ~= nil
end, 8000), 'server did not attach to en.json')
assert(cursor_onto(vim.api.nvim_get_current_buf(), 'app'), 'en.json lost the app parent')

local items
vim.ui.select = function(list, _, on_choice)
  items = list
  local target = list[1]
  for _, loc in ipairs(list) do
    -- main.js line 11, app.title, zero-based line 10.
    if loc.range.start.line == 10 then
      target = loc
    end
  end
  on_choice(target)
end
assert(usages.jump_under_cursor() == true, 'prefix usages did not query')
assert(items and #items >= 2, 'prefix query returned ' .. tostring(items and #items or 'nil') .. ' usages')
assert(vim.api.nvim_buf_get_name(0):find('src/main.js', 1, true), 'usage jump left the code file')
assert(vim.api.nvim_win_get_cursor(0)[1] == 11, 'usage jump landed on line ' .. vim.api.nvim_win_get_cursor(0)[1])

-- One usage from a locale-file leaf also jumps: opening the key in en.json
-- lands on its only call site.
vim.cmd('edit ' .. ctx.playground .. '/locales/en.json')
vim.cmd 'filetype detect'
local lbuf = vim.api.nvim_get_current_buf()
assert(ctx.wait_for(function()
  return vim.lsp.get_clients({ bufnr = lbuf, name = 'x18n' })[1] ~= nil
end, 8000), 'server did not attach to en.json for the single-hit check')
assert(cursor_onto(lbuf, 'title'), 'en.json lost the title leaf')
assert(usages.jump_under_cursor() == true, 'single locale-file usage did not jump')
assert(vim.api.nvim_buf_get_name(0):find('src/main.js', 1, true), 'single-hit jump left the code file')
assert(vim.api.nvim_win_get_cursor(0)[1] == 11, 'single-hit jump landed on line ' .. vim.api.nvim_win_get_cursor(0)[1])
print('usages ok')
