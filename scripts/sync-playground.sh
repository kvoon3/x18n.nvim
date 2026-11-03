#!/usr/bin/env sh
# Refresh playground/ from the upstream x18n repository. The playground is
# vendored so the repo works offline; run this to pick up upstream changes.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/x18n-playground.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

git clone --depth 1 --filter=blob:none --sparse https://github.com/x18n-dev/x18n "$tmp/x18n"
git -C "$tmp/x18n" sparse-checkout set playground
rsync -a --delete "$tmp/x18n/playground/" "$root/playground/"
printf 'playground synced from x18n-dev/x18n %s\n' "$(git -C "$tmp/x18n" rev-parse --short HEAD)"