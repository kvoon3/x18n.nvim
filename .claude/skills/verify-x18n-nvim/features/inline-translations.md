# Inline translations

The plugin replaces each i18n key literal with its display-locale value in the
source file, so a user reads the translated text at the call site. This is the
primary surface on every playground stack.

## Sub-features

- `inline-conceal` replaces the quoted key in `t('key')`, `$t('key')`,
  `i18next.t('key')`, `v-t`, `| translate`, `__()`, `trans()` and `t(".key")` with
  the display-locale value, hiding the quotes too.
- `inline-stacks` covers Vue, React/TSX, Next/TSX, Laravel Blade/PHP, Rails ERB,
  Angular TS/HTML, the monorepo web/docs split and i18n-ally.
- `inline-multi` renders two or more usages on one line without shifting the
  surrounding template text.
- `inline-dynamic` keeps the raw expression and appends `→ dynamic`.
- `inline-missing` keeps the raw key and shows either `→ missing` or the server's
  missing-key diagnostic (the arrow yields to the diagnostic).
- `inline-cross-check` verifies one rendered value per file/locale with the CLI's
  own read of the locale files.

## How to get to it (user POV)

- Open a source file of a playground project in Neovim. The plugin's default
  conceal mode renders the values automatically; no command is needed.
- Use `:X18nNextLocale` or `:X18nDisplayLocale <code>` to change the language of
  the rendered values.
- Inspect a call's translations with `gh`; the inline value is the same data.

## Driving it with verify-playground.sh

Preconditions:

- `scripts/doctor.sh` reports `ready`.
- The project has not been modified in `playground/` (the checker copies it).
- No other verification run is driving the same evidence directory.

- **Vue matrix.** Drive `vue-vite`. Run
  `scripts/verify-playground.sh --project vue-vite --out /tmp/x18n-vue`.
  `src/App.vue` passes 7 screen lines per locale; the evidence
  `screens/vue-vite__src_App_vue__en.txt` contains
  `RAW document.title = t('app.title')`,
  `SCREEN document.title = t(Playground)`, and `RESULT PASS`.
  `src/components/TodoList.vue` passes 4 lines per locale (including the
  `<i18n>` block's `local.hint`), and `src/main.ts` passes its two-usage ternary.
- **React matrix.** Drive `react-i18next`. Run
  `scripts/verify-playground.sh --project react-i18next --out /tmp/x18n-react`.
  `src/Cart.tsx` renders `i18next.t(Log out)` and
  `t(Welcome, {{name}}, { name })` in en and fr; the report is PASS.
- **Next matrix.** Drive `next-intl`. Run
  `scripts/verify-playground.sh --project next-intl --out /tmp/x18n-next`.
  Both `app/[locale]/page.tsx` and `pricing/page.tsx` pass in en and es.
- **Monorepo matrix.** Drive `monorepo`. Run
  `scripts/verify-playground.sh --project monorepo --out /tmp/x18n-mono`.
  `apps/web/src/App.vue` renders `$t(Web)` in en and fr;
  `apps/docs/src/index.ts` renders both `i18next.t(...)` values.
- **i18n-ally matrix.** Drive `i18n-ally`. Run
  `scripts/verify-playground.sh --project i18n-ally --out /tmp/x18n-ally`.
  `src/App.vue` renders `$t(Hello)` in en and the zh-CN value in zh-CN.
- **Laravel matrix.** Drive `laravel`. Run
  `scripts/verify-playground.sh --project laravel --out /tmp/x18n-laravel`.
  `dashboard.blade.php` renders `__(Dashboard)`, `__(Welcome, :name, ...)` and
  `__(Log out)`; `LoginController.php` renders
  `trans(These credentials do not match our records.)`. Both pass in en and de.
- **Rails matrix.** Drive `rails`. Run
  `scripts/verify-playground.sh --project rails --out /tmp/x18n-rails`.
  `index.html.erb` renders `t(All users)`, `t(No users yet)`,
  `t(Hello %{name}, ...)` and `t(Save)` in en; es translates the available keys
  and marks the rest `→ missing`.
- **Angular matrix.** Drive `angular`. Run
  `scripts/verify-playground.sh --project angular --out /tmp/x18n-angular`.
  `app.component.ts` passes in en and pt-BR; `app.component.html` renders
  `{{ Hello Angular | translate }}`, `[translate]="Translations with ngx-translate"`
  and `{{ Save | translate }}`.
- **Proof.** Capture the screen blocks and cross-check. Read
  `<out>/screens/vue-vite__src_App_vue__en.txt` and the `cross-check:` line in the same
  file. Both the SCREEN line and the CLI value must agree; the report must say
  PASS for every file that attached.

## Gotchas

- `lsp.filetypes` includes `html`, `php`, `blade`, `eruby` and `ruby` as well as
  the JS/TS family, Vue, Svelte, JSON and YAML. A new playground stack may need
  its filetype added; a `no x18n client attached` failure names the exact one.
- A component with an embedded `<i18n>` block (vue-vite
  `src/components/TodoList.vue`) is code first: its `t()` usages are decorated.
  The block's own keys are resources and are not rendered inline.
- Interpolated and plural values are literal strings: `t(Welcome, {{name}}, ...)`,
  `t(No tasks | One task | {n} tasks, ...)` and `t(Hello %{name}, ...)` are the
  expected rendering, not unresolved placeholders.
- Conceal always reveals the cursor line. The checker moves the cursor to a line
  without decorations; a one-line file gets a scratch blank line so its usage can
  be checked off-cursor.
- Diagnostics are hidden on the screen for a stable text comparison. Do not read
  the missing arrow on a line that has a `missing-key` diagnostic; see
  `missing-and-dynamic.md`.
- The checker uses the plugin defaults, not the user's dotfiles. A project with a
  nested `package.json` is rooted at that package; the monorepo manifest instead
  pins `x18n.config.*` so the intended monorepo config loads.
- Do not edit the vendored playground to make a journey pass; fix the plugin or
  record the gap.
