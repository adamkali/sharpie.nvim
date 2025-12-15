-- LSP integration for sharpie.nvim
local utils = require('sharpie.utils')
local M = {}

-- Get document symbols from LSP
function M.get_document_symbols(bufnr, callback)
    if not utils.has_lsp_client(bufnr) then
        utils.notify("No LSP client attached to buffer", vim.log.levels.WARN)
        callback(nil)
        return
    end

    local params = {
        textDocument = vim.lsp.util.make_text_document_params(bufnr)
    }

    vim.lsp.buf_request(bufnr, 'textDocument/documentSymbol', params, function(err, result, ctx)
        if err then
            utils.notify("Error getting document symbols: " .. vim.inspect(err), vim.log.levels.ERROR)
            callback(nil)
            return
        end

        if not result or vim.tbl_isempty(result) then
            callback({})
            return
        end

        -- Flatten and process symbols
        local symbols = M.flatten_symbols(result)
        callback(symbols)
    end)
end

-- Flatten hierarchical symbols into a flat list
function M.flatten_symbols(symbols, parent_name, result)
    result = result or {}
    parent_name = parent_name or ""

    for _, symbol in ipairs(symbols) do
        -- Build full name with parent context
        local full_name = parent_name ~= "" and (parent_name .. "." .. symbol.name) or symbol.name

        -- Extract symbol information
        local item = {
            name = full_name,
            simple_name = symbol.name,
            kind = M.symbol_kind_to_string(symbol.kind),
            detail = symbol.detail,
            range = symbol.range or symbol.location and symbol.location.range,
            selectionRange = symbol.selectionRange,
            children = symbol.children,
        }

        table.insert(result, item)

        -- Recursively process children
        if symbol.children and #symbol.children > 0 then
            M.flatten_symbols(symbol.children, full_name, result)
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
    if not utils.has_lsp_client(bufnr) then
        utils.notify("No LSP client attached to buffer", vim.log.levels.WARN)
        callback(nil)
        return
    end

    local params = vim.lsp.util.make_position_params(0, nil)
    params.context = { includeDeclaration = true }

    vim.lsp.buf_request(bufnr, 'textDocument/references', params, function(err, result, ctx)
        if err then
            utils.notify("Error getting references: " .. vim.inspect(err), vim.log.levels.ERROR)
            callback(nil)
            return
        end

        if not result or vim.tbl_isempty(result) then
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
    local clients = vim.lsp.get_active_clients({bufnr = bufnr})
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
