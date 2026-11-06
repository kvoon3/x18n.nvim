local ctx = ...
local keys = require 'x18n.keys'
local actions = require 'x18n.actions'

local wanted_locale = 'ja'
local selects = {}
vim.ui.select = function(items, opts, on_choice)
  selects[#selects + 1] = { items = items, opts = opts }
  for _, item in ipairs(items) do
    if item.key == 'app.title' then
      return on_choice(item)
    end
  end
  for _, item in ipairs(items) do
    if item.code == wanted_locale then
      return on_choice(item)
    end
  end
  on_choice(nil)
end

local function only()
  vim.cmd 'only'
  vim.cmd('edit ' .. ctx.playground .. '/src/main.js')
end

vim.fn.setreg('+', '')
keys.pick 'copy_key'
assert(
  ctx.wait_for(function()
    return vim.fn.getreg '+' == 'app.title'
  end, 5000),
  'copy_key failed'
)

vim.fn.setreg('+', '')
keys.pick 'copy_translation'
assert(
  ctx.wait_for(function()
    return vim.fn.getreg '+' == 'Hello x18n'
  end, 8000),
  'copy_translation failed: ' .. vim.fn.getreg '+'
)

actions.set_display_locale 'ja'
assert(
  ctx.wait_for(function()
    return require('x18n.locales').display_locale() == 'ja'
  end, 3000),
  'display locale did not switch to ja'
)
vim.fn.setreg('+', '')
keys.pick 'copy_translation'
assert(
  ctx.wait_for(function()
    return vim.fn.getreg '+' == 'こんにちは x18n'
  end, 8000),
  'copy_translation ignored ja: ' .. vim.fn.getreg '+'
)
actions.set_display_locale 'en'
assert(
  ctx.wait_for(function()
    return require('x18n.locales').display_locale() == 'en'
  end, 3000),
  'display locale did not switch back to en'
)

vim.cmd 'enew'
keys.pick 'jump'
assert(
  ctx.wait_for(function()
    return vim.api.nvim_buf_get_name(0):find('locales' .. '/' .. 'en%.json')
  end, 8000),
  'jump did not open en.json: ' .. vim.api.nvim_buf_get_name(0)
)
assert(vim.api.nvim_get_current_line():find('title', 1, true), 'cursor not on the title key')

only()
local before = #selects
keys.pick 'choose_locale'
assert(
  ctx.wait_for(function()
    return vim.api.nvim_buf_get_name(0):find('ja.json', 1, true)
  end, 8000),
  'choose_locale did not open ja.json: ' .. vim.api.nvim_buf_get_name(0)
)
assert(#selects == before + 2, 'choose_locale did not open a locale picker')
assert(selects[#selects].items[1].code ~= nil, 'second picker did not list locales')
local offered = {}
for _, item in ipairs(selects[#selects].items) do
  offered[item.code] = true
end
for _, code in ipairs { 'en', 'zh-CN', 'ja', 'fr' } do
  assert(offered[code], 'locale picker lost ' .. code)
end
assert(vim.api.nvim_get_current_line():find('title', 1, true), 'choose_locale missed the key')

only()
keys.pick 'split'
assert(
  ctx.wait_for(function()
    return #vim.api.nvim_list_wins() == 2
  end, 8000),
  'split action did not open a window'
)
assert(vim.api.nvim_buf_get_name(0):find('en.json', 1, true), 'split landed in the wrong buffer')

only()
local locales = require 'x18n.locales'
local original_key_info = locales.key_info
locales.key_info = function(_, _, _, on_result)
  on_result(nil)
end
vim.fn.setreg('+', '')
keys.pick 'copy_translation'
vim.wait(1000, function()
  return false
end, 50)
assert(vim.fn.getreg '+' == '', 'copy_translation copied without keyInfo: ' .. vim.fn.getreg '+')
locales.key_info = original_key_info
print 'keys ok'
