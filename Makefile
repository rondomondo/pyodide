.DEFAULT_GOAL := help
SHELL         := /bin/bash
MAKEFLAGS     += --no-print-directory

BOLD   := \033[1m
RED    := \033[31m
GREEN  := \033[32m
CYAN   := \033[36m
YELLOW := \033[33m
RESET  := \033[0m

DIST_DIR := dist

PORT            ?= 8008
HTML_ROOT       := .
SERVER_URL      := http://localhost:$(PORT)
SERVER_PID_FILE := .server.pid

# Each app: "html_file|s3_subpath|index_alias"
# html_file      - source HTML (also copied as-named)
# s3_subpath     - folder under S3_BUCKET
# index_alias    - y to also upload as index.html, n to skip
APPS := \
  sanitise-ascii.html:sanitise:y \
  pdf-strip.html:pdfstrip:y

S3_BUCKET     := s3://find4-webapp
S3_OPT_PREFIX := anna/

$(shell mkdir -p $(DIST_DIR))

##@ Help

.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0,5) } \
	  /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)

##@ Python / uv

.PHONY: venv
venv: ## Create .venv and install dependencies via uv
	uv sync
	@printf "$(GREEN)venv ready$(RESET) -- activate with: source .venv/bin/activate\n"

.PHONY: check-uv
check-uv: ## Verify uv is available
	@command -v uv >/dev/null 2>&1 || { printf "$(RED)uv not found$(RESET) -- install from https://docs.astral.sh/uv/\n" >&2; exit 1; }
	@printf "$(GREEN)uv found$(RESET): $$(uv --version)\n"

##@ Build

.PHONY: release
release: ## Copy app HTML files to $(DIST_DIR)
	@printf "$(CYAN)Release to$(RESET) $(DIST_DIR)\n"
	@ok=0; fail=0; \
	for entry in $(APPS); do \
		f=$$(echo "$$entry" | cut -d: -f1); \
		if /bin/cp $$f $(DIST_DIR)/ 2>/dev/null; then \
			printf "  $(GREEN)ok$(RESET)  $$f\n"; ok=$$((ok+1)); \
		else \
			printf "  $(RED)FAIL$(RESET)  $$f\n"; fail=$$((fail+1)); \
		fi \
	done; \
	printf "\n  $(BOLD)$$ok synced, $$fail failed$(RESET) -> $(DIST_DIR)\n"; \
	[ $$fail -eq 0 ]

##@ Deploy

.PHONY: deploy
deploy: ## Deploy all apps to S3 (set S3_OPT_PREFIX=staging/ for non-prod)
	@for entry in $(APPS); do \
		f=$$(echo "$$entry" | cut -d: -f1); \
		sub=$$(echo "$$entry" | cut -d: -f2); \
		alias=$$(echo "$$entry" | cut -d: -f3); \
		dest=$(S3_BUCKET)/$(S3_OPT_PREFIX)$$sub/$$f; \
		printf "$(CYAN)upload$(RESET)  $$f -> $$dest\n"; \
		aws s3 cp $$f $$dest; \
		if [ "$$alias" = "y" ]; then \
			idest=$(S3_BUCKET)/$(S3_OPT_PREFIX)$$sub/index.html; \
			printf "$(CYAN)alias $(RESET)  $$f -> $$idest\n"; \
			aws s3 cp $$f $$idest; \
		fi \
	done

##@ Local Server

.PHONY: start
start: ## Start HTTP server in background (PORT=8008)
	@if [ -f "$(SERVER_PID_FILE)" ] && kill -0 $$(cat $(SERVER_PID_FILE)) 2>/dev/null; then \
		printf "$(YELLOW)[start]$(RESET) Server already running (pid $$(cat $(SERVER_PID_FILE)))\n"; \
	else \
		python3 -c "import http.server, os; os.chdir('$(HTML_ROOT)'); \
			httpd = http.server.HTTPServer(('0.0.0.0', $(PORT)), http.server.SimpleHTTPRequestHandler); \
			print('Serving HTTP on $(SERVER_URL)'); httpd.serve_forever()" \
			>/dev/null 2>&1 & \
		echo $$! > $(SERVER_PID_FILE); \
		ln -sf sanitise-ascii.html index.html; \
		printf "$(GREEN)[start]$(RESET) Server started on $(SERVER_URL) (pid $$(cat $(SERVER_PID_FILE)))\n"; \
	fi

.PHONY: stop
stop: ## Stop the background HTTP server
	@if [ -f "$(SERVER_PID_FILE)" ] && kill -0 $$(cat $(SERVER_PID_FILE)) 2>/dev/null; then \
		kill $$(cat $(SERVER_PID_FILE)) && rm -f $(SERVER_PID_FILE); \
		kill $$(lsof -ti :$(PORT)) 2>/dev/null || true; \
		rm -f index.html; \
		printf "$(GREEN)[stop]$(RESET) Server stopped\n"; \
	else \
		rm -f $(SERVER_PID_FILE); \
		printf "$(YELLOW)[stop]$(RESET) No server running\n"; \
	fi

.PHONY: serve
serve: start ## Start server and open in browser
	@CB=$$(date +%s); \
	URL="$(SERVER_URL)/index.html?v=$$CB"; \
	printf "$(CYAN)[serve]$(RESET) Opening $$URL...\n"; \
	if command -v open &>/dev/null; then open "$$URL"; \
	elif command -v xdg-open &>/dev/null; then xdg-open "$$URL"; \
	else printf "$(YELLOW)Open manually:$(RESET) $$URL\n"; fi
