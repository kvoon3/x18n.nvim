# x18n.nvim

[Neovim](https://neovim.io) integration for [x18n](https://x18n.dev) — an i18n toolkit that reads a project's locale files, reports missing, unused and broken keys, and edits them safely.

The language server speaks plain LSP (completion, hover, rename, references, code lens, inlay hints, diagnostics), which Neovim handles natively. This plugin adds what standard LSP cannot express: the custom `x18n/*` protocol as editor UI.

## Features

- **Inline translations** — shows the translated value right after every `t('key')` call (or at the end of the line), in the display locale of your choice. With `decorations = { mode = 'conceal' }` the key reads as its value, `t(Hello x18n)`, and the cursor's line shows the raw key with the value at the end of the line. Missing keys yield to the server's diagnostic instead of doubling it.
- **Locale-file annotations** — inside `en.json`, `zh.json` and friends, each key line shows its value in the display locale at the end of the line, so you can translate against the source language.
- **Usage report** — missing and unused keys as a quickfix list, with jumps into the exact locale files.
- **Value search** — fuzzy search by translated value, pick a result and jump to its definition.
- **Key picker** — all keys of the workspace through `vim.ui.select` (so it uses whichever picker you have configured), with jump and copy actions.
- **Add missing keys** — an interactive per-locale input stages the key under the cursor in the locale files, as unsaved buffers you review and save (like extract).
- **Locale cycling** — cycle the display locale, and cycle the key under the cursor through the locale files that define it.
- **Translations popup** — every locale of the key under the cursor in one float, with usage counts.
- **Extract hard strings** — rewrites the string literals of the current buffer into locale files (applied by the server via `workspace/applyEdit`).
- **Web UI** — opens the x18n web UI in your browser.
- **Status and explain** — translation progress per locale, and how the server understood the workspace.
- `:checkhealth x18n` support.

## Requirements

- Neovim 0.11+ (`vim.lsp.config`)
- [`x18n-lsp`](https://x18n.dev): `npm install -g @x18n/lsp`

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'kvoon3/x18n.nvim',
  opts = {},
}
```

The LSP client is configured and enabled automatically. Call `setup` with `lsp = false` to manage `vim.lsp.config('x18n', ...)` yourself (e.g. when [nvim-lspconfig](https://github.com/folke/nvim-lspconfig) ships its own definition), and with `decorations = false` to disable the inline annotations.

Decorations take a `mode`: `'inline'` (default) puts the value right after the call, `'eol'` at the end of the line, and `'conceal'` replaces the key literal with the value, so `t('app.title')` reads `t(Hello x18n)`. In conceal mode the cursor's line falls back to the raw key with the value as an end-of-line arrow, redrawn as the cursor moves; `conceallevel` is raised to 2 in the windows it decorates and `:X18nToggleDecorations` puts it back. Missing keys always yield to the server's diagnostic instead of doubling it.

## Commands

| Command | Description |
| --- | --- |
| `:X18nShowTranslations` | Popup with every locale of the key under the cursor |
| `:X18nNextDefinition` | Jump to the key under the cursor in the next locale file |
| `:X18nAddKey [key]` | Add the key under the cursor (or the given key) to the locale files |
| `:X18nKeys [copy]` | Pick a key and jump to it, or copy the key |
| `:X18nUsageReport` | List missing and unused keys in the quickfix |
| `:X18nSearch [query]` | Search keys by translated value, jump to the chosen definition |
| `:X18nExtract` | Extract hard strings of the current buffer into locale files |
| `:X18nNextLocale` | Cycle the display locale |
| `:X18nDisplayLocale {locale}` | Switch the locale shown in hovers and decorations (completes) |
| `:X18nToggleDecorations` | Hide and restore the inline translations |
| `:X18nStatus` | Show projects, locales and translation progress |
| `:X18nExplain` | Show how the server understood the workspace |
| `:X18nOpenUi` | Open the x18n web UI in the browser |

Everything is also reachable as Lua for keymaps:

```lua
vim.keymap.set('n', '<leader>tt', function() require('x18n.actions').show_translations() end)
vim.keymap.set('n', '<leader>tn', function() require('x18n.locales').next() end)
vim.keymap.set('n', '<leader>tj', function() require('x18n.actions').next_definition() end)
```

`show_translations` returns `false` when the cursor is not on a key, so it chains with a fallback:

```lua
vim.keymap.set({ 'n', 'i' }, '<C-k>', function()
  if not require('x18n.actions').show_translations() then
    vim.lsp.buf.signature_help()
  end
end)
```

The pickers go through `vim.ui.select`, so [dressing.nvim](https://github.com/folke/dressing.nvim), [telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim) or [snacks.nvim](https://github.com/folke/snacks.nvim) render them in your picker of choice.

## Coming from i18n.nvim

[yelog/i18n.nvim](https://github.com/yelog/i18n.nvim) parses locale files inside the plugin. Here the server owns parsing and analysis, so several of its features are native LSP and need no command:

| i18n.nvim | Here |
| --- | --- |
| `:I18nShowTranslations` | `:X18nShowTranslations` |
| `:I18nDefinitionNextLocale` | `:X18nNextDefinition` |
| `:I18nAddKey` | `:X18nAddKey` (refuses keys that already exist; edits stay unsaved for review) |
| `i18n_keys` picker | `:X18nKeys` (jump and copy; no split, vsplit or choose-locale opens) |
| `:I18nKeyUsages` | `vim.lsp.buf.references()` |
| jump to definition | `vim.lsp.buf.definition()` |
| diagnostics | native LSP diagnostics from the server |
| completion sources | native LSP completion (blink.cmp and nvim-cmp pick it up) |
| `blink.cmp` / `nvim-cmp` source | no source needed: `completionProvider` with `'` `"` `` ` `` `.` `:` trigger characters; items carry the source value as detail and replace the whole key slot |
| help like `vim.lsp.buf.signature_help()` | `require('x18n.actions').show_translations()` chains with a fallback, see the keymap example above |
| `:I18nNextLocale` | `:X18nNextLocale` |
| `:I18nToggleTranslation` | `:X18nToggleDecorations` |
| `:I18nStatus` | `:X18nStatus` |
| `:I18nDetectFramework` | `:X18nExplain` |
| locale-file EOL translations | always on in the display locale; `:X18nToggleDecorations` toggles them together with the inline ones |
| `:I18nReload` | automatic: the server watches files |
| `:I18nEnable` / `:I18nDisable` | LSP root markers activate the server per project |
| `:I18nToggleOrigin` | the cursor's line always shows the raw key in conceal mode; `:X18nToggleDecorations` switches the whole overlay off |
| `sources` / `locales` config | [`x18n.config.ts`](https://x18n.dev) in the project, not plugin opts |

## Debugging

Set `vim.g.x18n_debug = true` to log protocol requests and responses. Run `:X18nExplain` when the server finds nothing, and see `:checkhealth x18n` for a status overview.

The repository carries a headless test suite against a real server:

```sh
for t in test/*.lua; do nvim -l test/harness.lua "$t"; done
```

## Roadmap

- Locale tree explorer (`x18n/tree`), review threads (`x18n/reviews`)
- Copy translate prompt (`x18n/translatePrompt`)

## License

[MIT](LICENSE)
