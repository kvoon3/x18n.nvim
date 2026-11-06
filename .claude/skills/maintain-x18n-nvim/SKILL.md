---
name: maintain-x18n-nvim
description: Keep x18n.nvim aligned with the published @x18n/lsp server. Use when upgrading the x18n server or CLI, auditing a new x18n release, removing compatibility fallbacks, reconciling filetypes with x18n builtins, or checking why a server feature differs from the plugin.
---

# Maintain x18n.nvim

The plugin is a thin LSP client for the published x18n server. Maintenance means
proving which server features exist, moving the pins to the new version, deleting
every fallback the new server makes unnecessary, and keeping the client-side file
selection honest. The server is the source of truth. The plugin does not fork it.

## Ground rules

- Target the published `@x18n/lsp` and `@x18n/cli` only. Do not reintroduce the
  `kvoon3/x18n` fork, a local server checkout, or an `X18N_LSP_BIN` lane.
- The plugin tests always start the server from
  `node_modules/@x18n/lsp/bin.mjs`.
- Do not open PRs unless the user asks. Land on `main` only when asked.
- Ask before force-pushing a shared branch. Bundle branches before deleting them.
- The plugin renders the values the server returns. Do not add a client-side
  interpolation layer to cover a server gap.

## Current contract

Snapshot: 0.1.13, 2026-11-06.

- `package.json` pins `@x18n/lsp` and `@x18n/cli` in `devDependencies`.
  `package-lock.json` and the installed package must agree.
- `lua/x18n/health.lua` holds `MINIMUM_SERVER` and reports
  `client.server_info.version`. `test/health.lua` asserts the report.
- `lua/x18n/init.lua` holds the default `lsp.filetypes` attach list.
- `lua/x18n/decorations.lua` skips `x18n.config.*` buffers. Published 0.1.13
  scans its own config as source and returns missing keys for it.
- `x18n/keyInfo` returns the raw message in 0.1.13. Decorations and inlay hints
  fill static call params. The translations popup shows `keyInfo` values as the
  server returns them.
- The suite runs `make check` against the root devDependency. There is no second
  server lane.

## Upgrade pass

1. Read the current pins and the published versions.

   ```sh
   node -e "const p=require('./package.json'); console.log(p.devDependencies['@x18n/lsp'], p.devDependencies['@x18n/cli'])"
   npm view @x18n/lsp version
   npm view @x18n/cli version
   ```

2. Inspect the published package, not just the release notes. The installed
   `dist/index.d.mts` and `dist/src.mjs` are the contract the plugin can rely on.
   Check the custom methods, result fields and any behavior the plugin assumes.

3. Probe before deleting anything. Start the published server with a headless
   nvim script and send the same request the plugin sends. A feature is upstream
   only when the running server produces the expected response. Keep the probe
   out of the commit.

4. Bump `@x18n/lsp` and `@x18n/cli`, regenerate `package-lock.json`, and install.

5. Update `MINIMUM_SERVER` in `lua/x18n/health.lua`, `test/health.lua`, the
   requirements in `README.md`, the server contract in `docs/features.md`, and
   the snapshot at the top of this skill.

6. Remove compatibility branches only after the probe passes. Delete the old
   server lane, capability probes and fallbacks in the same change that proves
   they are obsolete. Update `docs/roadmap.md` with what shipped.

7. Update tests and docs together. A user-visible behavior change needs a test
   assertion or a documented reason it cannot have one. When the release adds a
   scanner or resource format, update the filetype list in the same change.

8. Verify.

   ```sh
   make check
   .claude/skills/verify-x18n-nvim/scripts/verify-playground.sh --project vue-vite
   ```

   If `~/i/koma` exists, run its `bun run i18n` and dogfood the editor path
   there. Do not commit koma changes unless the user asks.

9. Land only when asked. If the branch was rewritten, ask before the force-push.

## Feature audit

For each custom method or field the plugin uses, prove it against the published
server. Check at least:

- `x18n/keyInfo` at a call usage, a locale definition and a line end.
- `x18n/decorations`, including whether static params are filled.
- `x18n/fileKeys` usage counts and missing keys.
- `x18n/projects`, `x18n/tree`, `x18n/reviews`, `x18n/translatePrompt` when the
  plugin or docs touch them.
- `server_info.version` in the initialize result.

A server result that is empty for metadata is not a bug in the plugin. A server
result that invents keys for metadata is a server bug. The plugin guards the
known case, `x18n.config.*`, and keeps the guard until upstream excludes it.

## Filetype attach

`lsp.filetypes` is a client-side performance gate. The server decides project
membership and resources, but Neovim must choose which buffers to send.

- The server's extension lists live in `@x18n/builtins/formats` and
  `@x18n/builtins/scanners`. Use them as the source when adding filetypes.
- Zed's `packages/zed/extension.toml` is the code-language sanity check. It is
  not complete, because it omits PHP and Ruby.
- VSCode attaches every `file:` document. Do not copy that into Neovim without
  measuring the per-buffer request cost.
- Add a new filetype only when the server's scanner or format list supports it.
  Document that users can extend `lsp.filetypes`.
- Keep `x18n.config.*` and `.x18n/` out of decorations and keymaps. They are
  metadata, not translation sources.

When the server adds a language or format, update the list and the docs in the
same change. A new server feature is not covered just because the server scans
it. The client must attach to the file.

## Failure modes

- `x18n/keyInfo` returns `Hello {name}` while decorations show `Hello Ada`.
  That is the 0.1.13 split. The popup stays raw; do not client-fill it.
- CI has no clipboard provider. Tests assert the unnamed register `"`, not `+`.
- `x18n.config.ts` shows missing keys. The server scanned its own config. The
  plugin skips decorations for `x18n.config.*`; keep the guard until upstream
  excludes the file.
- A new server release returns an empty result for a file the plugin decorates.
  Treat it as unsupported or metadata. Do not invent a fallback.
- The plugin's health check reports an old server. Update the global install
  or the root devDependency, not the plugin's logic.

## References

- [verify-x18n-nvim](../verify-x18n-nvim/SKILL.md) drives the real editor screen.
- `README.md`, `docs/development.md`, `docs/configuration.md`.
- `lua/x18n/health.lua`, `lua/x18n/init.lua`, `lua/x18n/decorations.lua`.
- Upstream: `https://github.com/x18n-dev/x18n`.
- Upstream clients: `packages/vscode/src/client.ts`,
  `packages/zed/extension.toml`, `packages/builtins/src/index.ts`.
