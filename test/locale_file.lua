-- Locale files: EOL virtual text shows the display-locale value of each key.
local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

vim.cmd('edit ' .. ctx.playground .. '/locales/zh.json')
vim.cmd 'filetype detect'
assert(vim.bo.filetype == 'json', 'json filetype expected, got ' .. vim.bo.filetype)
local lbuf = vim.api.nvim_get_current_buf()

assert(ctx.wait_for(function()
  local marks = vim.api.nvim_buf_get_extmarks(lbuf, ns, 0, -1, { details = true })
  return #marks >= 2
end, 10000), 'locale file got no EOL decorations')

local marks = vim.api.nvim_buf_get_extmarks(lbuf, ns, 0, -1, { details = true })
local texts = {}
for _, m in ipairs(marks) do
  assert(m[4].virt_text_pos == 'eol', 'locale-file mark not EOL')
  texts[#texts + 1] = m[4].virt_text[1][1]
end
local joined = table.concat(texts, '\n')
-- Display locale defaults to the source locale (en).
assert(joined:find('Hello x18n', 1, true), 'expected en value at EOL: ' .. joined)
assert(joined:find('A playground', 1, true), 'expected second en value at EOL: ' .. joined)

-- Switching the display locale re-renders the locale file with zh values.
require('x18n.locales').next()
assert(ctx.wait_for(function()
  local m2 = vim.api.nvim_buf_get_extmarks(lbuf, ns, 0, -1, { details = true })
  if #m2 < 2 then
    return false
  end
  for _, m in ipairs(m2) do
    if m[4].virt_text[1][1]:find('你好', 1, true) then
      return true
    end
  end
  return false
end, 5000), 'EOL decorations did not follow display locale to zh')
print('locale-file ok')
