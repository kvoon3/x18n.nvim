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
assert(cursor_onto 'app%.missing%.key', 'fixture lost the missing-key call')

local answers = {
  en = 'A missing title',
  ['zh-CN'] = '缺失的标题',
  ja = '欠けているタイトル',
  fr = 'Un titre manquant',
}
local asked = {}
local notes = {}
vim.notify = function(msg)
  notes[#notes + 1] = msg
end
vim.ui.input = function(opts, on_choice)
  local locale = opts.prompt:match '%[([%w-]+)%]'
  asked[#asked + 1] = locale
  on_choice(answers[locale] or '')
end

require('x18n.add_key').run()

for _, code in ipairs { 'en', 'zh-CN', 'ja', 'fr' } do
  local buf = vim.fn.bufadd(ctx.playground .. '/locales/' .. code .. '.json')
  assert(
    ctx.wait_for(function()
      local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
      return text:find('missing', 1, false) and text:find(answers[code], 1, true)
    end, 8000),
    code .. '.json never received the new key'
  )
end

local order = require('x18n.locales').locales()
assert(#order == 4, 'expected four locales, got ' .. table.concat(order, ','))
assert(#asked == #order and (function()
  for i, code in ipairs(order) do
    if asked[i] ~= code then
      return false
    end
  end
  return true
end)(), 'asked wrong locales: ' .. table.concat(asked, ','))

assert(
  ctx.wait_for(function()
    for _, msg in ipairs(notes) do
      if msg:find('added app.missing.key to 4 locale', 1, true) then
        return true
      end
    end
    return false
  end, 8000),
  'add-key success notification never arrived'
)

-- Refuse to overwrite: an existing key must not enter the flow.
asked = {}
assert(cursor_onto 'app%.title', 'fixture lost app.title')
require('x18n.add_key').run()
assert(#asked == 0, 'existing key entered the add flow')

-- An explicit brand-new key (used nowhere) goes through; an explicit existing
-- one is refused by the tree check.
asked = {}
require('x18n.add_key').run 'brand.new.key'
assert(#asked == #order, 'explicit new key did not reach the per-locale inputs: ' .. #asked)
require('x18n.add_key').run 'app.title'
assert(#asked == #order, 'explicit existing key entered the flow')
print 'add_key ok'
