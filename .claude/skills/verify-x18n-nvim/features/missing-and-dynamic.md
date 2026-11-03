# Missing and dynamic keys

Not every usage resolves to a value. A key absent from the source locale is an
error the server marks with a diagnostic; a key absent from a target locale has no
inline value; a dynamic expression cannot be resolved. The plugin must show each
state without inventing a translation.

## Sub-features

- `missing-diagnostic-yield` suppresses the inline missing arrow when the server
  already publishes a `missing-key` diagnostic on the same line, so the error is
  not doubled.
- `missing-arrow` appends `→ missing` when the key exists in the source but not in
  the chosen target locale (no code diagnostic on the line).
- `dynamic-arrow` keeps the expression and appends `→ dynamic`.
- `multi-usage` replaces two usages on one line (the vue-vite ternary in
  `src/main.ts`) without disturbing either side of the expression.

## How to get to it (user POV)

- Open a playground file with a deliberately missing key: vue-vite
  `src/App.vue` (`nav.contact`), react-i18next `src/Cart.tsx` (`auth:logout` in
  fr), react-i18next `src/Login.tsx` (`submit`, `forgot` in fr).
- Open vue-vite `src/App.vue` for the dynamic `pages.${page}.title` expression.
- No command is needed; the states render with the normal decorations.

## Driving it with verify-playground.sh

Preconditions:

- `scripts/doctor.sh` reports `ready`.
- The source locale is `en` and the target locale comes from the project list.
- Diagnostics are hidden by the checker; a source-missing key is therefore checked
  through `vim.diagnostic.get`, not through the screen text.

- **Diagnostic yield.** Drive vue-vite in en. Run
  `scripts/verify-playground.sh --project vue-vite --locale en --out /tmp/x18n-vue-en`.
  `src/App.vue` line 19 (`nav.contact`) produces a PASS check whose message is
  `missing-key diagnostic covers the line; the translation arrow yields`; the
  screen block for that line is absent because the plugin renders no arrow.
- **Target-locale missing arrow.** Drive react-i18next in fr. Run
  `scripts/verify-playground.sh --project react-i18next --locale fr --out /tmp/x18n-react-fr`.
  `src/Cart.tsx` line 16 shows
  `SCREEN export const logoutLabel = (): string => i18next.t('auth:logout') → missing`
  and `RESULT PASS`; `src/Login.tsx` shows the same for `submit` and `forgot`.
- **Dynamic arrow.** Drive vue-vite in any locale. Run
  `scripts/verify-playground.sh --project vue-vite --locale ja --out /tmp/x18n-vue-ja`.
  The screen evidence for `src/App.vue` line 23 contains
  `SCREEN ... $t(`pages.${page}.title`) → dynamic` and `RESULT PASS`.
- **Multi-usage line.** Drive vue-vite in en. Run
  `scripts/verify-playground.sh --project vue-vite --locale en --out /tmp/x18n-vue-en`.
  The `src/main.ts` evidence has one line with both
  `Network error` and `Something went wrong`; the CLI cross-check agrees with
  `errors.network`.
- **Proof.** Read the relevant screen block and the project report. Run
  `rg -n -A4 "nav.contact|dynamic|auth:logout" <out>/screens/`. The SCREEN line and
  RESULT must agree; the diagnostic-yield check is in `<out>/vue-vite.json`, not
  in the screen file.

## Gotchas

- The arrow is intentionally absent when a `missing-key` diagnostic covers the
  line. Do not report that as a failure; the suppressed path is a separate passing
  check.
- The checker hides diagnostic virtual text so the decoration text can be compared
  exactly. A real editor shows the diagnostic message at the end of the line on
  top of the raw key.
- The `missing-translation` warning mirror (a diagnostic on code usages) does not
  suppress the decoration arrow; it is a different diagnostic code and carries no
  `user_data.key`.
- A dynamic key is not an error and is never resolved. `→ dynamic` is the expected
  text.
- Directive and attribute usages (`v-t`, `[translate]`) have no enclosing call, so
  a missing marker is placed at the key range end inside the attribute value, for
  example `[translate]="'HOME.SUBTITLE → missing'"`. The state is correct; the
  position is cosmetic.
- A missing key in the source locale and a missing key in a target locale render
  differently: the first yields to the diagnostic, the second shows `→ missing`.
- Empty string values are not present in the playground; the plugin's fallback for
  them is `→ ok`, not `→ missing`.
