LUA_DIRS := lua plugin test .claude/skills/verify-x18n-nvim/scripts
NVIM ?= nvim

.PHONY: all check format format-check lint ls-lint test

all: check

check: format-check lint test

format:
	stylua $(LUA_DIRS)

format-check:
	stylua --check $(LUA_DIRS)

lint: ls-lint
	selene $(LUA_DIRS)

ls-lint:
	ls-lint

test:
	@set -e; for t in test/*.lua; do \
		if [ "$$t" != test/harness.lua ]; then $(NVIM) -l test/harness.lua "$$t"; fi; \
	done
