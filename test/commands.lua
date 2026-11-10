local _ = ...

vim.cmd 'runtime! plugin/x18n.lua'

local commands = {
  'X18nEnable',
  'X18nDisable',
  'X18nReload',
  'X18nExtract',
  'X18nUsageReport',
  'X18nReviews',
  'X18nTree',
  'X18nCopyTranslatePrompt',
  'X18nSearch',
  'X18nDisplayLocale',
  'X18nNextLocale',
  'X18nNextDefinition',
  'X18nDefinition',
  'X18nKeyUsages',
  'X18nShowTranslations',
  'X18nExplain',
  'X18nOpenUi',
  'X18nAddKey',
  'X18nToggleDecorations',
  'X18nToggleOrigin',
  'X18nToggleTranslation',
  'X18nToggleLocaleFileEol',
  'X18nStatus',
  'X18nKeys',
}
for _, name in ipairs(commands) do
  assert(vim.fn.exists(':' .. name) == 2, name .. ' is not registered')
end

local decorations = require 'x18n.decorations'
local before = decorations.get_mode()
vim.cmd 'X18nToggleTranslation'
assert(decorations.get_mode() == 'origin', 'ToggleTranslation did not enter origin')
vim.cmd 'X18nToggleTranslation'
assert(decorations.get_mode() == before, 'ToggleTranslation did not restore the mode')
vim.cmd 'X18nToggleOrigin'
assert(decorations.get_mode() == 'both', 'ToggleOrigin did not enter both from conceal: ' .. decorations.get_mode())
decorations.set_mode(before)
vim.cmd 'X18nToggleLocaleFileEol'
assert(decorations.locale_file_eol() == true, 'ToggleLocaleFileEol did not turn on')
vim.cmd 'X18nToggleLocaleFileEol'
assert(decorations.locale_file_eol() == false, 'ToggleLocaleFileEol did not turn off')
print 'commands ok'
