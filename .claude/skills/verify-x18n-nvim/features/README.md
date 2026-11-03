# x18n.nvim playground verification map

This directory is the maintained source for verifying the user-facing rendering of
x18n.nvim in the vendored upstream playground. Read this index first, then use the
matching feature file as the recipe.

## Baseline preconditions

- Run from the repository root; dependencies installed with `npm install`.
- The fork linked by the root `package.json` is built
  (`cd ~/f/x18n && pnpm --filter @x18n/lsp build`).
- `playground/` holds the upstream examples (`scripts/sync-playground.sh`).
- `scripts/doctor.sh` prints `ready`.
- Every journey starts from a clean temp copy of the project. The wrapper copies
  `playground/<project>` into `$TMPDIR/x18n-verify.*`; the vendored tree and the
  user's editor state are never touched.
- There is no long-lived app server. Each project runs in its own headless nvim;
  the x18n server is a child of that nvim and exits with it.

## Driving conventions

- Run every recipe through `scripts/verify-playground.sh`; do not hand-edit the
  vendored playground or drive a shared editor instance.
- One project and one evidence directory per run:
  `scripts/verify-playground.sh --project <name> --out <dir>`.
- All projects: omit `--project`.
- One locale: add `--locale <code>`. The code must belong to the project.
- Read `<out>/summary.md` first, then `<out>/<project>.md` and the matching
  `<out>/screens/*.txt` evidence.
- Treat every command as literal. Keep quoted names and flags unchanged.
- The checker uses the plugin's default `decorations.mode = 'conceal'`; the other
  modes are not part of this map yet.

## Proof and skip reporting

- The proof is the SCREEN line in `<out>/screens/*.txt`: the actual nvim grid cell
  text after `redraw`, with the cursor on a non-decorated line, compared with the
  line rebuilt from the server's `x18n/decorations` reply.
- A passing file/locale also records at least one `x18n get --json` cross-check of
  a value read directly from the locale files.
- Diagnostics are hidden on the screen so the comparison sees decoration text
  only. A missing key covered by a `missing-key` diagnostic is recorded as its own
  passing check; the plugin intentionally suppresses the arrow in that case.
- A file that does not attach an x18n client is a **failure**, not a skip. The
  report names the detected filetype and the current `lsp.filetypes`.
- Do not report a project as verified through a different project's file, and do
  not weaken a journey because a known product gap exists. List the gap in
  `Gotchas`.

## Current baseline (2026-11-03)

All eight pass after the filetype and embedded-`<i18n>` fixes. A later failure is
a regression unless the playground itself changed.

| Project | Result | Covered |
| --- | --- | --- |
| `vue-vite` | PASS | `App.vue`, `TodoList.vue`, `main.ts`; en/de/ja |
| `react-i18next` | PASS | both files; en/fr |
| `next-intl` | PASS | both files; en/es |
| `laravel` | PASS | Blade and PHP; en/de |
| `rails` | PASS | ERB; en/es |
| `angular` | PASS | TS and HTML; en/pt-BR |
| `monorepo` | PASS | web en/fr, docs en |
| `i18n-ally` | PASS | en/zh-CN |

## Features

- [Inline translations](./inline-translations.md) covers key replacement, values,
  missing keys, dynamic expressions, and the per-stack matrix.
- [Display locale](./display-locale.md) covers default locale values, switching,
  and the locale-file cross-check.
- [Missing and dynamic keys](./missing-and-dynamic.md) covers arrows and the
  diagnostic-yield rule.
