#!/usr/bin/env sh
# Type-check lua/ and plugin/ with LuaLS. The generated config points
# workspace.library at this Neovim's runtime so vim.* and uv.* resolve.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
nvim=${NVIM:-nvim}
lua_ls=${LUA_LS:-lua-language-server}

command -v "$nvim" >/dev/null 2>&1 || { printf 'nvim is not on PATH\n' >&2; exit 1; }
command -v "$lua_ls" >/dev/null 2>&1 || { printf 'lua-language-server is not on PATH; run mise install or set LUA_LS\n' >&2; exit 1; }

runtime=$("$nvim" --headless -u NONE -c 'lua io.write(vim.env.VIMRUNTIME)' -c q 2>/dev/null)
[ -n "$runtime" ] || { printf 'could not resolve VIMRUNTIME\n' >&2; exit 1; }
runtime_json=$(printf '%s' "$runtime" | sed 's/\\/\\\\/g; s/"/\\"/g')
source_json=$(printf '%s' "$root/lua" | sed 's/\\/\\\\/g; s/"/\\"/g')

config_dir=$(mktemp -d "${TMPDIR:-/tmp}/x18n-luarc.XXXXXX")
trap 'rm -rf "$config_dir"' EXIT INT TERM

base="$config_dir/base.json"
printf '{"runtime.version":"LuaJIT","workspace.library":["%s","${3rd}/luv/library"],"workspace.checkThirdParty":false,"diagnostics.globals":["vim"]}' "$runtime_json" > "$base"

plugin="$config_dir/plugin.json"
printf '{"runtime.version":"LuaJIT","workspace.library":["%s","${3rd}/luv/library","%s"],"workspace.checkThirdParty":false,"diagnostics.globals":["vim"]}' "$runtime_json" "$source_json" > "$plugin"

status=0
"$lua_ls" --check="$root/lua" --configpath="$base" --checklevel=Warning --check_format=pretty || status=$?
"$lua_ls" --check="$root/plugin" --configpath="$plugin" --checklevel=Warning --check_format=pretty || status=$?
exit "$status"
