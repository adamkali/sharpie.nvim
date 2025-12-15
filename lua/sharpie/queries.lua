-- Treesitter queries for sharpie.nvim (fallback when LSP is unavailable)
local M = {}

-- Check if treesitter is available
function M.has_treesitter()
    local ok, _ = pcall(require, 'nvim-treesitter')
    return ok
end

-- C# treesitter query for classes, methods, properties, etc.
M.csharp_query = [[
    (namespace_declaration
        name: (identifier) @namespace.name) @namespace

    (class_declaration
        name: (identifier) @class.name) @class

    (interface_declaration
        name: (identifier) @interface.name) @interface

    (struct_declaration
        name: (identifier) @struct.name) @struct

    (enum_declaration
        name: (identifier) @enum.name) @enum

    (method_declaration
        name: (identifier) @method.name) @method

    (property_declaration
        name: (identifier) @property.name) @property

    (field_declaration
        (variable_declaration
            (variable_declarator
                (identifier) @field.name))) @field

    (constructor_declaration
        name: (identifier) @constructor.name) @constructor

    (event_declaration
        name: (identifier) @event.name) @event
]]

-- Parse buffer using treesitter and extract symbols
function M.get_symbols_from_treesitter(bufnr)
    if not M.has_treesitter() then
        return {}
    end

    local parser = vim.treesitter.get_parser(bufnr, 'c_sharp')
    if not parser then
        return {}
    end

    local tree = parser:parse()[1]
    local root = tree:root()

    local query = vim.treesitter.query.parse('c_sharp', M.csharp_query)
    local symbols = {}

    for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
        local capture_name = query.captures[id]
        local text = vim.treesitter.get_node_text(node, bufnr)
        local start_row, start_col, end_row, end_col = node:range()

        -- Determine symbol kind from capture name
        local kind = M.capture_to_kind(capture_name)

        if kind then
            table.insert(symbols, {
                name = text,
                kind = kind,
                range = {
                    start = { line = start_row, character = start_col },
                    ["end"] = { line = end_row, character = end_col }
                },
                line = start_row + 1,
                col = start_col + 1,
            })
        end
    end

    return symbols
end

-- Convert treesitter capture name to symbol kind
function M.capture_to_kind(capture_name)
    local kind_map = {
        ["namespace.name"] = "Namespace",
        ["class.name"] = "Class",
        ["interface.name"] = "Interface",
        ["struct.name"] = "Struct",
        ["enum.name"] = "Enum",
        ["method.name"] = "Method",
        ["property.name"] = "Property",
        ["field.name"] = "Field",
        ["constructor.name"] = "Constructor",
        ["event.name"] = "Event",
    }

    return kind_map[capture_name]
end

-- Get the node at a specific position
function M.get_node_at_pos(bufnr, line, col)
    if not M.has_treesitter() then
        return nil
    end

    local parser = vim.treesitter.get_parser(bufnr, 'c_sharp')
    if not parser then
        return nil
    end

    local tree = parser:parse()[1]
    local root = tree:root()

    -- Convert to 0-indexed
    local node = root:named_descendant_for_range(line - 1, col - 1, line - 1, col - 1)
    return node
end

-- Get symbol at cursor position
function M.get_symbol_at_cursor(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line, col = cursor[1], cursor[2]

    local node = M.get_node_at_pos(bufnr, line, col)
    if not node then
        return nil
    end

    local text = vim.treesitter.get_node_text(node, bufnr)
    local start_row, start_col, end_row, end_col = node:range()

    return {
        name = text,
        kind = node:type(),
        range = {
            start = { line = start_row, character = start_col },
            ["end"] = { line = end_row, character = end_col }
        },
        line = start_row + 1,
        col = start_col + 1,
    }
end

-- Find all occurrences of a symbol in buffer using treesitter
function M.find_symbol_occurrences(bufnr, symbol_name)
    if not M.has_treesitter() then
        return {}
    end

    local parser = vim.treesitter.get_parser(bufnr, 'c_sharp')
    if not parser then
        return {}
    end

    local tree = parser:parse()[1]
    local root = tree:root()

    local occurrences = {}

    -- Simple query to find identifiers
    local query_str = string.format('((identifier) @id (#eq? @id "%s"))', symbol_name)
    local ok, query = pcall(vim.treesitter.query.parse, 'c_sharp', query_str)

    if not ok then
        return {}
    end

    for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
        local start_row, start_col, end_row, end_col = node:range()
        table.insert(occurrences, {
            line = start_row + 1,
            col = start_col + 1,
            col_end = end_col + 1,
            length = end_col - start_col,
        })
    end

    return occurrences
end

-- Check if buffer has C# filetype
function M.is_csharp_buffer(bufnr)
    local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
    return ft == 'cs' or ft == 'csharp'
end

return M
