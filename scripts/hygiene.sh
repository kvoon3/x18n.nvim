#!/usr/bin/env sh
# Repository hygiene: trailing whitespace, merge markers, final newlines and
# oversized tracked files. Vendored playground and fixtures are excluded.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

status=0
report() { printf '%s\n' "$1" >&2; status=1; }

matches=$(git grep -n -I -E '[[:blank:]]+$' -- . ':(exclude)playground' ':(exclude)test/fixture' || true)
[ -z "$matches" ] || { printf '%s\n' "$matches" >&2; report 'trailing whitespace found'; }

matches=$(git grep -n -I -E '^(<<<<<<< |=======$|>>>>>>> )' -- . ':(exclude)playground' ':(exclude)test/fixture' || true)
[ -z "$matches" ] || { printf '%s\n' "$matches" >&2; report 'merge conflict marker found'; }

missing=$(git ls-files -z | xargs -0 -n1 sh -c '
  file=$1
  case "$file" in playground/*|test/fixture/*) exit 0;; esac
  [ -s "$file" ] || exit 0
  grep -Iq "" "$file" 2>/dev/null || exit 0
  [ "$(tail -c 1 "$file" | od -An -t u1 | tr -d "[:space:]")" = "10" ] || printf "%s\n" "$file"
' sh)
[ -z "$missing" ] || { printf '%s\n' "$missing" >&2; report 'file missing a final newline'; }

large=$(git ls-files -z | xargs -0 -n1 sh -c '
  size=$(wc -c < "$1")
  [ "$size" -le 1048576 ] || printf "%s (%s bytes)\n" "$1" "$size"
' sh)
[ -z "$large" ] || { printf '%s\n' "$large" >&2; report 'tracked file larger than 1 MiB'; }

exit "$status"
