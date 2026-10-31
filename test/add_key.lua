-- Add key: cursor on the missing-key call, per-locale inputs, x18n.set writes.
local ctx = ...

-- Cursor onto the key literal of t('app.missing.key').
local function cursor_onto(pattern)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
    local col = l:find(pattern, 1, false)
    if col then
      vim.api.nvim_win_set_cursor(0, { i, col + 1 })
      return true
    end
  end
  return false
end
assert(cursor_onto('app%.missing%.key'), 'fixture lost the missing-key call')

local answers = { en = 'A missing title', zh = '缺失的标题' }
local asked = {}
vim.ui.input = function(opts, on_choice)
  local locale = opts.prompt:match('%[([%w-]+)%]')
  asked[#asked + 1] = locale
  on_choice(answers[locale] or '')
end

require('x18n.add_key').run()

assert(ctx.wait_for(function()
  local en_buf = vim.fn.bufadd(ctx.playground .. '/locales/en.json')
  local text = table.concat(vim.api.nvim_buf_get_lines(en_buf, 0, -1, false), '\n')
  return text:find('missing', 1, false) and text:find('A missing title', 1, true)
end, 8000), 'en.json never received the new key')

local zh_buf = vim.fn.bufadd(ctx.playground .. '/locales/zh.json')
ctx.wait_for(function()
  local text = table.concat(vim.api.nvim_buf_get_lines(zh_buf, 0, -1, false), '\n')
  return text:find('缺失的标题', 1, true)
end, 8000)

assert(#asked == 2 and asked[1] == 'en' and asked[2] == 'zh', 'asked wrong locales: ' .. table.concat(asked, ','))

-- Refuse to overwrite: an existing key must not enter the flow.
asked = {}
assert(cursor_onto('app%.title'), 'fixture lost app.title')
require('x18n.add_key').run()
assert(#asked == 0, 'existing key entered the add flow')
print('add_key ok')
