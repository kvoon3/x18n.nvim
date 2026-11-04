# Configuration

`setup` merges these over the defaults:

```lua
require('x18n').setup {
  lsp = { --[[ cmd, filetypes, root_markers, init_options ]] } or false,
  decorations = {
    enabled = true,
    mode = 'conceal', -- conceal | both | translation | translation_conceal | origin | inline | eol
    show_locale_file_eol_translation = false, -- also show the display-locale value
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

## LSP client

The LSP client is configured and enabled automatically. Call `setup` with
`lsp = false` to manage `vim.lsp.config('x18n', ...)` yourself (e.g. when
[nvim-lspconfig](https://github.com/folke/nvim-lspconfig) ships its own
definition), and with `decorations = false` to disable the inline annotations.

The client attaches to JavaScript/TypeScript, Vue, Svelte, HTML, PHP/Blade,
ERB/Ruby, JSON and YAML buffers; the server decides whether the project has
locale resources.

The default `root_markers` include `package.json` and `.git`, so the client
starts in ordinary JS projects and the server auto-detects the stack, the same
detection the CLI and VS Code use. Narrowing `root_markers` to `x18n.config.*`
starts the client only in explicitly configured projects, at the cost of
skipping the auto-detected ones. The server stays resident in a root where it
finds no locale files; stop it with `:X18nDisable`.

## Display modes

Decorations take a `mode`:

- `'conceal'` (default) replaces the key literal with the value, so
  `t('app.title')` reads `t(Hello x18n)`, and the cursor's line falls back to
  the raw key with the value as an end-of-line arrow, redrawn as the cursor
  moves.
- `'inline'` puts the value right after the call.
- `'eol'` puts it at the end of the line.
- i18n.nvim's names work too: `'both'`, `'translation'`,
  `'translation_conceal'` and `'origin'`.

In conceal modes `conceallevel` is raised to 2 in the windows it decorates and
restored on mode change or `:X18nToggleDecorations`. Missing keys always yield
to the server's diagnostic instead of doubling it.

## Diagnostics

`diagnostic = true` shows the server's diagnostics. `diagnostic = false`
suppresses them and clears the ones already shown; a table is forwarded to
`vim.diagnostic.config` for the server's namespace.

## Locale flags

Locale flags come from the server. Set `lsp.init_options.showFlags = false` to
show locale codes only, for terminals whose emoji font lacks a flag. The setting
affects standard hover; with the fork it also affects the translations popup and
completion docs. Quickfix definitions use the locale codes.

## Reloading

The server watches files, so locale edits and config changes reload
automatically. `:X18nReload` restarts the client for a clean reindex.
