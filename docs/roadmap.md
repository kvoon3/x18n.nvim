# Roadmap

## Now: upstream the fork additions

The small fixes are merged. The remaining delta goes upstream in this order.

- `feat(lsp): report usage counts in x18n/fileKeys` (PR 4). The Neovim
  locale-file badge is the first consumer; the same field can drive VS Code and
  Zed annotations. Screenshot and draft PR are next.
- The param stack is held until the small PRs land:
  - `feat(builtins): record static param values on usages` (PR 5) records string
    literals and same-block string bindings on `Usage`.
  - `feat(lsp): fill static call params into decoration and inlay-hint values`
    (PR 6) fills simple placeholders in the displayed value.
- `x18n/keyInfo` (PR 7) needs an issue to settle the method name and shape before
  a PR.
- The server entry mode (PR 8) is a packaging fix.
- Keep the plugin tests running against the published server with
  `make test-upstream`.

Exit criteria: each addition is merged upstream and removed from the fork. The
fork keeps only `x18n/keyInfo` if upstream declines it, plus the generic changes
until they ship.

## Next: editor features

- Locale tree explorer through `x18n/tree`.
- Review threads through `x18n/reviews`.
- Copy translate prompt through `x18n/translatePrompt`.
- Per-call previews: let the popup fill the current usage's static params and
  label the result as a preview.

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

- Hover flush, component decorations and completion resolve merged upstream
  (#127, #129, #130).
- Fork synced to upstream `a44a460` (v0.1.9 plus one commit).
- Key details moved from standard hover to `x18n/keyInfo`.
- Markdown hover fallback, locale index pairing and the `copy_translation`
  source fallback removed.
- Static param values limited to string literals and same-block string bindings.
- Upstream test lane added.
- Locale-file annotations show the usage count; the display value is opt-in.
