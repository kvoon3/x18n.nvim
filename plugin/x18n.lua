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
end, { nargs = 1, desc = 'x18n: switch the locale shown in hovers and decorations' })

vim.api.nvim_create_user_command('X18nOpenUi', function()
  require('x18n.actions').open_ui()
end, { desc = 'x18n: open the web UI in the browser' })
