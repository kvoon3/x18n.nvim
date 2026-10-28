# x18n.nvim

[Neovim](https://neovim.io) integration for [x18n](https://x18n.dev) — an i18n toolkit that reads a project's locale files, reports missing, unused and broken keys, and edits them safely.

The language server speaks plain LSP (completion, hover, rename, references, code lens, inlay hints, diagnostics), which Neovim handles natively. This plugin adds what standard LSP cannot express: the custom `x18n/*` protocol as editor UI.

## Features

- **Inline translations** — shows the translated value right after every `t('key')` call (or at the end of the line), in the display locale of your choice, with a distinct style for missing keys.
- **Usage report** — missing and unused keys as a quickfix list, with jumps into the exact locale files.
- **Value search** — fuzzy search by translated value, pick a result and jump to its definition.
- **Extract hard strings** — rewrites the string literals of the current buffer into locale files (applied by the server via `workspace/applyEdit`).
- **Display locale switch** — changes the locale used by hovers, inlay hints and decorations on the fly.
- **Web UI** — opens the x18n web UI in your browser.
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

The LSP client is configured and enabled automatically. Call `setup` with `lsp = false` to manage `vim.lsp.config('x18n', ...)` yourself (e.g. when [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) ships its own definition), and with `decorations = false` to disable the inline annotations.

## Commands

| Command | Description |
| --- | --- |
| `:X18nExtract` | Extract hard strings of the current buffer into locale files |
| `:X18nUsageReport` | List missing and unused keys in the quickfix |
| `:X18nSearch [query]` | Search keys by translated value, jump to the chosen definition |
| `:X18nDisplayLocale {locale}` | Switch the locale shown in hovers and decorations |
| `:X18nOpenUi` | Open the x18n web UI in the browser |

## Debugging

Set `vim.g.x18n_debug = true` to log protocol requests and responses. See `:checkhealth x18n` for a status overview.

## Roadmap

- Locale tree explorer (`x18n/tree`), translation progress (`x18n/progress`)
- Picker adapters (Snacks, fzf-lua, mini.pick) for `:X18nSearch`

## License

[MIT](LICENSE)
