-- Decorations opted out in config: the module is never set up, so every
-- toggle and command must be a no-op instead of indexing a nil config.
local ctx = ...
local decorations = require 'x18n.decorations'

vim.cmd 'runtime! plugin/x18n.lua'

assert(decorations.get_mode() == 'off', 'unconfigured mode is not off')
assert(decorations.toggle_translation() == 'off', 'toggle_translation changed an unconfigured module')
assert(decorations.toggle_origin() == 'off', 'toggle_origin changed an unconfigured module')
assert(decorations.toggle_locale_file_eol() == false, 'EOL toggle changed an unconfigured module')
assert(decorations.toggle() == false, 'master toggle changed an unconfigured module')
assert(decorations.locale_file_eol() == false, 'unconfigured module reports EOL on')

-- Commands are wired and must not raise.
vim.cmd 'X18nToggleDecorations'
vim.cmd 'X18nToggleOrigin'
vim.cmd 'X18nToggleTranslation'
vim.cmd 'X18nToggleLocaleFileEol'

assert(#vim.api.nvim_buf_get_extmarks(ctx.buf, decorations.namespace(), 0, -1, {}) == 0, 'marks rendered with decorations off')
assert(vim.wo.conceallevel == 0, 'conceallevel raised with decorations off')
print('decorations disabled ok')
