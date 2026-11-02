# x18n.nvim

[Neovim](https://neovim.io) integration for [x18n](https://x18n.dev) — an i18n toolkit that reads a project's locale files, reports missing, unused and broken keys, and edits them safely.

The language server speaks plain LSP (completion, hover, rename, references, code lens, inlay hints, diagnostics), which Neovim handles natively. This plugin adds what standard LSP cannot express: the custom `x18n/*` protocol as editor UI.

## Features

- **Inline translations** — the key reads as its value, `t('app.title')` renders as `t(Hello x18n)`, in the display locale of your choice. The cursor's line falls back to the raw key with the value at the end of the line, so what you edit stays visible. Modes cover both worlds: `conceal` (default), `inline`, `eol`, and i18n.nvim's `both`, `translation`, `translation_conceal` and `origin`. `:X18nToggleTranslation` swaps the overlay for the raw key and back, `:X18nToggleOrigin` flips raw-key visibility without losing the mode. Missing keys yield to the server's diagnostic instead of doubling it.
- **Completion** — native LSP completion inside `t('...')` slots. Items carry the source value as detail; the selected item resolves to a documentation panel with its value in every locale, missing ones marked.
- **Locale-file annotations** — inside `en.json`, `zh-CN.json`, `ja.json`, `fr.json` and friends, each key line shows its usage count and its value in the display locale at the end of the line. Both segments have their own switch: `:X18nToggleLocaleFileEol` for the value, `show_locale_file_eol_usage = false` for the badge.
- **Definition and usages** — on x18n buffers `gd` lists the key's locale definitions in the quickfix, the same list as `grr`, and jumps to the chosen entry (a single definition jumps directly); `:X18nDefinition` does the same from the command line. `:X18nKeyUsages` jumps to the key's usages, with a picker when several files use it.
- **Usage report** — missing and unused keys as a quickfix list, with jumps into the exact locale files.
- **Value search** — fuzzy search by translated value, pick a result and jump to its definition.
- **Key picker** — all keys of the workspace through `vim.ui.select` (so it uses whichever picker you have configured), with `jump` (display locale), `split`, `vsplit`, `tab`, `copy_key`, `copy_translation` and `choose_locale` actions.
- **Add missing keys** — on a missing key, `Ctrl+.` offers one code action per locale. Choosing one prompts for the value and stages it in that locale's buffer only; no empty values are written to the other locales. `:X18nAddKey` remains the batch prompt for every locale. Edits are unsaved buffers you review and save (like extract).
- **Locale cycling** — cycle the display locale, and cycle the key under the cursor through the locale files that define it.
- **Translations popup** — every locale of the key under the cursor in one float, with usage counts and a copy-key mapping inside the float.
- **Extract hard strings** — rewrites the string literals of the current buffer into locale files (applied by the server via `workspace/applyEdit`).
- **Web UI** — opens the x18n web UI in your browser.
- **Status and explain** — translation progress per locale, the active display mode, and how the server understood the workspace.
- **Lifecycle and diagnostics** — `:X18nEnable`, `:X18nDisable` and `:X18nReload` drive the client, and `diagnostic = false` or a `vim.diagnostic.config` table tunes the server's diagnostics. A key missing from target locales is a warning on its source-locale entry; the plugin mirrors that warning onto every usage in code, so the code line shows the missing locales without opening the locale file.
- `:checkhealth x18n` support.

## Requirements

- Neovim 0.11+ (`vim.lsp.config`)
- [`x18n-lsp`](https://x18n.dev): `npm install -g @x18n/lsp`

Structured hover data, whole-call and line-end hover, completion documentation, locale-file usage counts and locale-labeled implementation jumps come from the `kvoon3/x18n` fork. With an upstream server the popup falls back to parsing the hover markdown, completion keeps the detail line but has no documentation panel, locale-file annotations show the translation without the usage badge, choose-locale falls back to the project locale order, and hover only resolves the key literal.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'kvoon3/x18n.nvim',
  opts = {},
}
```

The LSP client is configured and enabled automatically. Call `setup` with `lsp = false` to manage `vim.lsp.config('x18n', ...)` yourself (e.g. when [nvim-lspconfig](https://github.com/folke/nvim-lspconfig) ships its own definition), and with `decorations = false` to disable the inline annotations.

Decorations take a `mode`. `'conceal'` (default) replaces the key literal with the value, so `t('app.title')` reads `t(Hello x18n)`, and the cursor's line falls back to the raw key with the value as an end-of-line arrow, redrawn as the cursor moves. `'inline'` puts the value right after the call, `'eol'` at the end of the line. i18n.nvim's names work too: `'both'`, `'translation'`, `'translation_conceal'` and `'origin'`. In conceal modes `conceallevel` is raised to 2 in the windows it decorates and restored on mode change or `:X18nToggleDecorations`. Missing keys always yield to the server's diagnostic instead of doubling it.

`gh` and `gd` are chained on x18n buffers. On a key `gh` opens the translations popup and `gd` lists the key's locale definitions in the quickfix; elsewhere both fall back to the binding that was there before (usually LSP hover and definition). No keymap setup is needed. Mouse hover shows the same data through whichever hover plugin you use (eagle.nvim renders the server hover, whose VS Code command links this plugin strips via the fork's `hoverCommands: false`). Hovering the rendered translation or the closing parenthesis resolves the key. A line-end annotation resolves it too when the line has one key; a line with several keys stays ambiguous at its end. Definition and usage commands still require the key literal.

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
| `:X18nSearch [query]` | Search keys by translated value, jump to the chosen definition |
| `:X18nExtract` | Extract hard strings of the current buffer into locale files |
| `:X18nNextLocale` | Cycle the display locale |
| `:X18nDisplayLocale {locale}` | Switch the locale shown in hovers and decorations (completes) |
| `:X18nToggleDecorations` | Master switch for all decorations |
| `:X18nToggleTranslation` | Swap the translation overlay for the raw key and back |
| `:X18nToggleOrigin` | Toggle raw-key visibility while translations stay active |
| `:X18nToggleLocaleFileEol` | Toggle end-of-line translations in locale files |
| `:X18nStatus` | Show projects, locales, progress, mode and EOL state |
| `:X18nExplain` | Show how the server understood the workspace |
| `:X18nOpenUi` | Open the x18n web UI in the browser |

Everything is also reachable as Lua for keymaps:

```lua
local actions = require 'x18n.actions'

vim.keymap.set('n', '<leader>tt', function() actions.show_translations() end)
vim.keymap.set('n', '<leader>tn', function() require('x18n.locales').next() end)
vim.keymap.set('n', '<leader>tj', function() actions.next_definition() end)
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
vim.keymap.set('n', '<leader>tk', function() require('x18n.keys').pick 'choose_locale' end)
```

`show_translations` returns `false` when the cursor is not on a key, so it chains with a fallback:

```lua
vim.keymap.set({ 'n', 'i' }, '<C-k>', function()
  if not require('x18n.actions').show_translations() then
    vim.lsp.buf.signature_help()
  end
end)
```

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

The key, search and usage pickers go through `vim.ui.select`, so [dressing.nvim](https://github.com/folke/dressing.nvim), [telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim) or [snacks.nvim](https://github.com/folke/snacks.nvim) render them in your picker of choice. Definitions use the quickfix, like references.

## Configuration

`setup` merges these over the defaults:

```lua
require('x18n').setup {
  lsp = { --[[ cmd, filetypes, root_markers, init_options ]] } or false,
  decorations = {
    enabled = true,
    mode = 'conceal', -- conceal | both | translation | translation_conceal | origin | inline | eol
    show_locale_file_eol_translation = true,
    show_locale_file_eol_usage = true,
    debounce_ms = 400,
    cursor_redraw_ms = 100,
  },
  navigation = { open_cmd = 'edit' }, -- edit | split | vsplit | tabedit
  translation_popup = { keys = { copy_key = { '<C-y>' } } },
  diagnostic = true, -- false suppresses; a table forwards to vim.diagnostic.config
  usage = { notify_no_key = true },
}
```

The server watches files, so locale edits and config changes reload automatically. `:X18nReload` restarts the client for a clean reindex.

Locale flags come from the server. Set `lsp.init_options.showFlags = false` to show locale codes only in hovers and completion docs, for terminals whose emoji font lacks a flag. Quickfix definitions already use the locale codes.

## Coming from i18n.nvim

[yelog/i18n.nvim](https://github.com/yelog/i18n.nvim) parses locale files inside the plugin. Here the x18n server owns parsing, analysis and detection, so those features are native LSP or server config. Every user-facing command has a mapping:

| i18n.nvim | Here |
| --- | --- |
| `:I18nEnable` / `:I18nDisable` | `:X18nEnable` / `:X18nDisable` |
| `:I18nReload` | `:X18nReload` (the server also watches files) |
| `:I18nStatus` | `:X18nStatus` |
| `:I18nDetectFramework` | `:X18nExplain` |
| `:I18nNextLocale` | `:X18nNextLocale` |
| `:I18nToggleTranslation` | `:X18nToggleTranslation` (master `:X18nToggleDecorations` still exists) |
| `:I18nToggleOrigin` | `:X18nToggleOrigin` |
| `:I18nToggleLocaleFileEol` | `:X18nToggleLocaleFileEol` |
| `show_mode` `both` / `translation` / `translation_conceal` / `origin` | the same names in `decorations.mode`, plus `set_mode` / `get_mode` |
| `:I18nShowTranslations` | `:X18nShowTranslations`, with `translation_popup.keys.copy_key` in the float |
| `:I18nDefinitionNextLocale` | `:X18nNextDefinition` |
| `i18n_definition()` | `:X18nDefinition` or `require('x18n.actions').definition()`; lists the locale definitions in the quickfix (upstream jumps directly) |
| `:I18nKeyUsages` | `:X18nKeyUsages` |
| `:I18nAddKey` | `Ctrl+.` per-locale code actions, or `:X18nAddKey` for the batch prompt (refuses keys that already exist; edits stay unsaved for review) |
| `i18n_keys` picker | `:X18nKeys [action]` with `jump`, `split`, `vsplit`, `tab`, `copy`, `copy_translation` and `choose_locale`; the list shows key and source value, and the translations popup shows the rest |
| `navigation.open_cmd` | the same option |
| `diagnostic = false` or a table | the same option |
| locale-file EOL and usage badges | both on by default; `:X18nToggleLocaleFileEol` and `show_locale_file_eol_usage` are independent |
| diagnostics | native LSP diagnostics from the server |
| blink.cmp / nvim-cmp source | native LSP completion: items carry the source value as detail and replace the key slot; `completionItem/resolve` supplies the all-locale documentation panel |
| fzf-lua / telescope / snacks pickers | `vim.ui.select`, so snacks, telescope-ui-select or dressing render them |
| `usage.popup_type` | `vim.ui.select` (no backend switch) |
| `usage.notify_no_key` | the same option |
| `usage.max_file_size`, `usage.scan_on_startup`, `func_pattern`, `func_type` | server config in `x18n.config.*` |
| JSON/YAML/.properties/JS/TS parsing, Spring messages, auto-detect, project config, namespace resolver | server |
| `sources` / `locales` config | [`x18n.config.ts`](https://x18n.dev) in the project, not plugin opts |

## Debugging

Set `vim.g.x18n_debug = true` to log protocol requests and responses. Run `:X18nExplain` when the server finds nothing, and see `:checkhealth x18n` for a status overview.

The repository carries a headless test suite against the real server. Each test copies `test/fixture` to a temp directory and runs there, so `playground/` stays a live sandbox and its edits do not affect the suite. The harness uses the fork binary linked by `playground/package.json` (`file:../../../f/x18n`). Build that fork (`pnpm --filter @x18n/lsp build`) before running the suite, so structured hover, completion documentation and usage badges are exercised:

```sh
for t in test/*.lua; do [ "$t" = test/harness.lua ] || nvim -l test/harness.lua "$t"; done
```

## Roadmap

- Locale tree explorer (`x18n/tree`), review threads (`x18n/reviews`)
- Copy translate prompt (`x18n/translatePrompt`)

## License

[MIT](LICENSE)
