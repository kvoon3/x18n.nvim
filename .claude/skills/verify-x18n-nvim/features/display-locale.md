# Display locale

The plugin renders every key in one display locale at a time. Changing it must
change both the inline values and the hover/annotation data, and the values must
match the locale files, not a stale cache or another locale.

## Sub-features

- `locale-default` renders the project's default display locale (the source locale
  unless configured otherwise) on first attach.
- `locale-switch` changes the inline values through
  `:X18nDisplayLocale <code>` / `require('x18n.actions').set_display_locale`.
- `locale-matrix` covers every locale each project reports: vue-vite en/de/ja,
  react-i18next en/fr, next-intl en/es, laravel en/de, rails en/es, angular
  en/pt-BR, monorepo web en/fr + docs en, i18n-ally en/zh-CN.
- `locale-cross-check` reads one value per file/locale with
  `x18n get <key> --root <project> --json` and compares it with the decoration.
- `locale-missing` renders a key absent from the chosen locale as `→ missing` (or
  the server diagnostic) instead of leaking the source value.

## How to get to it (user POV)

- Open a playground source file; the default display locale renders immediately.
- Run `:X18nNextLocale` to cycle, or `:X18nDisplayLocale <code>` to choose one.
- The same value appears in `gh` (translations popup), hover, and locale-file
  end-of-line annotations.

## Driving it with verify-playground.sh

Preconditions:

- `scripts/doctor.sh` reports `ready`.
- The project's locale list is unchanged from the vendored playground.
- The chosen `--locale` belongs to the project; otherwise the checker fails the
  file with the available codes.

- **Default locale.** Drive one project without `--locale`. Run
  `scripts/verify-playground.sh --project react-i18next --out /tmp/x18n-react`.
  The evidence files start with `display locale: en` and every screen line is PASS.
- **German values.** Drive vue-vite in German. Run
  `scripts/verify-playground.sh --project vue-vite --locale de --out /tmp/x18n-vue-de`.
  `src/App.vue` reads `t('app.title')` as `t(Spielwiese)`; the report is PASS for
  the attached files.
- **Japanese values.** Drive vue-vite in Japanese. Run
  `scripts/verify-playground.sh --project vue-vite --locale ja --out /tmp/x18n-vue-ja`.
  The same line reads `t(プレイグラウンド)`; wide characters survive the screen
  comparison.
- **French values.** Drive react-i18next in French. Run
  `scripts/verify-playground.sh --project react-i18next --locale fr --out /tmp/x18n-react-fr`.
  `Cart.tsx` renders the French values; keys missing from fr render as missing.
- **Monorepo split.** Drive the monorepo in French. Run
  `scripts/verify-playground.sh --project monorepo --locale fr --out /tmp/x18n-mono-fr`.
  The docs file only has `en`, so the checker fails that file with
  `locale not in project; available: en`; this is expected and is not a display
  mismatch.
- **Proof.** Open a locale evidence file and read the header and cross-check. Run
  `sed -n '1,12p' /tmp/x18n-vue-de/screens/vue-vite__src_App_vue__de.txt`. It contains
  `display locale: de`, the `SCREEN` line with `Spielwiese`, `RESULT: PASS`, and a
  `cross-check:` line showing the CLI agrees.

## Gotchas

- The display locale is one setting on the client, shared by every project in the
  session. Switching it for one file also switches it for the others.
- `x18n/projects` reports the locales per project; a locale that belongs to
  another project is not valid for this file. The checker rejects it by name.
- The server answers `x18n/decorations` with the locale it used. The checker waits
  for that field to equal the requested code before comparing; a stale reply is a
  retry, not a failure.
- A project with only a source locale (monorepo docs) has no target locale to
  switch to; test it in `en` and record the limitation.
- Do not trust the locale code alone; the cross-check compares the value read from
  the locale files, which catches a wrong-locale render with the right header.
