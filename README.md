# x18n.nvim

> [!WARNING]
> This project is under active development. Commands, options and the Lua API
> may change between releases.

[Neovim](https://neovim.io) integration for [x18n](https://x18n.dev) — an i18n
toolkit that reads a project's locale files, reports missing, unused and broken
keys, and edits them safely.

The language server speaks plain LSP (completion, hover, rename, references,
code lens, inlay hints, diagnostics), which Neovim handles natively. This plugin
adds what standard LSP cannot express: the custom `x18n/*` protocol as editor
UI.

## Features

- **Inline translations** — `t('app.title')` reads as `t(Hello x18n)` in the
  display locale, with static call params filled. Missing keys yield to the
  server's diagnostic.
- **Locale files** — usage counts beside every key line, with opt-in
  display-locale values.
- **Native LSP** — completion, hover, rename, references, code lens and
  diagnostics, with all-locale completion docs.
- **Navigation** — definition and usage lists, key and value search, locale
  cycling.
- **Editing** — per-locale code actions for missing keys, a batch add, and
  hard-string extraction.
- **Status** — `:X18nStatus`, `:X18nExplain` and `:checkhealth x18n`.

## Requirements

- Neovim 0.11+ (`vim.lsp.config`)
- [`x18n-lsp`](https://x18n.dev) 0.1.13 or newer: `npm install -g @x18n/lsp`

The published server implements standard LSP and the full `x18n/*` protocol the
plugin draws on, including `x18n/keyInfo`, locale-file usage counts and
param-filled inline annotations. `:checkhealth x18n` reports the running
version.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'kvoon3/x18n.nvim',
  opts = {},
}
```

The LSP client is configured and enabled automatically. Pass `lsp = false` to
manage `vim.lsp.config('x18n', ...)` yourself, `decorations = false` to disable
the inline annotations, or see [Configuration](docs/configuration.md) for every
option.

## License

[MIT](LICENSE)
