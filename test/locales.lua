-- Locale cycling: next() flips en -> zh -> en and decorations follow the server.
local ctx = ...
local decorations = require 'x18n.decorations'

local function marks_text()
  local marks = vim.api.nvim_buf_get_extmarks(ctx.buf, decorations.namespace(), 0, -1, { details = true })
  local out = {}
  for _, m in ipairs(marks) do
    out[#out + 1] = m[4].virt_text[1][1]
  end
  return table.concat(out, '\n')
end

assert(marks_text():find('Hello x18n', 1, true), 'baseline should show the en value')

local next_locale = require('x18n.locales').next()
assert(next_locale == 'zh', ('expected zh, got %s'):format(tostring(next_locale)))

assert(ctx.wait_for(function()
  return marks_text():find('你好 x18n', 1, true)
end, 5000), 'decorations did not switch to zh: ' .. marks_text())

local back = require('x18n.locales').next()
assert(back == 'en', ('expected en, got %s'):format(tostring(back)))
assert(ctx.wait_for(function()
  return marks_text():find('Hello x18n', 1, true)
end, 5000), 'decorations did not switch back to en')

local locales = require('x18n.locales').locales()
assert(#locales == 2 and locales[1] == 'en' and locales[2] == 'zh', 'locale list wrong: ' .. table.concat(locales, ','))
print('locales ok')
