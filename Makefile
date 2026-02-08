# Colors
_C_OK := \033[38;2;0;200;0m
_C_ERR := \033[31m
_C_WARN := \033[33m
_C_CMD := \033[38;2;102;178;255m
_C_DIM := \033[2m
_C_BOLD := \033[1m
_C_RST := \033[0m

.PHONY: help setup require doctor

help:
	@echo "tint - terminal background color picker"
	@echo ""
	@echo "Usage:"
	@echo "  make setup      Install dev tools (pre-commit, hooks)"
	@echo "  make require    Verify dev tools are installed"
	@echo "  make doctor     Diagnose dev environment"

# ---------------------------------------------------------------------------
# Dev environment: setup / require / doctor
# ---------------------------------------------------------------------------

setup:
	@# --- pre-commit ---
	@if command -v pre-commit >/dev/null 2>&1; then \
		printf '%b%s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'pre-commit already installed'; \
	elif command -v brew >/dev/null 2>&1; then \
		echo "Installing pre-commit via brew..."; \
		printf '%b  %s%b\n' '$(_C_CMD)' '$$ brew install pre-commit' '$(_C_RST)'; \
		brew install pre-commit || exit 1; \
		printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'pre-commit installed'; \
	elif command -v pipx >/dev/null 2>&1; then \
		echo "Installing pre-commit via pipx..."; \
		printf '%b  %s%b\n' '$(_C_CMD)' '$$ pipx install pre-commit' '$(_C_RST)'; \
		pipx install pre-commit || exit 1; \
		printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'pre-commit installed'; \
	elif command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then \
		pip_cmd="pip3"; command -v pip3 >/dev/null 2>&1 || pip_cmd="pip"; \
		echo "Installing pre-commit via $$pip_cmd..."; \
		printf '%b  %s%b\n' '$(_C_CMD)' "\$$ $$pip_cmd install --user pre-commit" '$(_C_RST)'; \
		$$pip_cmd install --user pre-commit || exit 1; \
		printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'pre-commit installed'; \
	else \
		printf '%b%s%b\n' '$(_C_ERR)' 'Error: Could not install pre-commit (need brew, pipx, or pip)' '$(_C_RST)'; \
		echo "Install manually: https://pre-commit.com/#install"; \
		exit 1; \
	fi
	@# --- git hooks ---
	@if [ -f .pre-commit-config.yaml ]; then \
		pre_commit_cmd=""; \
		if command -v pre-commit >/dev/null 2>&1; then \
			pre_commit_cmd="pre-commit"; \
		elif [ -x "$$HOME/.local/bin/pre-commit" ]; then \
			pre_commit_cmd="$$HOME/.local/bin/pre-commit"; \
		fi; \
		if [ -n "$$pre_commit_cmd" ]; then \
			printf '%b  %s%b\n' '$(_C_CMD)' '$$ pre-commit install' '$(_C_RST)'; \
			$$pre_commit_cmd install || exit 1; \
			printf '%b  %s%b\n' '$(_C_CMD)' '$$ pre-commit install --hook-type commit-msg' '$(_C_RST)'; \
			$$pre_commit_cmd install --hook-type commit-msg || exit 1; \
			printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'git hooks installed'; \
		fi; \
	fi
	@echo ""
	@printf '%b%s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'Setup complete. Run: make require'

require:
	@if command -v pre-commit >/dev/null 2>&1; then \
		printf '%b%s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' "$$(pre-commit --version)"; \
	else \
		printf '%b%s%b\n' '$(_C_ERR)' '✗ pre-commit not found. Run: make setup' '$(_C_RST)'; \
		exit 1; \
	fi

doctor:
	@printf '%b%s%b\n' '$(_C_BOLD)' 'pre-commit' '$(_C_RST)'
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		printf '%b  %s%b\n' '$(_C_ERR)' '✗ not found' '$(_C_RST)'; \
		printf '%b  %s%b\n' '$(_C_DIM)' 'Fix: make setup' '$(_C_RST)'; \
	else \
		printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' "$$(pre-commit --version)"; \
		if [ -f .pre-commit-config.yaml ]; then \
			printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' '.pre-commit-config.yaml exists'; \
		else \
			printf '%b  %s%b\n' '$(_C_WARN)' '⚠ .pre-commit-config.yaml not found' '$(_C_RST)'; \
		fi; \
		if [ -f .git/hooks/pre-commit ] && grep -q "pre-commit" .git/hooks/pre-commit 2>/dev/null; then \
			printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'pre-commit hook installed'; \
		else \
			printf '%b  %s%b\n' '$(_C_WARN)' '⚠ pre-commit hook not installed' '$(_C_RST)'; \
			printf '%b  %s%b\n' '$(_C_DIM)' 'Fix: pre-commit install' '$(_C_RST)'; \
		fi; \
		if [ -f .git/hooks/commit-msg ] && grep -q "pre-commit" .git/hooks/commit-msg 2>/dev/null; then \
			printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'commit-msg hook installed'; \
		else \
			printf '%b  %s%b\n' '$(_C_WARN)' '⚠ commit-msg hook not installed' '$(_C_RST)'; \
			printf '%b  %s%b\n' '$(_C_DIM)' 'Fix: pre-commit install --hook-type commit-msg' '$(_C_RST)'; \
		fi; \
	fi
