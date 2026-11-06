local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

vim.cmd('edit ' .. ctx.playground .. '/locales/ja.json')
vim.cmd 'filetype detect'
assert(vim.bo.filetype == 'json', 'json filetype expected, got ' .. vim.bo.filetype)
local lbuf = vim.api.nvim_get_current_buf()

assert(
  ctx.wait_for(function()
    local marks = vim.api.nvim_buf_get_extmarks(lbuf, ns, 0, -1, { details = true })
    return #marks >= 2
  end, 10000),
  'locale file got no EOL decorations'
)

--[[ The code buffer raised conceallevel to hide its keys; the locale file must
  get the user's level back, or JSON quotes vanish under conceallevel=2. ]]
assert(
  ctx.wait_for(function()
    return vim.wo.conceallevel == 0
  end, 5000),
  'locale file kept conceallevel raised'
)

local marks = vim.api.nvim_buf_get_extmarks(lbuf, ns, 0, -1, { details = true })
local texts = {}
for _, m in ipairs(marks) do
  assert(m[4].virt_text_pos == 'eol', 'locale-file mark not EOL')
  texts[#texts + 1] = m[4].virt_text[1][1]
end
local joined = table.concat(texts, '\n')
assert(joined:find('1 usage', 1, true), 'expected usage badges at EOL: ' .. joined)
assert(not joined:find('Hello x18n', 1, true), 'default EOL annotation should not repeat the value: ' .. joined)

local function eol_text()
  local out = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(lbuf, ns, 0, -1, { details = true })) do
    out[#out + 1] = m[4].virt_text[1][1]
  end
  return table.concat(out, '\n')
end

decorations.setup {
  mode = 'conceal',
  debounce_ms = 100,
  show_locale_file_eol_translation = true,
  show_locale_file_eol_usage = true,
}
decorations.refresh_attached()
assert(
  ctx.wait_for(function()
    local text = eol_text()
    return text:find('Hello x18n', 1, true) ~= nil and text:find('1 usage', 1, true) ~= nil
  end, 5000),
  'opt-in value annotation did not appear: ' .. eol_text()
)

local display_values = {
  en = { 'Hello x18n', 'A playground for x18n.nvim' },
  fr = { 'Bonjour x18n', 'Un terrain de jeu pour x18n.nvim' },
  ja = { 'こんにちは x18n', 'x18n.nvim の実験場' },
  ['zh-CN'] = { '你好 x18n', 'x18n.nvim 的试验场' },
}
local next_locale = require('x18n.locales').next()
local next_title = display_values[next_locale][1]
local next_description = display_values[next_locale][2]
assert(next_title and next_description, 'unknown locale ' .. tostring(next_locale))
assert(
  ctx.wait_for(function()
    local found_title, found_description = false, false
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(lbuf, ns, 0, -1, { details = true })) do
      local text = m[4].virt_text[1][1]
      if text:find(next_title, 1, true) then
        found_title = true
      end
      if text:find(next_description, 1, true) then
        found_description = true
      end
    end
    return found_title and found_description
  end, 5000),
  'EOL decorations did not follow display locale to ' .. next_locale
)

assert(decorations.toggle_locale_file_eol() == false, 'EOL toggle should report off')
assert(
  ctx.wait_for(function()
    local text = eol_text()
    return not text:find(next_title, 1, true)
      and not text:find(next_description, 1, true)
      and text:find('usage', 1, true) ~= nil
  end, 5000),
  'EOL translation toggle changed the usage badges: ' .. eol_text()
)
assert(decorations.toggle_locale_file_eol() == true, 'EOL toggle should report on')
assert(
  ctx.wait_for(function()
    return eol_text():find(next_title, 1, true) ~= nil and eol_text():find(next_description, 1, true) ~= nil
  end, 5000),
  'EOL translations did not return after toggle on'
)

decorations.setup {
  mode = 'conceal',
  debounce_ms = 100,
  show_locale_file_eol_translation = true,
  show_locale_file_eol_usage = false,
}
decorations.refresh_attached()
assert(
  ctx.wait_for(function()
    local text = eol_text()
    return text:find('usage', 1, true) == nil
      and text:find(next_title, 1, true) ~= nil
      and text:find(next_description, 1, true) ~= nil
  end, 5000),
  'show_locale_file_eol_usage=false did not drop the badge: ' .. eol_text()
)

decorations.setup {
  mode = 'conceal',
  debounce_ms = 100,
  show_locale_file_eol_translation = false,
  show_locale_file_eol_usage = true,
}
decorations.refresh_attached()
assert(
  ctx.wait_for(function()
    local text = eol_text()
    return not text:find(next_title, 1, true) and not text:find(next_description, 1, true)
  end, 5000),
  'show_locale_file_eol_translation=false did not drop the value: ' .. eol_text()
)

vim.cmd('edit ' .. ctx.playground .. '/src/main.js')
vim.cmd 'filetype detect'
assert(
  ctx.wait_for(function()
    return vim.wo.conceallevel == 2
  end, 8000),
  'conceallevel not raised on the code buffer'
)
vim.cmd 'enew'
assert(
  ctx.wait_for(function()
    return vim.wo.conceallevel == 0
  end, 5000),
  'plain buffer kept conceallevel raised'
)
vim.cmd('edit ' .. ctx.playground .. '/src/main.js')
vim.cmd 'filetype detect'
assert(
  ctx.wait_for(function()
    return vim.wo.conceallevel == 2
  end, 8000),
  'conceallevel not raised after returning to the code buffer'
)
print 'locale-file ok'
