# Development

## Toolchain

The Lua toolchain is pinned in `.mise.toml`:

```sh
mise install
npm install
```

`package.json` exists only for development: it pins the x18n CLI and language
server (`@x18n/cli`, `@x18n/lsp`) that the test harness and the playground check
run. The plugin itself is pure Lua and has no Node runtime dependency.

- [stylua](https://github.com/JohnnyMorganz/StyLua) formats Lua.
- [selene](https://github.com/Kampfkarren/selene) lints Lua. `vim.yml` vendors
  the Neovim standard library selene does not ship, and `selene.toml` points at
  it with `std = "vim"`.
- [ls-lint](https://ls-lint.org) enforces file naming (`.ls-lint.yml`):
  snake_case Lua, kebab-case Markdown, scripts and config, with `playground/`,
  `test/fixture/`, `node_modules/` and tool dotfiles ignored.
- [lefthook](https://lefthook.dev) runs the pre-commit job from `lefthook.yml`.

Without mise, install the tools yourself; the Makefile calls them by name.

## Tasks

```sh
make hooks         # enable the pre-commit hook for this clone
make format        # stylua, in place
make format-check  # stylua --check
make lint          # ls-lint + lefthook validate + selene
make test          # headless test suite, published server
make test-fork     # same suite, fork server from X18N_LSP_BIN
make check         # format-check + lint + test
```

The pre-commit hook is defined in `lefthook.yml`: stylua formats staged Lua
files and re-stages them (`stage_fixed`), then selene lints them, then ls-lint
checks the staged names. Jobs run in order, so selene sees the formatted
result. A file with unstaged hunks is staged in full after formatting. The hook
needs `stylua`, `selene` and `ls-lint` on `PATH`.

Style lives in `.stylua.toml`: LuaJIT syntax, two-space indent, 120 columns,
single quotes, no call parentheses.

## Playground

The repository vendors the upstream [x18n playground](https://github.com/x18n-dev/x18n/tree/main/playground)
under `playground/` at upstream commit `abe9140`: eight stacks (Vue, React,
Next, Laravel, Rails, Angular, a monorepo and an i18n-ally migration), each
with deliberate missing keys, unused keys, placeholder mismatches and
hard-coded strings. Refresh the copy with `scripts/sync-playground.sh`.

The CLI and server are dev dependencies at the repo root:

```sh
npm install
node_modules/.bin/x18n check --root playground/vue-vite
```

## Tests

The headless test suite runs against the real server. Each test copies
`test/fixture` to a temp directory and runs there, so `playground/` keeps
whatever state the examples have.

`make test` uses the published `@x18n/lsp` from the root devDependencies. The
harness probes `x18n/keyInfo`; tests for fork-only features print
`skipped, needs the x18n fork`. Everything else must pass.

The fork is a second lane. Build it (`pnpm --filter @x18n/lsp build`) and point
`X18N_LSP_BIN` at its server entry, so keyInfo, usage badges and param-filled
values are exercised too:

```sh
X18N_LSP_BIN=~/f/x18n/packages/lsp/bin.mjs make test-fork
```

`make test` honors `X18N_LSP_BIN` as well; point it at any other server binary
to change the lane. The same loop directly:

```sh
for t in test/*.lua; do [ "$t" = test/harness.lua ] || nvim -l test/harness.lua "$t"; done
```

The playground's rendering has its own project-local verification skill:
[`.claude/skills/verify-x18n-nvim/SKILL.md`](../.claude/skills/verify-x18n-nvim/SKILL.md).
It boots headless nvim against each vendored example, switches every locale,
reads the actual screen cells, and compares them with the server's
decorations and the CLI's read of the locale files. The feature map under
`features/` is the maintained source for those journeys.

## Debugging

Set `vim.g.x18n_debug = true` to log protocol requests and responses. Run
`:X18nExplain` when the server finds nothing, and see `:checkhealth x18n` for a
status overview.
