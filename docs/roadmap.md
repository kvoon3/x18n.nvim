# Roadmap

## Now: upstream the param stack

The remaining delta goes upstream in this order.

- `feat(builtins): record static param values on usages` (PR 5) records string
  literals and same-block string bindings on `Usage`.
- `feat(lsp): fill static call params into decoration and inlay-hint values`
  (PR 6) fills simple placeholders in the displayed value.
- `x18n/keyInfo` (PR 7) is open as
  [#135](https://github.com/x18n-dev/x18n/pull/135). Its param-filled values
  wait for the param stack.
- `make test` targets the published server; `make test-fork` covers the delta.

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

- The plugin targets the published `@x18n/lsp` 0.1.10; the root
  devDependencies no longer link the fork, and the published server is the
  default test lane.
- Key details moved from standard hover to `x18n/keyInfo`.
- Markdown hover fallback, locale index pairing and the `copy_translation`
  source fallback removed.
- Static param values limited to string literals and same-block string bindings.
- Published-server test lane added.
- Locale-file annotations show the usage count; the display value is opt-in.
