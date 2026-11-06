# Coming from i18n.nvim

[yelog/i18n.nvim](https://github.com/yelog/i18n.nvim) parses locale files inside
the plugin. Here the x18n server owns parsing, analysis and detection, so those
features are native LSP or server config. Every user-facing command has a
mapping:

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
| `i18n_definition()` | `:X18nDefinition` or `require('x18n.actions').definition()`; lists the locale definitions in the quickfix (a single definition jumps directly) |
| `:I18nKeyUsages` | `:X18nKeyUsages` |
| `:I18nAddKey` | `Ctrl+.` per-locale code actions, or `:X18nAddKey` for the batch prompt (refuses keys that already exist; edits stay unsaved for review) |
| `i18n_keys` picker | `:X18nKeys [action]` with `jump`, `split`, `vsplit`, `tab`, `copy`, `copy_translation` and `choose_locale`; the list shows key and source value, and the translations popup shows the rest |
| `navigation.open_cmd` | the same option |
| `diagnostic = false` or a table | the same option |
| locale-file EOL and usage badges | the usage badge is on by default and the value is opt-in; `:X18nToggleLocaleFileEol` and `show_locale_file_eol_usage` are independent |
| diagnostics | native LSP diagnostics from the server |
| blink.cmp / nvim-cmp source | native LSP completion: items carry the source value as detail, replace the key slot and resolve to the all-locale documentation panel |
| fzf-lua / telescope / snacks pickers | `vim.ui.select`, so snacks, telescope-ui-select or dressing render them |
| `usage.popup_type` | `vim.ui.select` (no backend switch) |
| `usage.notify_no_key` | the same option |
| `usage.max_file_size`, `usage.scan_on_startup`, `func_pattern`, `func_type` | server config in `x18n.config.*` |
| JSON/YAML/.properties/JS/TS parsing, Spring messages, auto-detect, project config, namespace resolver | server |
| `sources` / `locales` config | [`x18n.config.ts`](https://x18n.dev) in the project, not plugin opts |
