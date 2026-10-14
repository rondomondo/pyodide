.DEFAULT_GOAL := help
SHELL         := /bin/bash
MAKEFLAGS     += --no-print-directory

BOLD   := \033[1m
RED    := \033[31m
GREEN  := \033[32m
CYAN   := \033[36m
YELLOW := \033[33m
RESET  := \033[0m

DIST_DIR   := dist
ASSET_DIRS := css js py

PORT            ?= 8008
SERVER_URL      := http://127.0.0.1:$(PORT)
SERVER_PID_FILE := .server.pid
DEFAULT_PAGE    := sanitise-ascii.html

# Each app: "html_file:s3_subpath:index_alias"
# html_file      - source HTML (uploaded under its own name)
# s3_subpath     - folder under S3_BUCKET
# index_alias    - y to also upload as index.html, n to skip
APPS := \
  sanitise-ascii.html:sanitise:y \
  pdf-strip.html:pdfstrip:y

S3_BUCKET     := s3://alertstack-ai
S3_OPT_PREFIX := alertstack.ai/apps/
CACHE_CONTROL := max-age=300

##@ Help

.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0,5) } \
	  /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)

##@ Setup

.PHONY: install
install: ## Sync dependencies with uv and enable the commit-msg hook
	@command -v uv >/dev/null 2>&1 || { printf "$(RED)uv not found$(RESET) -- install from https://docs.astral.sh/uv/\n" >&2; exit 1; }
	uv sync
	git config core.hooksPath .githooks
	chmod +x .githooks/commit-msg
	@printf "$(GREEN)ready$(RESET) -- hooks enabled, run 'make check' to verify\n"

##@ Quality

.PHONY: test
test: ## Run the test suite
	uv run pytest

.PHONY: lint
lint: ## Lint, check formatting and type-check
	uv run ruff check .
	uv run ruff format --check .
	uv run mypy py tests

.PHONY: check
check: lint test ## Lint and test

##@ Build

.PHONY: release
release: check ## Copy app HTML and shared assets to $(DIST_DIR)
	@rm -rf $(DIST_DIR) && mkdir -p $(DIST_DIR)
	@for entry in $(APPS); do cp "$${entry%%:*}" $(DIST_DIR)/ || exit 1; done
	@cp -R $(ASSET_DIRS) $(DIST_DIR)/
	@find $(DIST_DIR) -name __pycache__ -prune -exec rm -rf {} +
	@printf "$(GREEN)released$(RESET) to $(DIST_DIR)/\n"

##@ Deploy

.PHONY: deploy
deploy: release ## Deploy all apps to S3 (set S3_OPT_PREFIX=staging/ for non-prod)
	@for entry in $(APPS); do \
		IFS=: read -r f sub alias <<< "$$entry"; \
		dest=$(S3_BUCKET)/$(S3_OPT_PREFIX)$$sub; \
		printf "$(CYAN)upload$(RESET)  $$f -> $$dest/\n"; \
		aws s3 cp --cache-control "$(CACHE_CONTROL)" $(DIST_DIR)/$$f $$dest/$$f || exit 1; \
		if [ "$$alias" = "y" ]; then \
			aws s3 cp --cache-control "$(CACHE_CONTROL)" $(DIST_DIR)/$$f $$dest/index.html || exit 1; \
		fi; \
		for d in $(ASSET_DIRS); do \
			aws s3 sync --delete --cache-control "$(CACHE_CONTROL)" $(DIST_DIR)/$$d $$dest/$$d || exit 1; \
		done; \
	done

##@ Local Server

.PHONY: start
start: ## Start HTTP server in background (PORT=8008)
	@if [ -f "$(SERVER_PID_FILE)" ] && kill -0 $$(cat $(SERVER_PID_FILE)) 2>/dev/null; then \
		printf "$(YELLOW)[start]$(RESET) Server already running (pid $$(cat $(SERVER_PID_FILE)))\n"; \
	else \
		python3 -m http.server $(PORT) --bind 127.0.0.1 >/dev/null 2>&1 & \
		echo $$! > $(SERVER_PID_FILE); \
		printf "$(GREEN)[start]$(RESET) Server started on $(SERVER_URL) (pid $$(cat $(SERVER_PID_FILE)))\n"; \
	fi

.PHONY: stop
stop: ## Stop the background HTTP server
	@if [ -f "$(SERVER_PID_FILE)" ] && kill -0 $$(cat $(SERVER_PID_FILE)) 2>/dev/null; then \
		kill $$(cat $(SERVER_PID_FILE)); \
		rm -f $(SERVER_PID_FILE); \
		printf "$(GREEN)[stop]$(RESET) Server stopped\n"; \
	else \
		rm -f $(SERVER_PID_FILE); \
		printf "$(YELLOW)[stop]$(RESET) No server running\n"; \
	fi

.PHONY: serve
serve: start ## Start server and open in browser
	@URL="$(SERVER_URL)/$(DEFAULT_PAGE)?v=$$(date +%s)"; \
	printf "$(CYAN)[serve]$(RESET) Opening $$URL...\n"; \
	if command -v open >/dev/null 2>&1; then open "$$URL"; \
	elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$$URL"; \
	else printf "$(YELLOW)Open manually:$(RESET) $$URL\n"; fi
