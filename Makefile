.PHONY: test test-watch lint format help

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

test: ## Run tests with busted
	busted tests/

test-watch: ## Run tests in watch mode
	find lua/ tests/ -name '*.lua' | entr -c busted tests/

lint: ## Run luacheck
	luacheck lua/

format: ## Format code with stylua
	stylua lua/ tests/

clean: ## Clean up generated files
	rm -rf luacov.*.out
