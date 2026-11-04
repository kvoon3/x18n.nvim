LUA_DIRS := lua plugin test .claude/skills/verify-x18n-nvim/scripts
NVIM ?= nvim

.PHONY: all check format format-check hooks lint ls-lint test test-fork

all: check

check: format-check lint test

hooks:
	lefthook install --reset-hooks-path

format:
	stylua $(LUA_DIRS)

format-check:
	stylua --check $(LUA_DIRS)

lint: ls-lint
	lefthook validate
	selene $(LUA_DIRS)

ls-lint:
	ls-lint

# The root devDependency (@x18n/lsp 0.1.10) is the default server. The harness
# skips tests for features that server does not implement.
test:
	@set -e; for t in test/*.lua; do \
		if [ "$$t" != test/harness.lua ]; then $(NVIM) -l test/harness.lua "$$t"; fi; \
	done

# Run the same suite against a local kvoon3/x18n build, which adds
# x18n/keyInfo, usage counts and param-filled values.
test-fork:
	@test -n "$$X18N_LSP_BIN" || { echo 'set X18N_LSP_BIN to the fork server binary, e.g. ~/f/x18n/packages/lsp/bin.mjs' >&2; exit 1; }
	@set -e; for t in test/*.lua; do \
		if [ "$$t" != test/harness.lua ]; then X18N_LSP_BIN=$$X18N_LSP_BIN $(NVIM) -l test/harness.lua "$$t"; fi; \
	done
