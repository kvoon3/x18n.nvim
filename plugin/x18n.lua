if vim.g.loaded_x18n then
  return
end
vim.g.loaded_x18n = true

vim.api.nvim_create_user_command('X18nExtract', function()
  require('x18n.actions').extract()
end, { desc = 'x18n: extract hard strings of the current buffer' })

vim.api.nvim_create_user_command('X18nUsageReport', function()
  require('x18n.report').run()
end, { desc = 'x18n: list missing and unused keys in the quickfix' })

vim.api.nvim_create_user_command('X18nSearch', function(a)
  require('x18n.search').run(a.args)
end, { nargs = '?', desc = 'x18n: search keys by translated value' })

vim.api.nvim_create_user_command('X18nDisplayLocale', function(a)
  require('x18n.actions').set_display_locale(a.args)
end, {
  nargs = 1,
  complete = function()
    local locales = require 'x18n.locales'
    local list = locales.cached()
    if #list == 0 then
      locales.warm()
    end
    return list
  end,
  desc = 'x18n: switch the locale shown in hovers and decorations',
})

vim.api.nvim_create_user_command('X18nNextLocale', function()
  local locale = require('x18n.locales').next()
  if not locale then
    require('x18n').notify('no project locales known', vim.log.levels.WARN)
  end
end, { desc = 'x18n: cycle the display locale to the next project locale' })

vim.api.nvim_create_user_command('X18nNextDefinition', function()
  require('x18n.actions').next_definition()
end, { desc = 'x18n: jump to the key under the cursor in the next locale file' })

vim.api.nvim_create_user_command('X18nShowTranslations', function()
  if not require('x18n.actions').show_translations() then
    require('x18n').notify('no i18n key under the cursor')
  end
end, { desc = 'x18n: popup with every locale of the key under the cursor' })

vim.api.nvim_create_user_command('X18nExplain', function()
  require('x18n.actions').explain()
end, { desc = 'x18n: how the server understood the workspace' })

vim.api.nvim_create_user_command('X18nOpenUi', function()
  require('x18n.actions').open_ui()
end, { desc = 'x18n: open the web UI in the browser' })

vim.api.nvim_create_user_command('X18nAddKey', function(a)
  require('x18n.add_key').run(a.args ~= '' and a.args or nil)
end, {
  nargs = '?',
  desc = 'x18n: add the key under the cursor (or the given key) to the locale files',
})

vim.api.nvim_create_user_command('X18nToggleDecorations', function()
  local on = require('x18n.decorations').toggle()
  require('x18n').notify(on and 'decorations on' or 'decorations off')
end, { desc = 'x18n: toggle inline translations on/off' })

vim.api.nvim_create_user_command('X18nStatus', function()
  require('x18n.status').show()
end, { desc = 'x18n: show projects, locales and translation progress' })

vim.api.nvim_create_user_command('X18nKeys', function(a)
  local action = a.args == 'copy' and 'copy_key' or 'jump'
  require('x18n.keys').pick(action)
end, {
  nargs = '?',
  complete = function()
    return { 'copy' }
  end,
  desc = 'x18n: pick a key to jump to (arg: copy)',
})
