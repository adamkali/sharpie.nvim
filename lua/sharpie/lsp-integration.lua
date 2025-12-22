-- LSP integration for sharpie.nvim
local utils = require('sharpie.utils')
local logger = require('sharpie.logger')
local M = {}

-- Get document symbols from LSP
function M.get_document_symbols(bufnr, callback)
    logger.trace("lsp", "get_document_symbols called", { bufnr = bufnr })

    if not utils.has_lsp_client(bufnr) then
        logger.warn("lsp", "No LSP client attached to buffer", { bufnr = bufnr })
        utils.notify("No LSP client attached to buffer", vim.log.levels.WARN)
        callback(nil)
        return
    end

    local params = {
        textDocument = vim.lsp.util.make_text_document_params(bufnr)
    }

    logger.debug("lsp", "Requesting document symbols", { bufnr = bufnr })
    local start_time = vim.loop.hrtime()

    vim.lsp.buf_request(bufnr, 'textDocument/documentSymbol', params, function(err, result, ctx)
        local duration_ms = (vim.loop.hrtime() - start_time) / 1000000

        if err then
            logger.error("lsp", "Error getting document symbols", { error = vim.inspect(err), bufnr = bufnr })
            utils.notify("Error getting document symbols: " .. vim.inspect(err), vim.log.levels.ERROR)
            callback(nil)
            return
        end

        if not result or vim.tbl_isempty(result) then
            logger.info("lsp", "No symbols found in document", { bufnr = bufnr, duration_ms = duration_ms })
            callback({})
            return
        end

        -- Flatten and process symbols
        local symbols = M.flatten_symbols(result)
        logger.info("lsp", "Document symbols retrieved", {
            bufnr = bufnr,
            symbol_count = #symbols,
            duration_ms = duration_ms
        })
        callback(symbols)
    end)
end

-- Clean symbol name (remove file extensions based on language)
-- @param name string: Symbol name to clean
-- @param language_config table|nil: Language configuration (optional)
-- @return string: Cleaned symbol name
local function clean_symbol_name(name, language_config)
    if not name then
        return name
    end

    -- If language config provided, use its file extensions
    if language_config and language_config.file_extensions then
        for _, ext in ipairs(language_config.file_extensions) do
            -- Escape special pattern characters in extension
            local escaped_ext = ext:gsub("[%.%-]", "%%%1")

            -- Remove extension from end of name
            name = name:gsub(escaped_ext .. "$", "")

            -- Remove extension from middle of names (e.g., "File.go.Package" -> "File.Package")
            name = name:gsub(escaped_ext .. "%.", ".")
        end
    else
        -- Fallback to C# extensions for backward compatibility
        name = name:gsub("%.cs$", "")
        name = name:gsub("%.vb$", "")
        name = name:gsub("%.fs$", "")
        name = name:gsub("%.cs%.", ".")
        name = name:gsub("%.vb%.", ".")
        name = name:gsub("%.fs%.", ".")
    end

    return name
end

-- Flatten hierarchical symbols into a flat list
-- @param symbols table: Hierarchical symbol list from LSP
-- @param parent_name string|nil: Parent symbol name for building full paths
-- @param result table|nil: Accumulator for flattened results
-- @param language_config table|nil: Language configuration for extension cleaning
-- @return table: Flat list of symbols
function M.flatten_symbols(symbols, parent_name, result, language_config)
    result = result or {}
    parent_name = parent_name or ""

    for _, symbol in ipairs(symbols) do
        -- Clean the symbol name (remove file extensions)
        local clean_name = clean_symbol_name(symbol.name, language_config)

        -- Build full name with parent context
        local full_name = parent_name ~= "" and (parent_name .. "." .. clean_name) or clean_name

        -- Extract symbol information
        local item = {
            name = full_name,
            simple_name = clean_name,
            kind = M.symbol_kind_to_string(symbol.kind),
            detail = symbol.detail,
            range = symbol.range or symbol.location and symbol.location.range,
            selectionRange = symbol.selectionRange,
            children = symbol.children,
        }

        table.insert(result, item)

        -- Recursively process children
        if symbol.children and #symbol.children > 0 then
            M.flatten_symbols(symbol.children, full_name, result, language_config)
        end
    end

    return result
end

-- Convert LSP symbol kind number to string
function M.symbol_kind_to_string(kind)
    local kinds = {
        [1] = "File",
        [2] = "Module",
        [3] = "Namespace",
        [4] = "Package",
        [5] = "Class",
        [6] = "Method",
        [7] = "Property",
        [8] = "Field",
        [9] = "Constructor",
        [10] = "Enum",
        [11] = "Interface",
        [12] = "Function",
        [13] = "Variable",
        [14] = "Constant",
        [15] = "String",
        [16] = "Number",
        [17] = "Boolean",
        [18] = "Array",
        [19] = "Object",
        [20] = "Key",
        [21] = "Null",
        [22] = "EnumMember",
        [23] = "Struct",
        [24] = "Event",
        [25] = "Operator",
        [26] = "TypeParameter",
    }
    return kinds[kind] or "Unknown"
end

-- Get references for a symbol at position
function M.get_references(bufnr, line, col, callback)
    logger.trace("lsp", "get_references called", { bufnr = bufnr, line = line, col = col })

    if not utils.has_lsp_client(bufnr) then
        logger.warn("lsp", "No LSP client attached to buffer", { bufnr = bufnr })
        utils.notify("No LSP client attached to buffer", vim.log.levels.WARN)
        callback(nil)
        return
    end

    local params = vim.lsp.util.make_position_params(0, nil)
    params.context = { includeDeclaration = true }

    logger.debug("lsp", "Requesting references", { bufnr = bufnr, line = line, col = col })
    local start_time = vim.loop.hrtime()

    vim.lsp.buf_request(bufnr, 'textDocument/references', params, function(err, result, ctx)
        local duration_ms = (vim.loop.hrtime() - start_time) / 1000000

        if err then
            logger.error("lsp", "Error getting references", { error = vim.inspect(err), bufnr = bufnr })
            utils.notify("Error getting references: " .. vim.inspect(err), vim.log.levels.ERROR)
            callback(nil)
            return
        end

        if not result or vim.tbl_isempty(result) then
            logger.info("lsp", "No references found", { bufnr = bufnr, duration_ms = duration_ms })
            callback({})
            return
        end

        -- Process references
        local references = {}
        for _, ref in ipairs(result) do
            table.insert(references, {
                uri = ref.uri,
                range = ref.range,
                line = ref.range.start.line + 1,
                col = ref.range.start.character + 1,
            })
        end

        logger.info("lsp", "References retrieved", {
            bufnr = bufnr,
            reference_count = #references,
            duration_ms = duration_ms
        })
        callback(references)
    end)
end

-- Get definition for symbol at position
function M.get_definition(bufnr, line, col, callback)
    if not utils.has_lsp_client(bufnr) then
        utils.notify("No LSP client attached to buffer", vim.log.levels.WARN)
        callback(nil)
        return
    end

    local params = vim.lsp.util.make_position_params(0, nil)

    vim.lsp.buf_request(bufnr, 'textDocument/definition', params, function(err, result, ctx)
        if err then
            utils.notify("Error getting definition: " .. vim.inspect(err), vim.log.levels.ERROR)
            callback(nil)
            return
        end

        if not result or vim.tbl_isempty(result) then
            callback(nil)
            return
        end

        -- Handle both single location and array of locations
        local location = vim.tbl_islist(result) and result[1] or result

        if location then
            callback({
                uri = location.uri or location.targetUri,
                range = location.range or location.targetRange,
                line = (location.range or location.targetRange).start.line + 1,
                col = (location.range or location.targetRange).start.character + 1,
            })
        else
            callback(nil)
        end
    end)
end

-- Get workspace symbols matching query
function M.get_workspace_symbols(query, callback)
    local bufnr = vim.api.nvim_get_current_buf()

    if not utils.has_lsp_client(bufnr) then
        utils.notify("No LSP client attached to buffer", vim.log.levels.WARN)
        callback(nil)
        return
    end

    local params = {
        query = query or ""
    }

    vim.lsp.buf_request(bufnr, 'workspace/symbol', params, function(err, result, ctx)
        if err then
            utils.notify("Error getting workspace symbols: " .. vim.inspect(err), vim.log.levels.ERROR)
            callback(nil)
            return
        end

        if not result or vim.tbl_isempty(result) then
            callback({})
            return
        end

        -- Process symbols
        local symbols = {}
        for _, symbol in ipairs(result) do
            table.insert(symbols, {
                name = symbol.name,
                kind = M.symbol_kind_to_string(symbol.kind),
                location = symbol.location,
                containerName = symbol.containerName,
            })
        end

        callback(symbols)
    end)
end

-- Check if LSP is ready for buffer
function M.is_lsp_ready(bufnr)
    return utils.has_lsp_client(bufnr)
end

-- Get LSP client info for buffer
function M.get_client_info(bufnr)
    local clients = vim.lsp.get_clients({bufnr = bufnr})
    local info = {}

    for _, client in ipairs(clients) do
        table.insert(info, {
            name = client.name,
            id = client.id,
            supports_symbols = client.server_capabilities.documentSymbolProvider,
            supports_references = client.server_capabilities.referencesProvider,
            supports_definition = client.server_capabilities.definitionProvider,
        })
    end

    return info
end

-- Wait for LSP to be ready
function M.wait_for_lsp(bufnr, timeout, callback)
    timeout = timeout or 5000
    local start_time = vim.loop.now()

    local function check()
        if M.is_lsp_ready(bufnr) then
            callback(true)
            return
        end

        if vim.loop.now() - start_time > timeout then
            callback(false)
            return
        end

        vim.defer_fn(check, 100)
    end

    check()
end

return M
