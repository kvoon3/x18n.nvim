# Roadmap

## Now: converge the fork

The plugin needs a small set of additions from the x18n server. The fork keeps
those additions until upstream accepts them.

- Keep the fork delta to `x18n/keyInfo`, completion resolve, param-filled
  values, component decorations, `fileKeys[].usages` and the hover flush.
- Send the generic changes upstream: param-filled values, completion resolve,
  component decorations, usage counts and the hover flush.
- Propose `x18n/keyInfo` upstream as an optional custom method. If upstream
  accepts it, drop the fork.
- Keep the plugin tests running against the published server with
  `make test-upstream`.

Exit criteria: the fork diff is one protocol method plus the generic changes,
the upstream lane passes, and `FORK.md` lists every remaining difference.

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

- Fork synced to upstream `a44a460` (v0.1.9 plus one commit).
- Key details moved from standard hover to `x18n/keyInfo`.
- Markdown hover fallback, locale index pairing and the `copy_translation`
  source fallback removed.
- Static param values limited to string literals and same-block constants.
- Upstream test lane added.
