local ctx = ...
local reviews = require 'x18n.reviews'

local notes = {}
vim.notify = function(msg, level)
  notes[#notes + 1] = { msg = msg, level = level }
end

local function last_note()
  return notes[#notes]
end

local function qf_title()
  return vim.fn.getqflist({ title = 1 }).title
end

local function find_item(pattern)
  for i, item in ipairs(vim.fn.getqflist()) do
    if item.text:find(pattern, 1, true) then
      return i, item
    end
  end
end

local ja_uri = vim.uri_from_fname(ctx.playground .. '/locales/ja.json')
local fr_uri = vim.uri_from_fname(ctx.playground .. '/locales/fr.json')
local zh_uri = vim.uri_from_fname(ctx.playground .. '/locales/zh-CN.json')

reviews.show {
  {
    project = 'playground',
    key = 'app.title',
    locale = 'ja',
    state = 'changes-requested',
    comments = { { type = 'request-change', text = 'Please use the formal greeting' } },
    location = { uri = ja_uri, range = { start = { line = 2, character = 4 } } },
  },
  {
    project = 'playground',
    key = 'app.description',
    locale = 'fr',
    state = 'suggested',
    comments = { { type = 'suggestion', suggestion = 'Un autre terrain' } },
    location = { uri = fr_uri, range = { start = { line = 3, character = 4 } } },
  },
  {
    project = 'playground',
    key = 'app.greeting',
    locale = 'zh-CN',
    state = 'approved',
    comments = { { type = 'approve', value = '你好 x18n' } },
    location = { uri = zh_uri, range = { start = { line = 4, character = 4 } } },
  },
  {
    project = 'playground',
    key = 'app.ghost',
    locale = 'fr',
    state = 'changes-requested',
    comments = { { type = 'request-change' } },
  },
}

local items = vim.fn.getqflist()
assert(#items == 4, 'expected 4 synthetic items, got ' .. #items)
assert(qf_title() == 'x18n reviews', 'synthetic title wrong: ' .. tostring(qf_title()))
assert(
  items[1].text == '[changes requested] app.title [ja] · Please use the formal greeting',
  'synthetic text wrong: ' .. items[1].text
)
assert(
  items[2].text == '[suggested] app.description [fr] · suggestion: Un autre terrain',
  'suggestion text wrong: ' .. items[2].text
)
assert(
  items[3].text == '[approved] app.greeting [zh-CN] · approved 你好 x18n',
  'approved text wrong: ' .. items[3].text
)
assert(
  items[4].text == '[changes requested] app.ghost [fr] · change requested (no location)',
  'locationless text wrong: ' .. items[4].text
)
assert(vim.api.nvim_buf_get_name(items[1].bufnr):find('locales/ja.json', 1, true), 'title item lost its file')
assert(vim.api.nvim_buf_get_name(items[2].bufnr):find('locales/fr.json', 1, true), 'suggestion item lost its file')
assert(items[4].bufnr == 0, 'locationless item got a buffer')

vim.fn.setqflist {}
reviews.run()
assert(
  ctx.wait_for(function()
    return #vim.fn.getqflist() == 4
  end, 8000),
  'x18n/reviews never populated the quickfix'
)
assert(qf_title() == 'x18n reviews', 'live title wrong: ' .. tostring(qf_title()))

local expected = {
  '[suggested] app.description [fr] · suggestion: Un terrain de jeu',
  '[commented] app.ghost [fr] · Key missing from the resources (no location)',
  '[resolved] app.greeting [zh-CN] · Reviewed already',
  '[changes requested] app.title [ja] · Please use the formal greeting',
}
items = vim.fn.getqflist()
for i, text in ipairs(expected) do
  assert(items[i].text == text, ('live item %d wrong: %s'):format(i, items[i].text))
end
assert(vim.api.nvim_buf_get_name(items[1].bufnr):find('locales/fr.json', 1, true), 'description item lost fr.json')
assert(vim.api.nvim_buf_get_name(items[3].bufnr):find('locales/zh-CN.json', 1, true), 'greeting item lost zh-CN.json')
assert(items[2].bufnr == 0, 'ghost item got a buffer')
assert(vim.api.nvim_buf_get_name(items[4].bufnr):find('locales/ja.json', 1, true), 'title item lost ja.json')

local title_index = assert(find_item 'app.title [ja]')
vim.cmd('cc ' .. title_index)
assert(
  vim.api.nvim_buf_get_name(0):find('locales/ja.json', 1, true),
  'cc did not open ja.json: ' .. vim.api.nvim_buf_get_name(0)
)
assert(vim.api.nvim_get_current_line():find('"title"', 1, true), 'cc did not land on the title key')

local ghost_index = assert(find_item 'app.ghost [fr]')
assert(vim.fn.getqflist()[ghost_index].bufnr == 0, 'ghost item has a location')
local ok = pcall(vim.cmd, 'cc ' .. ghost_index)
assert(ok, 'cc on the locationless item errored')

reviews.run { open = true }
assert(
  ctx.wait_for(function()
    return qf_title() == 'x18n reviews (open)'
  end, 8000),
  'open filter never refreshed the quickfix'
)
items = vim.fn.getqflist()
assert(#items == 3, 'open filter expected 3 items, got ' .. #items)
assert(find_item 'app.greeting' == nil, 'open filter kept the resolved thread')
assert(find_item 'app.title [ja]' ~= nil, 'open filter dropped the change request')

local before_title = qf_title()
local before_items = #vim.fn.getqflist()
reviews.show({}, { open = true })
assert(last_note() and last_note().msg:find('no open review threads', 1, true), 'empty open show did not warn')
assert(last_note().level == vim.log.levels.WARN, 'empty open show did not warn at WARN')
assert(qf_title() == before_title and #vim.fn.getqflist() == before_items, 'empty open show touched the quickfix')
reviews.show {}
assert(last_note() and last_note().msg:find('no review threads', 1, true), 'empty show did not warn')
assert(last_note().level == vim.log.levels.WARN, 'empty show did not warn at WARN')
assert(qf_title() == before_title and #vim.fn.getqflist() == before_items, 'empty show touched the quickfix')

require('x18n.lsp').stop()
assert(
  ctx.wait_for(function()
    return #vim.lsp.get_clients { name = 'x18n' } == 0
  end, 5000),
  'server did not stop'
)
assert(reviews.run() == false, 'run started without a client')
assert(
  last_note() and last_note().msg:find('x18n-lsp is not running in this session', 1, true),
  'missing client did not warn'
)
print 'reviews ok'
