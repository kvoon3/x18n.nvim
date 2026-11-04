LUA_DIRS := lua plugin test .claude/skills/verify-x18n-nvim/scripts
NVIM ?= nvim

.PHONY: all check format format-check hooks lint ls-lint test

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

test:
	@set -e; for t in test/*.lua; do \
		if [ "$$t" != test/harness.lua ]; then $(NVIM) -l test/harness.lua "$$t"; fi; \
	done

test-upstream:
	@test -d test/upstream/node_modules/@x18n/lsp || npm install --prefix test/upstream
	@set -e; for t in test/*.lua; do \
		if [ "$$t" != test/harness.lua ]; then \
			X18N_UPSTREAM=1 X18N_LSP_BIN=$(CURDIR)/test/upstream/node_modules/@x18n/lsp/bin.mjs \
				$(NVIM) -l test/harness.lua "$$t"; \
		fi; \
	done
