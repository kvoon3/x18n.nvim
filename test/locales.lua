-- Locale cycling: the server reports locales as en, fr, ja, zh-CN; next()
-- walks that order and wraps. The values are derived from the reported list.
local ctx = ...
local decorations = require 'x18n.decorations'

local function marks_text()
  local marks = vim.api.nvim_buf_get_extmarks(ctx.buf, decorations.namespace(), 0, -1, { details = true })
  local out = {}
  for _, m in ipairs(marks) do
    if m[4].virt_text then
      out[#out + 1] = m[4].virt_text[1][1]
    end
  end
  return table.concat(out, '\n')
end

local values = {
  en = { 'Hello x18n', 'A playground for x18n.nvim' },
  fr = { 'Bonjour x18n', 'Un terrain de jeu pour x18n.nvim' },
  ja = { 'こんにちは x18n', 'x18n.nvim の実験場' },
  ['zh-CN'] = { '你好 x18n', 'x18n.nvim 的试验场' },
}
local function rendered(code)
  local text = marks_text()
  return text:find(values[code][1], 1, true) and text:find(values[code][2], 1, true)
end

assert(rendered 'en', 'baseline should show both en values')

local module = require 'x18n.locales'
local list = module.locales()
assert(#list == 4 and list[1] == 'en', 'locale list wrong: ' .. table.concat(list, ','))
for i = 2, #list do
  local got = module.next()
  assert(got == list[i], ('expected %s, got %s'):format(list[i], tostring(got)))
  assert(ctx.wait_for(function()
    return rendered(list[i])
  end, 5000), ('decorations did not switch to %s: %s'):format(list[i], marks_text()))
end

local wrapped = module.next()
assert(wrapped == list[1], ('expected wrap to %s, got %s'):format(list[1], tostring(wrapped)))
assert(ctx.wait_for(function()
  return rendered(list[1])
end, 5000), 'decorations did not switch back to ' .. list[1])

assert(#module.locales() == 4, 'locale list changed during the cycle')
print('locales ok')