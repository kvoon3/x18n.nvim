# Commands and Lua API

## Commands

| Command | Description |
| --- | --- |
| `:X18nEnable` | Start the x18n client for the current buffer |
| `:X18nDisable` | Stop every x18n client, clear decorations, and stop root-marker autostart |
| `:X18nReload` | Restart the client and reindex the project |
| `:X18nShowTranslations` | Popup with every locale of the key under the cursor |
| `:X18nDefinition` | List the key's locale definitions in the quickfix (a single one jumps directly) |
| `:X18nNextDefinition` | Jump to the key under the cursor in the next locale file |
| `:X18nKeyUsages` | Jump to the key's usages, with a picker on multiple hits |
| `:X18nAddKey [key]` | Batch prompt for the key under the cursor (or the given key) in every locale |
| `:X18nKeys [action]` | Pick a key; `jump` (default), `split`, `vsplit`, `tab`, `copy`, `copy_translation`, `choose_locale` |
| `:X18nUsageReport` | List missing and unused keys in the quickfix |
| `:X18nReviews [open]` | List review threads in the quickfix; `open` keeps unresolved threads |
| `:X18nTree [project]` | Browse the key tree one level at a time (project name for monorepos) |
| `:X18nCopyTranslatePrompt [locale]` | Copy the translate prompt for the display locale (or the given one) |
| `:X18nSearch [query]` | Search keys by translated value, jump to the chosen definition |
| `:X18nExtract` | Extract hard strings of the current buffer into locale files |
| `:X18nNextLocale` | Cycle the display locale |
| `:X18nDisplayLocale {locale}` | Switch the locale shown in hovers and decorations (completes) |
| `:X18nToggleDecorations` | Master switch for all decorations |
| `:X18nToggleTranslation` | Swap the translation overlay for the raw key and back |
| `:X18nToggleOrigin` | Toggle raw-key visibility while translations stay active |
| `:X18nToggleLocaleFileEol` | Toggle the display-locale value at the end of locale-file lines |
| `:X18nStatus` | Show projects, locales, progress, mode and EOL state |
| `:X18nExplain` | Show how the server understood the workspace |
| `:X18nOpenUi` | Open the x18n web UI in the browser |

Every command works against the published `@x18n/lsp` 0.1.13 or newer.

## Lua API

Everything is also reachable as Lua for keymaps:

```lua
local actions = require 'x18n.actions'

vim.keymap.set('n', '<leader>tt', function()
  actions.show_translations()
end)
vim.keymap.set('n', '<leader>tn', function()
  require('x18n.locales').next()
end)
vim.keymap.set('n', '<leader>tj', function()
  actions.next_definition()
end)
-- The plugin already binds gd on x18n buffers; this is for a custom key.
vim.keymap.set('n', 'gd', function()
  if not actions.definition() then
    vim.lsp.buf.definition()
  end
end)
vim.keymap.set('n', 'gu', function()
  if not require('x18n.usages').jump_under_cursor() then
    vim.lsp.buf.references()
  end
end)
vim.keymap.set('n', '<leader>tk', function()
  require('x18n.keys').pick 'choose_locale'
end)
vim.keymap.set('n', '<leader>xr', function()
  require('x18n.reviews').run { open = true }
end)
vim.keymap.set('n', '<leader>xt', function()
  require('x18n.tree').open()
end)
vim.keymap.set('n', '<leader>xp', function()
  require('x18n.translate_prompt').copy()
end)
```

`show_translations` returns `false` when the cursor is not on a key, so it
chains with a fallback:

```lua
vim.keymap.set({ 'n', 'i' }, '<C-k>', function()
  if not require('x18n.actions').show_translations() then
    vim.lsp.buf.signature_help()
  end
end)
```

## Runtime state

Modes and toggles are runtime state:

```lua
local decorations = require 'x18n.decorations'
decorations.set_mode 'translation'
decorations.get_mode()
decorations.toggle_origin()
decorations.toggle_translation()
decorations.toggle_locale_file_eol()
require('x18n.lifecycle').is_enabled()
```

## Pickers

The key, search and usage pickers go through `vim.ui.select`, so
[dressing.nvim](https://github.com/folke/dressing.nvim),
[telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim)
or [snacks.nvim](https://github.com/folke/snacks.nvim) render them in your
picker of choice. Definitions use the quickfix, like references.
