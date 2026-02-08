# Colors
_C_OK := \033[38;2;0;200;0m
_C_ERR := \033[31m
_C_WARN := \033[33m
_C_CMD := \033[38;2;102;178;255m
_C_DIM := \033[2m
_C_BOLD := \033[1m
_C_RST := \033[0m

.PHONY: help lint
.PHONY: setup install-pre-commit install-shellcheck
.PHONY: require require-pre-commit require-shellcheck
.PHONY: doctor doctor-pre-commit doctor-shellcheck

help:
	@echo "tint - terminal background color picker"
	@echo ""
	@echo "Usage:"
	@echo "  make lint       Run shellcheck on all scripts"
	@echo "  make setup      Install dev tools (pre-commit, shellcheck)"
	@echo "  make require    Verify dev tools are installed"
	@echo "  make doctor     Diagnose dev environment"

lint:
	@shellcheck scripts/validate-commit-message.sh

# ---------------------------------------------------------------------------
# Dev environment: setup / require / doctor
# ---------------------------------------------------------------------------

setup: install-pre-commit install-shellcheck
	@echo ""
	@printf '%b%s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'Setup complete. Run: make require'

require: require-pre-commit require-shellcheck

doctor: doctor-pre-commit doctor-shellcheck

# ---------------------------------------------------------------------------
# pre-commit
# ---------------------------------------------------------------------------

install-pre-commit:
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

require-pre-commit:
	@command -v pre-commit >/dev/null 2>&1 || \
		(printf '%b%s%b\n' '$(_C_ERR)' '✗ pre-commit not found. Run: make install-pre-commit' '$(_C_RST)' && exit 1)
	@printf '%b%s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' "$$(pre-commit --version)"

doctor-pre-commit:
	@printf '%b%s%b\n' '$(_C_BOLD)' 'pre-commit' '$(_C_RST)'
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		printf '%b  %s%b\n' '$(_C_ERR)' '✗ not found' '$(_C_RST)'; \
		printf '%b  %s%b\n' '$(_C_DIM)' 'Fix: make install-pre-commit' '$(_C_RST)'; \
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

# ---------------------------------------------------------------------------
# shellcheck
# ---------------------------------------------------------------------------

install-shellcheck:
	@if command -v shellcheck >/dev/null 2>&1; then \
		printf '%b%s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'shellcheck already installed'; \
	elif command -v brew >/dev/null 2>&1; then \
		echo "Installing shellcheck via brew..."; \
		brew install shellcheck || exit 1; \
		printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'shellcheck installed'; \
	elif command -v apt-get >/dev/null 2>&1; then \
		echo "Installing shellcheck via apt..."; \
		sudo apt-get update && sudo apt-get install -y shellcheck || exit 1; \
		printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' 'shellcheck installed'; \
	else \
		printf '%b%s%b\n' '$(_C_WARN)' 'Warning: Could not install shellcheck automatically' '$(_C_RST)'; \
		echo "Install manually: https://github.com/koalaman/shellcheck#installing"; \
	fi

require-shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || \
		(printf '%b%s%b\n' '$(_C_ERR)' '✗ shellcheck not found. Run: make install-shellcheck' '$(_C_RST)' && exit 1)
	@printf '%b%s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' "shellcheck $$(shellcheck --version 2>/dev/null | grep '^version:' | cut -d' ' -f2)"

doctor-shellcheck:
	@echo ""
	@printf '%b%s%b\n' '$(_C_BOLD)' 'shellcheck' '$(_C_RST)'
	@if command -v shellcheck >/dev/null 2>&1; then \
		printf '%b  %s%b %s\n' '$(_C_OK)' '✓' '$(_C_RST)' "shellcheck $$(shellcheck --version 2>/dev/null | grep '^version:' | cut -d' ' -f2)"; \
	else \
		printf '%b  %s%b\n' '$(_C_ERR)' '✗ not found' '$(_C_RST)'; \
		printf '%b  %s%b\n' '$(_C_DIM)' 'Fix: make install-shellcheck' '$(_C_RST)'; \
	fi
