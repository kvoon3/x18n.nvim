# Roadmap

## Now: editor features

- Locale tree explorer through `x18n/tree`.
- Review threads through `x18n/reviews`.
- Copy translate prompt through `x18n/translatePrompt`.

## Later

- Param filling from imports, props and other non-literal expressions. The
  scanner needs to resolve them without the cross-block scope that was removed.
- Svelte and other template languages, once their scanners expose the same
  usage ranges.

## Not planned

- A machine translation backend. The server's translate prompts cover it.
- A picker backend. `vim.ui.select` lets the user choose one.
- A second hover format. The plugin reads `x18n/keyInfo`; standard hover stays
  upstream's markdown.

## Done

- Usage counts in `x18n/fileKeys` (#133), `x18n/keyInfo` (#135), static param
  values and param-filled decoration and inlay-hint values (#139, #140), and
  the executable server entry (#132) merged upstream and shipped in v0.1.11
  through v0.1.13.
- The plugin requires `@x18n/lsp` 0.1.13 and drops the keyInfo probe, the
  old-server fallbacks and the separate server test target. The suite runs
  against the published server.
- Hover flush, component decorations and completion resolve merged upstream
  (#127, #129, #130) and shipped in v0.1.10.
- Key details moved from standard hover to `x18n/keyInfo`.
- Markdown hover fallback, locale index pairing and the `copy_translation`
  source fallback removed.
- Static param values limited to string literals and same-block string bindings.
- Locale-file annotations show the usage count; the display value is opt-in.
