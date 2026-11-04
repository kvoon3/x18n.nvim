---
name: verify-x18n-nvim
description: Verify x18n.nvim renders translations in Neovim against the vendored upstream playground. Boots headless nvim with the real plugin and x18n server per project, switches every project locale, reads the actual screen cells, and compares them with the server's decorations plus a CLI cross-check. Use when decorations, display modes, locale switching, or LSP client filetypes change, or when asked whether keys are replaced by translated text correctly.
---

# Verify x18n.nvim translations in the playground

The user-facing surface is Neovim: the plugin asks the x18n language server for
each usage's display-locale value and renders it over the key literal. This skill
proves what a user actually sees by reading the nvim screen grid after redraw, not
by inspecting internal tables.

The repository vendors the upstream playground under `playground/` (see
`scripts/sync-playground.sh`). Each project is copied to a disposable temp
directory before it is driven, so the vendored tree and the user's editor state
are never touched.

## Launch

Prerequisites:

- Neovim 0.11+ and Node on `PATH`.
- Root dev dependencies installed: `npm install` at the repo root. This pins
  the published `@x18n/lsp` 0.1.10, the default server.
- The playground present: `playground/vue-vite`, `react-i18next`, `next-intl`,
  `laravel`, `rails`, `angular`, `monorepo`, `i18n-ally`.

To verify the fork-only features (keyInfo popup data, param-filled values,
locale-file usage counts), build the fork and export
`X18N_LSP_BIN=~/f/x18n/packages/lsp/bin.mjs` before any script below.

There is no long-lived app process. "Launch" is one headless nvim per project,
started by the wrapper; it copies the project, opens each manifest file, waits for
the client and decorations, and exits. A run is ready when the wrapper prints
`PASS`/`FAIL <project>` and a report path; the summary confirms the count.

Boot the whole matrix:

```sh
.claude/skills/verify-x18n-nvim/scripts/verify-playground.sh
```

Boot one project for a fast iteration:

```sh
.claude/skills/verify-x18n-nvim/scripts/verify-playground.sh --project vue-vite
```

Teardown is automatic: the wrapper removes the temp project copies on exit. The
headless nvim and its x18n child exit with the script; the checker has a 120 s
watchdog and the wrapper a 180 s alarm. Do not kill processes by name.

## Doctor

Run this first whenever a result looks off; it is read-only and starts no server.

```sh
.claude/skills/verify-x18n-nvim/scripts/doctor.sh
```

It checks Neovim, Node, `rsync`, the server binary (`X18N_LSP_BIN` or the root
`node_modules/@x18n/lsp/bin.mjs`) and its resolved `dist/index.mjs`, the builtins
build, the `x18n` CLI, all eight playground directories, and that
`nvim --clean --headless` starts. The last line is `ready` or `not ready`; the
exit code is the gate.

## Drive

```sh
# All projects, every locale the server reports for each project.
.claude/skills/verify-x18n-nvim/scripts/verify-playground.sh

# One project, all of its locales, a named evidence directory.
.claude/skills/verify-x18n-nvim/scripts/verify-playground.sh \
  --project react-i18next --out /tmp/x18n-react

# One locale only; it must belong to the project.
.claude/skills/verify-x18n-nvim/scripts/verify-playground.sh \
  --project vue-vite --locale de

# Keep the temp project copies for debugging.
.claude/skills/verify-x18n-nvim/scripts/verify-playground.sh \
  --project next-intl --keep-temp
```

Options: `--project <name>`, `--locale <code>`, `--out <dir>`, `--all`,
`--skip-doctor`, `--keep-temp`. Default evidence directory:
`${XDG_CACHE_HOME:-$HOME/.cache}/x18n-nvim-verify/<UTC timestamp>-<pid>/`.

For each project the checker:

1. rsyncs `playground/<project>` to `$TMPDIR/x18n-verify.*/<project>`;
2. starts `nvim --clean --headless` with a 300x600 grid, prepends the plugin,
   disables diagnostic virtual text/signs (so the screen contains only decoration
   text), and configures the server binary (`X18N_LSP_BIN` or the root
   devDependency) and project root markers;
3. opens every file in `scripts/playgrounds.lua`, runs `filetype detect`, and
   waits for the x18n client and decoration extmarks;
4. reads `x18n/projects`, determines the file's project and locale list, and sets
   each locale through `require('x18n.actions').set_display_locale`, the same path
   as `:X18nDisplayLocale`;
5. moves the cursor to a line without decorations (conceal always reveals the
   cursor line), redraws, and reads the rendered cells with
   `screenstring(screenpos(...).row, col)`;
6. rebuilds the expected line from the server's `x18n/decorations` reply, runs
   `x18n get <key> --root <project> --json` for one value per file/locale, and
   compares.

Read the proof:

- `<out>/summary.md` — project matrix and failures
- `<out>/<project>.md` — per-file, per-locale pass/fail counts
- `<out>/<project>.json` — every check with expected/actual
- `<out>/screens/<project>__<file>__<locale>.txt` — RAW / EXPECTED / SCREEN lines
- `<out>/<project>.log` — the headless nvim console

### One feature end to end

`inline-translations` on `vue-vite`:

```sh
.claude/skills/verify-x18n-nvim/scripts/verify-playground.sh \
  --project vue-vite --out /tmp/x18n-vue-vite
sed -n '1,40p' /tmp/x18n-vue-vite/vue-vite.md
sed -n '1,30p' /tmp/x18n-vue-vite/screens/vue-vite__src_App_vue__en.txt
```

A passing screen block looks like:

```
RAW      : document.title = t('app.title')
EXPECTED : document.title = t(Playground)
SCREEN   : document.title = t(Playground)
RESULT   : PASS
```

The screen line is the actual nvim grid; expected comes from the server's
decorations. The CLI cross-check at the end of the same locale evidence reads the
same key from the locale files through `x18n get --json`.

## Evidence

A proof is the `<out>/screens/*.txt` file plus the matching `<out>/<project>.md`
and `<out>/<project>.json`. It must show:

- the exact display locale and the neutral cursor line;
- the raw source line, the expected rendered line, and the actual SCREEN line;
- the cross-check result when enabled.

Standards:

- Exercise the real plugin and server. Never set decoration extmarks by hand or
  call `x18n/decorations` as the only proof; that is the oracle, not the surface.
- The screen read happens after `redraw` with the cursor away from the tested
  lines; conceal reveals the cursor line by design.
- Diagnostics are hidden for the screen so decoration text is compared in
  isolation. Missing keys covered by the server's `missing-key` diagnostic are
  verified as a separate check (the plugin intentionally suppresses the arrow).
- Missing keys with no diagnostic render `→ missing`; dynamic expressions render
  `→ dynamic`; both are compared as text.
- Failures are reported, not skipped. A file that does not attach a client is a
  failure naming the detected filetype and `lsp.filetypes`.

## Cleanup

The wrapper's `trap` deletes `$TMPDIR/x18n-verify.*` on success, failure, and
interrupt. `--keep-temp` prints the retained path for debugging. Evidence under
`--out` (including the default `~/.cache` path) is never removed by cleanup; the
proof survives the run. The vendored `playground/` is never written: the server's
cache lives in the temp copy.

## Helpers

| Helper | Invocation | Purpose |
| --- | --- | --- |
| `scripts/doctor.sh` | `.claude/skills/verify-x18n-nvim/scripts/doctor.sh` | read-only readiness check |
| `scripts/verify-playground.sh` | see Drive | matrix runner, evidence writer, cleanup |
| `scripts/playground-check.lua` | invoked by the wrapper | per-project headless checker |
| `scripts/playgrounds.lua` | data file | project → files and root markers |

`playgrounds.lua` is the maintained project list. Add a new upstream playground
there, then extend the wrapper's project list (kept in sync by a comment) and the
feature map Gotchas if it uses a new filetype or locale layout.

## Current baseline (2026-11-04)

All eight playgrounds pass against the published `@x18n/lsp` 0.1.10, the default
server. The fixes this verifier drove:

- `lsp.filetypes` now includes `html`, `php`, `blade`, `eruby` and `ruby`, so
  Laravel, Rails and the Angular template attach.
- `x18n/decorations` returns code usages for a component with an embedded
  `<i18n>` block (merged in x18n 0.1.10, PR #129), so vue-vite `TodoList.vue`
  renders its inline values.
- Usages without an enclosing call (the `v-t` directive) no longer crash render;
  the fallback uses the key range (`lua/x18n/decorations.lua`).

A failure in a later run is a regression unless the playground itself changed.
