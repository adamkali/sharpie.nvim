-- Language abstraction layer for sharpie.nvim
-- Provides language detection and configuration for multi-language support

local M = {}

-- Language configuration structure
-- @field name string: Language identifier ("csharp" | "go")
-- @field filetypes table: List of vim filetypes (e.g., {"cs", "csharp"})
-- @field file_patterns table: List of glob patterns (e.g., {"*.cs"})
-- @field lsp_clients table: List of LSP client name patterns (e.g., {"omnisharp", "csharp"})
-- @field treesitter_lang string: Treesitter parser name (e.g., "c_sharp")
-- @field file_extensions table: List of file extensions (e.g., {".cs", ".vb", ".fs"})
-- @field handler module: Language-specific handler module

-- C# language configuration
M.languages = {
    csharp = {
        name = "csharp",
        display_name = "C#",
        filetypes = { "cs", "csharp" },
        file_patterns = { "*.cs" },
        lsp_clients = { "omnisharp", "csharp" },
        treesitter_lang = "c_sharp",
        file_extensions = { ".cs", ".vb", ".fs" },
        -- Handler module loaded lazily
        handler = nil,
    },
    go = {
        name = "go",
        display_name = "Go",
        filetypes = { "go" },
        file_patterns = { "*.go" },
        lsp_clients = { "gopls" },
        treesitter_lang = "go",
        file_extensions = { ".go" },
        -- Handler module loaded lazily
        handler = nil,
    },
}

-- Get language handler module (lazy-loaded)
-- @param lang_config table: Language configuration
-- @return table: Language handler module
function M.get_handler(lang_config)
    if not lang_config then
        return nil
    end

    -- Lazy load handler if not already loaded
    if not lang_config.handler then
        local handler_path = string.format("sharpie.languages.%s", lang_config.name)
        local ok, handler = pcall(require, handler_path)
        if ok then
            lang_config.handler = handler
        else
            vim.notify(
                string.format("Failed to load language handler for %s: %s", lang_config.name, handler),
                vim.log.levels.WARN
            )
            return nil
        end
    end

    return lang_config.handler
end

-- Detect language from buffer filetype
-- @param bufnr number|nil: Buffer number (default: current buffer)
-- @return table|nil: Language configuration or nil if not supported
function M.detect_language(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    -- Get buffer filetype
    local ok, filetype = pcall(vim.api.nvim_buf_get_option, bufnr, 'filetype')
    if not ok or not filetype then
        return nil
    end

    -- Check each registered language
    for _, lang_config in pairs(M.languages) do
        for _, ft in ipairs(lang_config.filetypes) do
            if filetype == ft then
                return lang_config
            end
        end
    end

    return nil
end

-- Get language configuration by name
-- @param name string: Language name ("csharp" | "go")
-- @return table|nil: Language configuration or nil if not found
function M.get_language(name)
    return M.languages[name]
end

-- Check if language is supported
-- @param name string: Language name
-- @return boolean: True if language is supported
function M.is_supported(name)
    return M.languages[name] ~= nil
end

-- Get all supported languages
-- @return table: List of language configurations
function M.get_all_languages()
    local langs = {}
    for _, lang_config in pairs(M.languages) do
        table.insert(langs, lang_config)
    end
    return langs
end

-- Check if buffer is a supported language
-- @param bufnr number|nil: Buffer number (default: current buffer)
-- @return boolean: True if buffer is a supported language
function M.is_supported_buffer(bufnr)
    return M.detect_language(bufnr) ~= nil
end

-- Get file patterns for all supported languages
-- @return table: Flat list of all file patterns (e.g., {"*.cs", "*.go"})
function M.get_all_file_patterns()
    local patterns = {}
    for _, lang_config in pairs(M.languages) do
        for _, pattern in ipairs(lang_config.file_patterns) do
            table.insert(patterns, pattern)
        end
    end
    return patterns
end

return M
