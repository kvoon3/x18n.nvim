#!/usr/bin/env sh
# Drive the headless inline-translation verifier across the vendored upstream
# playground. Evidence lands in the output directory; only the per-run project
# copies are removed.
set -u

skill=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo=$(CDPATH= cd -- "$skill/../../.." && pwd)
# Keep in sync with scripts/playgrounds.lua.
projects="vue-vite react-i18next next-intl laravel rails angular monorepo i18n-ally"

project=all
locale=
out=
skip_doctor=0
keep_temp=0

usage() {
  cat <<'EOF'
Usage: verify-playground.sh [options]

  --project <name>   One playground (default: all)
  --locale <code>    Only this display locale (must belong to the project)
  --out <dir>        Evidence directory (default: ~/.cache/x18n-nvim-verify/<time>)
  --all              Run every playground (default)
  --skip-doctor      Do not run scripts/doctor.sh first
  --keep-temp        Keep the temporary project copies and print the path
  -h, --help         Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project) project=$2; shift 2 ;;
    --locale) locale=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --all) project=all; shift ;;
    --skip-doctor) skip_doctor=1; shift ;;
    --keep-temp) keep_temp=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$project" != all ]; then
  case " $projects " in
    *" $project "*) ;;
    *) printf 'unknown playground: %s\n' "$project" >&2; exit 2 ;;
  esac
fi

if [ "$skip_doctor" -eq 0 ]; then
  "$skill/scripts/doctor.sh" || {
    printf '\ndoctor failed; fix the FAIL lines above (or pass --skip-doctor)\n' >&2
    exit 1
  }
fi

if [ -z "$out" ]; then
  out="${XDG_CACHE_HOME:-$HOME/.cache}/x18n-nvim-verify/$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi
mkdir -p "$out/screens"
out=$(CDPATH= cd -- "$out" && pwd)

tmp=$(mktemp -d "${TMPDIR:-/tmp}/x18n-verify.XXXXXX")
cleanup() {
  if [ "$keep_temp" -eq 1 ]; then
    printf 'temp kept: %s\n' "$tmp"
  else
    rm -rf "$tmp"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

{
  printf 'repo: %s\n' "$repo"
  printf 'date: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'nvim: %s\n' "$(nvim --version | sed -n '1p')"
  printf 'node: %s\n' "$(node --version)"
  printf 'git: %s\n' "$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf 'project: %s\n' "$project"
  printf 'locale: %s\n' "${locale:-<project default>}"
} > "$out/run.txt"

report="$out/report.md"
: > "$report"
fails=0
total=0

run_one() {
  name=$1
  total=$((total + 1))
  log="$out/$name.log"
  if command -v perl >/dev/null 2>&1; then
    X18N_VERIFY_REPO="$repo" \
      X18N_VERIFY_PROJECT="$name" \
      X18N_VERIFY_LOCALE="$locale" \
      X18N_VERIFY_OUT="$out" \
      X18N_VERIFY_TMP="$tmp" \
      perl -e 'alarm shift; exec @ARGV' 180 \
      nvim --clean --headless \
        --cmd 'set lines=300 columns=600' \
        --cmd 'set noswapfile' \
        -c "luafile $skill/scripts/playground-check.lua" >"$log" 2>&1
  else
    X18N_VERIFY_REPO="$repo" \
      X18N_VERIFY_PROJECT="$name" \
      X18N_VERIFY_LOCALE="$locale" \
      X18N_VERIFY_OUT="$out" \
      X18N_VERIFY_TMP="$tmp" \
      nvim --clean --headless \
        --cmd 'set lines=300 columns=600' \
        --cmd 'set noswapfile' \
        -c "luafile $skill/scripts/playground-check.lua" >"$log" 2>&1
  fi
  status=$?
  if [ -f "$out/$name.md" ]; then
    cat "$out/$name.md" >> "$report"
    printf '\n' >> "$report"
  else
    {
      printf '# %s — FAIL\n\n' "$name"
      printf 'Verifier produced no report (exit %d); see `%s.log`.\n\n' "$status" "$name"
    } >> "$report"
  fi
  if [ "$status" -eq 0 ]; then
    printf 'PASS %s\n' "$name"
  else
    printf 'FAIL %s (exit %d)\n' "$name" "$status"
    fails=$((fails + 1))
  fi
}

if [ "$project" = all ]; then
  for name in $projects; do
    run_one "$name"
  done
else
  run_one "$project"
fi

{
  printf '# x18n.nvim playground verification\n\n'
  printf -- '- date: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- repo: %s\n' "$repo"
  printf -- '- git: %s\n' "$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf -- '- projects: %d, failures: %d\n' "$total" "$fails"
  printf -- '- evidence: `%s/screens/`\n\n' "$out"
  cat "$report"
} > "$out/summary.md"

printf '\nreport: %s\n' "$out/summary.md"
if [ "$fails" -ne 0 ]; then
  printf '%d project(s) failed\n' "$fails"
  exit 1
fi
printf 'all %d project(s) passed\n' "$total"
