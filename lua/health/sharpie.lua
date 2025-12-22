-- Health check module for sharpie.nvim
-- This file is automatically loaded by Neovim's :checkhealth command

local M = {}

function M.check()
    local utils = require('sharpie.utils')
    local config = require('sharpie.config')
    local queries = require('sharpie.queries')
    local language = require('sharpie.language')

    vim.health.start("sharpie.nvim")

    -- Check Neovim version
    local nvim_version = vim.version()
    local required_version = {0, 8, 0}
    local version_ok = (nvim_version.major > required_version[1]) or
                      (nvim_version.major == required_version[1] and nvim_version.minor >= required_version[2])

    if version_ok then
        vim.health.ok(string.format("Neovim version %d.%d.%d (>= 0.8.0)",
            nvim_version.major, nvim_version.minor, nvim_version.patch))
    else
        vim.health.error(string.format("Neovim version %d.%d.%d is too old. Requires >= 0.8.0",
            nvim_version.major, nvim_version.minor, nvim_version.patch))
    end

    -- Check LSP
    local active_clients = vim.lsp.get_clients()
    if #active_clients > 0 then
        vim.health.ok(string.format("LSP is active (%d client(s) running)", #active_clients))
        for _, client in ipairs(active_clients) do
            vim.health.info(string.format("  - %s (id: %d)", client.name, client.id))
        end
    else
        vim.health.warn("No LSP clients active", {
            "Start an LSP client for supported languages",
            "C#: OmniSharp or csharp-ls",
            "Go: gopls"
        })
    end

    -- Check for language-specific LSP clients
    local bufnr = vim.api.nvim_get_current_buf()
    local lang_clients_found = {}

    -- Check C# LSP
    local csharp_config = language.get_language("csharp")
    local csharp_client = utils.get_lsp_client(bufnr, csharp_config)
    if csharp_client then
        vim.health.ok(string.format("C# LSP client found: %s", csharp_client.name))
        lang_clients_found.csharp = csharp_client

        -- Check LSP capabilities
        local caps = csharp_client.server_capabilities
        if caps.documentSymbolProvider then
            vim.health.ok("  Supports document symbols")
        else
            vim.health.error("  Missing document symbol support")
        end

        if caps.referencesProvider then
            vim.health.ok("  Supports references")
        else
            vim.health.warn("  Missing references support")
        end

        if caps.definitionProvider then
            vim.health.ok("  Supports go-to-definition")
        else
            vim.health.warn("  Missing definition support")
        end
    else
        vim.health.info("No C# LSP client found", {
            "Install OmniSharp or csharp-ls if you need C# support",
            "This is optional if you only use Go"
        })
    end

    -- Check Go LSP
    local go_config = language.get_language("go")
    local go_client = utils.get_lsp_client(bufnr, go_config)
    if go_client then
        vim.health.ok(string.format("Go LSP client found: %s", go_client.name))
        lang_clients_found.go = go_client

        -- Check LSP capabilities
        local caps = go_client.server_capabilities
        if caps.documentSymbolProvider then
            vim.health.ok("  Supports document symbols")
        else
            vim.health.error("  Missing document symbol support")
        end

        if caps.referencesProvider then
            vim.health.ok("  Supports references")
        else
            vim.health.warn("  Missing references support")
        end

        if caps.definitionProvider then
            vim.health.ok("  Supports go-to-definition")
        else
            vim.health.warn("  Missing definition support")
        end
    else
        vim.health.info("No Go LSP client found", {
            "Install gopls if you need Go support",
            "This is optional if you only use C#"
        })
    end

    -- Check current buffer language
    local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
    local current_lang = queries.get_buffer_language(bufnr)
    if current_lang then
        vim.health.ok(string.format("Current buffer is %s (filetype: %s)", current_lang.display_name, ft))
    else
        vim.health.info(string.format("Current buffer is not a supported language (filetype: %s)", ft), {
            "Supported languages: C# (cs/csharp), Go (go)"
        })
    end

    -- Check treesitter
    if queries.has_treesitter() then
        vim.health.ok("Treesitter is available")

        -- Check for C# parser
        local has_csharp_parser = pcall(vim.treesitter.get_parser, bufnr, 'c_sharp')
        if has_csharp_parser then
            vim.health.ok("  C# parser installed")
        else
            vim.health.info("  C# parser not installed (optional)", {
                "Install with: :TSInstall c_sharp"
            })
        end

        -- Check for Go parser
        local has_go_parser = pcall(vim.treesitter.get_parser, bufnr, 'go')
        if has_go_parser then
            vim.health.ok("  Go parser installed")
        else
            vim.health.info("  Go parser not installed (optional)", {
                "Install with: :TSInstall go"
            })
        end
    else
        vim.health.info("Treesitter is not available (optional)", {
            "Install nvim-treesitter plugin for enhanced features"
        })
    end

    -- Check fuzzy finder configuration
    local fuzzy_config = config.get().fuzzy_finder
    vim.health.info(string.format("Configured fuzzy finder: %s", fuzzy_config))

    if fuzzy_config == "telescope" then
        local has_telescope, telescope = pcall(require, 'telescope')
        if has_telescope then
            vim.health.ok("Telescope is available")

            -- Check telescope version if possible
            if telescope.setup then
                vim.health.ok("  Telescope is properly configured")
            end
        else
            vim.health.error("Telescope is not installed but configured", {
                "Install telescope.nvim plugin",
                "Or change config: fuzzy_finder = 'fzf'"
            })
        end
    elseif fuzzy_config == "fzf" then
        local has_fzf, fzf = pcall(require, 'fzf-lua')
        if has_fzf then
            vim.health.ok("FZF-lua is available")
        else
            vim.health.error("FZF-lua is not installed but configured", {
                "Install fzf-lua plugin",
                "Or change config: fuzzy_finder = 'telescope'"
            })
        end
    else
        vim.health.error(string.format("Unknown fuzzy finder: %s", fuzzy_config), {
            "Valid options: 'telescope' or 'fzf'",
            "Update your configuration"
        })
    end

    -- Check plugin configuration
    local cfg = config.get()
    vim.health.info("Plugin configuration:")
    vim.health.info(string.format("  Display style: %s", cfg.display.style))
    vim.health.info(string.format("  Symbol path depth: %d", cfg.symbol_options.path))
    vim.health.info(string.format("  Keybinding prefix: %s", cfg.keybindings.sharpie_local_leader))

    -- Check if default keybindings are enabled
    if cfg.keybindings.disable_default_keybindings then
        vim.health.warn("Default keybindings are disabled", {
            "You need to set up custom keybindings manually"
        })
    else
        vim.health.ok("Default keybindings are enabled")
    end

    -- Check logging configuration
    local logger = require('sharpie.logger')
    local log_config = logger.get_config()
    vim.health.info("Logging configuration:")
    vim.health.info(string.format("  Enabled: %s", log_config.enabled))
    vim.health.info(string.format("  Level: %s", log_config.level))
    vim.health.info(string.format("  File: %s", log_config.file))

    if log_config.enabled then
        -- Check if log file is writable
        local log_dir = vim.fn.fnamemodify(log_config.file, ':h')
        if vim.fn.isdirectory(log_dir) == 0 then
            vim.health.warn(string.format("Log directory does not exist: %s", log_dir), {
                "Create directory with: mkdir -p " .. log_dir
            })
        else
            vim.health.ok("Log directory exists")
        end
    end

    -- Summary
    vim.health.start("Summary")
    local issues = 0
    local warnings = 0

    if not version_ok then issues = issues + 1 end
    if #active_clients == 0 then issues = issues + 1 end

    -- At least one language LSP should be available
    if not (lang_clients_found.csharp or lang_clients_found.go) then
        warnings = warnings + 1
    end

    if fuzzy_config == "telescope" and not pcall(require, 'telescope') then issues = issues + 1 end
    if fuzzy_config == "fzf" and not pcall(require, 'fzf-lua') then issues = issues + 1 end

    if issues == 0 and warnings == 0 then
        vim.health.ok("All checks passed! sharpie.nvim is ready to use")
        if lang_clients_found.csharp and lang_clients_found.go then
            vim.health.info("Both C# and Go LSP clients are available")
        elseif lang_clients_found.csharp then
            vim.health.info("C# LSP client is available (Go is optional)")
        elseif lang_clients_found.go then
            vim.health.info("Go LSP client is available (C# is optional)")
        end
    elseif issues == 0 and warnings > 0 then
        vim.health.info(string.format("%d warning(s) found. Plugin will work but some features may be limited", warnings))
    else
        vim.health.warn(string.format("%d issue(s) found. See above for details", issues))
    end
end

return M
