-- Ctrl+. on an x18n key lists one add action per missing locale. It works on
-- the code usage, and on the missing-translation warning line in a locale file.
-- Only the chosen locale is written; the native code actions are the fallback.
local ctx = ...

local function cursor_onto(pattern)
  local buf = vim.api.nvim_get_current_buf()
  for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = l:find(pattern, 1, false)
    if col then
      vim.api.nvim_win_set_cursor(0, { i, col - 1 })
      return true
    end
  end
  return false
end

assert(cursor_onto 'app%.missing%.key', 'fixture lost the missing-key call')

local actions, wanted
vim.ui.select = function(items, opts, on_choice)
  --[[ Picker-specific hints (snacks' kind='codeaction') change how the items
    are interpreted; these are plain client-built entries, so none may ride. ]]
  assert(opts and opts.kind == nil, 'picker-specific kind leaked: ' .. tostring(opts and opts.kind))
  actions = items
  if wanted then
    for _, item in ipairs(items) do
      if item.title == wanted then
        on_choice(item)
        return
      end
    end
  end
  on_choice(nil)
end
local answers = { en = 'Source title', fr = 'Titre ajouté' }
vim.ui.input = function(opts, on_choice)
  local locale = opts.prompt:match '%[([%w-]+)%]'
  on_choice(answers[locale] or '')
end

local function menu()
  actions = nil
  local map = vim.fn.maparg('<C-.>', 'n', false, true)
  assert(map and map.callback, 'Ctrl+. not bound on x18n buffers')
  map.callback()
  assert(
    ctx.wait_for(function()
      return actions ~= nil
    end, 5000),
    'code action menu never opened'
  )
  local titles = {}
  for _, item in ipairs(actions) do
    titles[#titles + 1] = item.title
  end
  return table.concat(titles, '\n')
end

local function key_lines(code)
  local buf = vim.fn.bufadd(ctx.playground .. '/locales/' .. code .. '.json')
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
end

-- The source is missing: all four locales are offered.
wanted = 'Add "app.missing.key" to en'
local first = menu()
for _, locale in ipairs { 'en', 'fr', 'ja', 'zh-CN' } do
  assert(first:find('Add "app.missing.key" to ' .. locale, 1, true), 'missing action for ' .. locale .. ': ' .. first)
end
assert(not first:find('Add empty values in', 1, true), 'empty-value action leaked: ' .. first)
assert(
  ctx.wait_for(function()
    return key_lines('en'):find('Source title', 1, true)
  end, 8000),
  'en.json never received the code action value'
)

-- The code usage has no diagnostic now, but the plugin still lists the three
-- remaining locales instead of disappearing. The server index updates after the
-- edit, so retry until the en action drops out.
wanted = nil
local second
assert(
  ctx.wait_for(function()
    second = menu()
    return not second:find('Add "app.missing.key" to en', 1, true)
  end, 8000),
  'en action stayed after the key was added: ' .. tostring(second)
)
for _, locale in ipairs { 'fr', 'ja', 'zh-CN' } do
  assert(second:find('Add "app.missing.key" to ' .. locale, 1, true), 'missing action for ' .. locale .. ': ' .. second)
end
assert(not second:find('Add empty values in', 1, true), 'empty-value action leaked: ' .. second)

-- The missing-translation warning in en.json offers the same actions.
vim.cmd('edit ' .. ctx.playground .. '/locales/en.json')
vim.cmd 'filetype detect'
local enbuf = vim.api.nvim_get_current_buf()
assert(
  ctx.wait_for(function()
    return vim.diagnostic.get(enbuf, { code = 'missing-translation' })[1] ~= nil
  end, 8000),
  'en.json warning never arrived'
)
local warning = vim.diagnostic.get(enbuf, { code = 'missing-translation' })[1]
vim.api.nvim_win_set_cursor(0, { warning.lnum + 1, warning.col })
wanted = 'Add "app.missing.key" to fr'
local third = menu()
for _, locale in ipairs { 'fr', 'ja', 'zh-CN' } do
  assert(third:find('Add "app.missing.key" to ' .. locale, 1, true), 'warning action for ' .. locale .. ': ' .. third)
end
assert(
  ctx.wait_for(function()
    return key_lines('fr'):find('Titre ajouté', 1, true)
  end, 8000),
  'fr.json never received the code action value'
)

for _, code in ipairs { 'ja', 'zh-CN' } do
  local text = key_lines(code)
  assert(not text:find('missing', 1, true), code .. ' was auto-filled with the key')
  assert(not text:find('Titre ajouté', 1, true), code .. ' was auto-filled with the value')
end
print 'code action ok'
