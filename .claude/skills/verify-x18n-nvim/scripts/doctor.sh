#!/usr/bin/env sh
# Read-only readiness check for the x18n.nvim playground verification.
# Run this first whenever a verification run looks off. It starts no servers
# and changes no files.
set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/../../../.." && pwd)
fail=0

ok() { printf 'OK   %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*"; fail=1; }

printf 'repo: %s\n' "$repo"

if command -v nvim >/dev/null 2>&1; then
  version=$(nvim --version | head -1)
  case "$version" in
    *0.11.*|*0.12.*|*0.13.*|*1.*) ok "$version" ;;
    *) bad "Neovim 0.11+ required: $version" ;;
  esac
else
  bad 'nvim is not on PATH'
fi

if command -v node >/dev/null 2>&1; then
  ok "node $(node --version)"
else
  bad 'node is not on PATH'
fi

if command -v rsync >/dev/null 2>&1; then
  ok 'rsync is available'
else
  bad 'rsync is not on PATH (the checker copies each project to a temp dir)'
fi

lsp_bin="$repo/node_modules/@x18n/lsp/bin.mjs"
if [ -x "$lsp_bin" ]; then
  resolved=$(node -e 'try { console.log(require("node:fs").realpathSync(process.argv[1])) } catch (e) { process.exit(1) }' "$lsp_bin" 2>/dev/null)
  if [ -n "${resolved:-}" ] && [ -f "$(dirname "$resolved")/dist/index.mjs" ]; then
    ok "x18n-lsp -> $resolved"
  else
    bad "x18n-lsp resolves to ${resolved:-<nothing>} but dist/index.mjs is missing; build the fork"
  fi
else
  bad "missing $lsp_bin; run npm install at the repo root"
fi

builtins=$(node -e 'const fs=require("node:fs"), path=require("node:path"); try { const p=fs.realpathSync(process.argv[1]); console.log(path.resolve(path.dirname(p), "../builtins/dist/checks.mjs")) } catch (e) { process.exit(1) }' "$lsp_bin" 2>/dev/null)
if [ -n "${builtins:-}" ] && [ -f "$builtins" ]; then
  ok "fork builtins -> $builtins"
else
  bad 'fork builtins/dist/checks.mjs is missing; run pnpm --filter @x18n/lsp build in the fork'
fi

if [ -x "$repo/node_modules/.bin/x18n" ]; then
  ok 'x18n CLI is installed'
else
  bad "missing $repo/node_modules/.bin/x18n; run npm install at the repo root"
fi

for project in vue-vite react-i18next next-intl laravel rails angular monorepo i18n-ally; do
  if [ -d "$repo/playground/$project" ]; then
    ok "playground/$project"
  else
    bad "playground/$project is missing; run scripts/sync-playground.sh"
  fi
done

if nvim --clean --headless --cmd 'set lines=50 columns=200' -c 'qa!' >/dev/null 2>&1; then
  ok 'headless nvim starts cleanly'
else
  bad 'nvim --clean --headless failed'
fi

if [ "$fail" -eq 0 ]; then
  printf '\nready\n'
else
  printf '\nnot ready; fix the FAIL lines above\n'
fi
exit "$fail"
