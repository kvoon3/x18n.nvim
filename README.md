# x18n.nvim

[Neovim](https://neovim.io) integration for [x18n](https://x18n.dev) — an i18n toolkit that reads a project's locale files, reports missing, unused and broken keys, and edits them safely.

The language server speaks plain LSP (completion, hover, rename, references, code lens, inlay hints, diagnostics), which Neovim handles natively. This plugin adds what standard LSP cannot express: the custom `x18n/*` protocol as editor UI.

## Features

- **Inline translations** — replaces every `t('key')` call with its translation in the display locale, concealing the source call; press `K` on a replaced call to see the original source plus every locale in a floating panel. Missing keys keep their source and get a red `→ missing` marker.
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

## Configuration

```lua
{
  'kvoon3/x18n.nvim',
  opts = {
    decorations = {
      mode = 'replace', -- 'replace' | 'inline' (append after the call) | 'eol'
      conceal = true, -- set conceallevel/concealcursor so the source call is hidden
      wrap = false, -- nowrap while replacements are shown; insert restores wrapping
    },
    hover = {
      keymap = 'K', -- buffer-local; false keeps the default LSP hover
    },
  },
}
```

`replace` conceals the `t('key')` call and draws the translation in its place; insert mode drops the decorations so the real source is editable. `K` on a replaced call shows the hidden source line and the value of every locale, with the current display locale highlighted. `wrap = false` avoids a Neovim quirk where inline virtual text wraps against the concealed columns and pushes trailing punctuation onto its own row.

## Playground

`playground/` is a self-contained demo project (three locales, a missing key, an unused key, hard-coded strings) that runs against the local `@x18n/lsp`:

```sh
cd playground
npm install
nvim -u init.lua
```

The init prepends this repository to `runtimepath`, puts `playground/node_modules/.bin` first on `PATH`, and opens `src/main.ts`. Try `K` on a replaced call, `:X18nDisplayLocale zh-CN`, `:X18nUsageReport`, and `:X18nExtract` in `src/settings.ts`. See [`playground/README.md`](playground/README.md) for the full tour.

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
