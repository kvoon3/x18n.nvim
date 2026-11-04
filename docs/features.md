# Features

x18n.nvim is the editor surface of the x18n server. The server speaks plain LSP
(completion, hover, rename, references, code lens, inlay hints, diagnostics),
which Neovim handles natively. The plugin adds what standard LSP cannot express:
the custom `x18n/*` protocol as editor UI.

## Inline translations

The key reads as its value, `t('app.title')` renders as `t(Hello x18n)`, in the
display locale of your choice. Static call params fill the message placeholders,
so `t('app.greeting', { name: 'Ada' })` reads `t(Hello Ada!)`; a param the
scanner cannot resolve keeps its placeholder as written.

The cursor's line falls back to the raw key with the value at the end of the
line, so what you edit stays visible. Modes cover both worlds:

- `conceal` (default)
- `inline`
- `eol`
- i18n.nvim's `both`, `translation`, `translation_conceal` and `origin`

`:X18nToggleTranslation` swaps the overlay for the raw key and back;
`:X18nToggleOrigin` flips raw-key visibility without losing the mode. Missing
keys yield to the server's diagnostic instead of doubling it.

In conceal modes `conceallevel` is raised to 2 in the windows the plugin
decorates and restored on mode change or `:X18nToggleDecorations`.

## Completion

Native LSP completion inside `t('...')` slots. Items carry the source value as
detail; the selected item resolves to a documentation panel with its value in
every locale, missing ones marked.

## Locale-file annotations

Inside `en.json`, `zh-CN.json`, `ja.json`, `fr.json` and friends, each key line
shows its usage count and its value in the display locale at the end of the
line. Both segments have their own switch: `:X18nToggleLocaleFileEol` for the
value, `show_locale_file_eol_usage = false` for the badge.

## Definition and usages

On x18n buffers `gd` lists the key's locale definitions in the quickfix, the
same list as `grr`, and jumps to the chosen entry (a single definition jumps
directly); `:X18nDefinition` does the same from the command line.
`:X18nKeyUsages` jumps to the key's usages, with a picker when several files
use it.

## Usage report

Missing and unused keys as a quickfix list, with jumps into the exact locale
files.

## Value search

Fuzzy search by translated value, pick a result and jump to its definition.

## Key picker

All keys of the workspace through `vim.ui.select` (so it uses whichever picker
you have configured), with `jump` (display locale), `split`, `vsplit`, `tab`,
`copy_key`, `copy_translation` and `choose_locale` actions.

## Add missing keys

On a missing key, `Ctrl+.` offers one code action per locale. Choosing one
prompts for the value and stages it in that locale's buffer only; no empty
values are written to the other locales. `:X18nAddKey` remains the batch prompt
for every locale. Edits are unsaved buffers you review and save (like extract).

## Locale cycling

Cycle the display locale, and cycle the key under the cursor through the locale
files that define it.

## Translations popup

Every locale of the key under the cursor in one float, with usage counts and a
copy-key mapping inside the float.

## Extract hard strings

Rewrites the string literals of the current buffer into locale files (applied
by the server via `workspace/applyEdit`).

## Web UI

Opens the x18n web UI in your browser.

## Status and explain

Translation progress per locale, the active display mode, and how the server
understood the workspace.

## Lifecycle and diagnostics

`:X18nEnable`, `:X18nDisable` and `:X18nReload` drive the client, and
`diagnostic = false` or a `vim.diagnostic.config` table tunes the server's
diagnostics. A key missing from target locales is a warning on its
source-locale entry; the plugin mirrors that warning onto every usage in code,
so the code line shows the missing locales without opening the locale file.

`:checkhealth x18n` reports the client, server binary and project state.

## Keymaps and hover

`gh` and `gd` are chained on x18n buffers. On a key `gh` opens the translations
popup and `gd` lists the key's locale definitions in the quickfix; elsewhere
both fall back to the binding that was there before (usually LSP hover and
definition). No keymap setup is needed.

Mouse hover shows the same data through whichever hover plugin you use
(eagle.nvim renders the server hover; the server omits VS Code `command:` links
unless the client opts into them with `lsp.init_options.hoverCommands`, an
array of command names, and this plugin opts into none). Hovering the rendered
translation or the closing parenthesis resolves the key. A line-end annotation
resolves it too when the line has one key; a line with several keys stays
ambiguous at its end. Definition and usage commands still require the key
literal.

The key, search and usage pickers go through `vim.ui.select`, so
[dressing.nvim](https://github.com/folke/dressing.nvim),
[telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim)
or [snacks.nvim](https://github.com/folke/snacks.nvim) render them in your
picker of choice. Definitions use the quickfix, like references.

## Server fork and upstream

Structured hover data, whole-call and line-end hover, completion documentation,
locale-file usage counts, locale-labeled implementation jumps and param-filled
annotation values come from the `kvoon3/x18n` fork.

With an upstream server the popup falls back to parsing the hover markdown,
completion keeps the detail line but has no documentation panel, locale-file
annotations show the translation without the usage badge, choose-locale falls
back to the project locale order, hover only resolves the key literal, and the
inline value keeps its placeholders.
