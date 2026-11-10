local ctx = ...
local tree = require 'x18n.tree'
local actions = require 'x18n.actions'
local locales = require 'x18n.locales'

local notes = {}
vim.notify = function(msg, level)
  notes[#notes + 1] = { msg = msg, level = level }
end

local selects = {}
local plan = {}
vim.ui.select = function(items, opts, on_choice)
  selects[#selects + 1] = { items = items, opts = opts }
  local pick = table.remove(plan, 1)
  on_choice(pick and pick(items) or nil)
end

local function find_row(items, label)
  for _, item in ipairs(items) do
    if item.label == label then
      return item
    end
  end
end

local function row_texts(call)
  local out = {}
  for _, item in ipairs(call.items) do
    out[#out + 1] = call.opts.format_item(item)
  end
  return out
end

local before = #selects
plan = {
  function()
    return nil
  end,
}
assert(tree.open 'playground' == true, 'tree.open returned false')
assert(
  ctx.wait_for(function()
    return #selects == before + 1
  end, 5000),
  'tree roots never opened'
)
local roots = selects[#selects]
assert(roots.opts.prompt == 'x18n tree', 'roots prompt wrong: ' .. tostring(roots.opts.prompt))
assert(#roots.items == 1, 'roots expected one item, got ' .. #roots.items)
assert(
  roots.opts.format_item(roots.items[1]) == '▸ app  (9/9)',
  'root row wrong: ' .. roots.opts.format_item(roots.items[1])
)

assert(tree.open 'nope' == false, 'unknown project started a session')
assert(notes[#notes] and notes[#notes].msg:find('unknown project nope', 1, true), 'unknown project did not warn')
assert(#selects == before + 1, 'unknown project opened a picker')

before = #selects
plan = {
  function(items)
    return find_row(items, 'app')
  end,
  function()
    return nil
  end,
}
tree.open 'playground'
assert(
  ctx.wait_for(function()
    return #selects == before + 2
  end, 5000),
  'drill never reached the leaves'
)
local children = selects[#selects]
assert(children.opts.prompt == 'x18n tree: app', 'drill prompt wrong: ' .. tostring(children.opts.prompt))
assert(#children.items == 4, 'drilled level expected four rows, got ' .. #children.items)
local texts = row_texts(children)
assert(texts[1] == '.. (up)', 'up row wrong: ' .. texts[1])
assert(texts[2] == 'description = A playground for x18n.nvim  (3/3)', 'description row wrong: ' .. texts[2])
assert(texts[3] == 'greeting = Hello {name}  (3/3)', 'greeting row wrong: ' .. texts[3])
assert(texts[4] == 'title = Hello x18n  (3/3)', 'title row wrong: ' .. texts[4])

actions.set_display_locale 'ja'
assert(
  ctx.wait_for(function()
    return locales.display_locale() == 'ja'
  end, 3000),
  'display locale did not switch to ja'
)
before = #selects
plan = {
  function(items)
    return find_row(items, 'app')
  end,
  function()
    return nil
  end,
}
tree.open 'playground'
assert(
  ctx.wait_for(function()
    return #selects == before + 2
  end, 8000),
  'ja drill never reached the leaves'
)
texts = row_texts(selects[#selects])
assert(texts[4]:find('こんにちは x18n', 1, true), 'ja leaf lost the display value: ' .. texts[4])

before = #selects
plan = {
  function(items)
    return find_row(items, 'app')
  end,
  function(items)
    return find_row(items, 'title')
  end,
}
tree.open 'playground'
assert(
  ctx.wait_for(function()
    return vim.api.nvim_buf_get_name(0):find('locales/ja.json', 1, true) ~= nil
  end, 8000),
  'ja leaf jump did not open ja.json: ' .. vim.api.nvim_buf_get_name(0)
)
assert(vim.api.nvim_get_current_line():find('こんにちは x18n', 1, true), 'ja leaf jump missed the value')

actions.set_display_locale 'en'
assert(
  ctx.wait_for(function()
    return locales.display_locale() == 'en'
  end, 3000),
  'display locale did not switch back to en'
)
vim.cmd('edit ' .. ctx.playground .. '/src/main.js')
before = #selects
plan = {
  function(items)
    return find_row(items, 'app')
  end,
  function(items)
    return find_row(items, 'title')
  end,
}
tree.open 'playground'
assert(
  ctx.wait_for(function()
    return vim.api.nvim_buf_get_name(0):find('locales/en.json', 1, true) ~= nil
  end, 8000),
  'en leaf jump did not open en.json: ' .. vim.api.nvim_buf_get_name(0)
)
assert(vim.api.nvim_get_current_line():find('"title"', 1, true), 'en leaf jump missed the key')
assert(vim.api.nvim_get_current_line():find('Hello x18n', 1, true), 'en leaf jump missed the value')

vim.cmd('edit ' .. ctx.playground .. '/locales/en.json')
vim.cmd 'filetype detect'
local buffer_before = vim.api.nvim_get_current_buf()
before = #selects
plan = {
  function(items)
    return find_row(items, 'app')
  end,
  function(items)
    return find_row(items, '.. (up)')
  end,
  function()
    return nil
  end,
}
tree.open 'playground'
assert(
  ctx.wait_for(function()
    return #selects == before + 3
  end, 8000),
  'back never returned to the roots'
)
local back_roots = selects[#selects]
assert(back_roots.opts.prompt == 'x18n tree', 'back prompt wrong: ' .. tostring(back_roots.opts.prompt))
assert(#back_roots.items == 1 and back_roots.items[1].label == 'app', 'back did not offer the root again')
assert(vim.api.nvim_get_current_buf() == buffer_before, 'back changed the current buffer')

before = #selects
local notes_before = #notes
plan = {
  function()
    return nil
  end,
}
tree.open 'playground'
assert(
  ctx.wait_for(function()
    return #selects == before + 1
  end, 5000),
  'cancel never reached the roots'
)
vim.wait(300, function()
  return #selects > before + 1
end)
assert(#selects == before + 1, 'cancel opened another level')
assert(#notes == notes_before, 'cancel notified')

local real_request = require('x18n.lsp').custom_request
require('x18n.lsp').custom_request = function(client, method, params, handler)
  if method ~= 'x18n/tree' then
    return real_request(client, method, params, handler)
  end
  if params.parent == nil then
    handler(nil, { { key = 'auth:', label = 'auth', leaf = false, translated = 0, total = 1 } })
  else
    handler(nil, {
      { key = 'auth:login', label = 'ogin', leaf = false, translated = 0, total = 1 },
      { key = 'auth:logout', label = 'ogout', leaf = true, translated = 0, total = 1 },
    })
  end
end
before = #selects
plan = {
  function(items)
    return find_row(items, 'auth')
  end,
  function()
    return nil
  end,
}
tree.open 'playground'
assert(
  ctx.wait_for(function()
    return #selects == before + 2
  end, 5000),
  'namespace drill never opened'
)
local namespaced = row_texts(selects[#selects])
assert(namespaced[2] == '▸ login  (0/1)', 'namespace child label wrong: ' .. namespaced[2])
assert(namespaced[3] == 'logout = —  (0/1)', 'namespace leaf label wrong: ' .. namespaced[3])
require('x18n.lsp').custom_request = real_request

require('x18n.lsp').stop()
assert(
  ctx.wait_for(function()
    return #vim.lsp.get_clients { name = 'x18n' } == 0
  end, 5000),
  'server did not stop'
)
before = #selects
local notes_after_stop = #notes
assert(tree.open() == false, 'tree.open started without a client')
assert(#notes == notes_after_stop + 1, 'missing client did not warn')
assert(notes[#notes].msg:find('x18n-lsp is not running in this session', 1, true), 'missing client warning wrong')
vim.wait(300, function()
  return #selects > before
end)
assert(#selects == before, 'no-client opened a picker')
print 'tree ok'
