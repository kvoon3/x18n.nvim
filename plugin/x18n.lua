if vim.g.loaded_x18n then
  return
end
vim.g.loaded_x18n = true

vim.api.nvim_create_user_command('X18nExtract', function()
  require('x18n.actions').extract()
end, { desc = 'x18n: extract hard strings of the current buffer' })

vim.api.nvim_create_user_command('X18nEnable', function()
  require('x18n.lifecycle').enable()
end, { desc = 'x18n: start the language server for this buffer' })

vim.api.nvim_create_user_command('X18nDisable', function()
  require('x18n.lifecycle').disable()
end, { desc = 'x18n: stop the language server and clear decorations' })

vim.api.nvim_create_user_command('X18nReload', function()
  require('x18n.lifecycle').reload()
end, { desc = 'x18n: restart the language server and reindex the project' })

vim.api.nvim_create_user_command('X18nUsageReport', function()
  require('x18n.report').run()
end, { desc = 'x18n: list missing and unused keys in the quickfix' })

vim.api.nvim_create_user_command('X18nReviews', function(a)
  if a.args ~= '' and a.args ~= 'open' then
    require('x18n').notify('unknown review filter: ' .. a.args, vim.log.levels.WARN)
    return
  end
  require('x18n.reviews').run { open = a.args == 'open' }
end, {
  nargs = '?',
  complete = function()
    return { 'open' }
  end,
  desc = 'x18n: list review threads in the quickfix',
})

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

vim.api.nvim_create_user_command('X18nDefinition', function()
  require('x18n.actions').definition()
end, { desc = "x18n: list the key's locale definitions in the quickfix (a single one jumps directly)" })

vim.api.nvim_create_user_command('X18nKeyUsages', function()
  require('x18n.usages').jump_under_cursor()
end, { desc = 'x18n: jump to the usages of the key under the cursor' })

vim.api.nvim_create_user_command('X18nShowTranslations', function()
  if not require('x18n.actions').show_translations() then
    require('x18n').notify 'no i18n key under the cursor'
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

vim.api.nvim_create_user_command('X18nToggleOrigin', function()
  local mode = require('x18n.decorations').toggle_origin()
  require('x18n').notify('show mode: ' .. mode)
end, { desc = 'x18n: toggle showing the raw key while translations stay on' })

vim.api.nvim_create_user_command('X18nToggleTranslation', function()
  local mode = require('x18n.decorations').toggle_translation()
  require('x18n').notify('show mode: ' .. mode)
end, { desc = 'x18n: toggle the translation overlay' })

vim.api.nvim_create_user_command('X18nToggleLocaleFileEol', function()
  local on = require('x18n.decorations').toggle_locale_file_eol()
  require('x18n').notify(on and 'locale-file EOL translations on' or 'locale-file EOL translations off')
end, { desc = 'x18n: toggle end-of-line translations in locale files' })

vim.api.nvim_create_user_command('X18nStatus', function()
  require('x18n.status').show()
end, { desc = 'x18n: show projects, locales and translation progress' })

vim.api.nvim_create_user_command('X18nKeys', function(a)
  require('x18n.keys').pick(a.args ~= '' and a.args or nil)
end, {
  nargs = '?',
  complete = function()
    local actions = { 'copy' }
    vim.list_extend(actions, require('x18n.keys').actions)
    return actions
  end,
  desc = 'x18n: pick a key (action: jump, split, vsplit, tab, copy, copy_translation, choose_locale)',
})
