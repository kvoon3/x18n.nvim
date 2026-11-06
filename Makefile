LUA_DIRS := lua plugin test scripts .claude/skills/verify-x18n-nvim/scripts
NVIM ?= nvim

.PHONY: all check comment-lint format format-check hooks hygiene lint ls-lint test typecheck workflow-lint

all: check

check: format-check lint test

hooks:
	lefthook install --reset-hooks-path

format:
	stylua $(LUA_DIRS)

format-check:
	stylua --check $(LUA_DIRS)

comment-lint:
	@$(NVIM) -l scripts/lint_comments.lua $(LUA_DIRS)

typecheck:
	@scripts/typecheck.sh

hygiene:
	@scripts/hygiene.sh

workflow-lint:
	@command -v actionlint >/dev/null 2>&1 || { echo 'actionlint is not on PATH; run mise install' >&2; exit 1; }
	@actionlint

lint: ls-lint comment-lint typecheck workflow-lint hygiene
	lefthook validate
	selene $(LUA_DIRS)

ls-lint:
	ls-lint

# The root devDependency (@x18n/lsp 0.1.13) is the server for every test.
test:
	@set -e; for t in test/*.lua; do \
		if [ "$$t" != test/harness.lua ]; then $(NVIM) -l test/harness.lua "$$t"; fi; \
	done
