-- Highlight groups management for sharpie.nvim
local M = {}

-- Namespace for highlights
M.namespace = vim.api.nvim_create_namespace('sharpie_nvim')

-- Define default highlight groups
M.highlight_groups = {
    -- Symbol type highlights
    SharpieNamespace = { link = "Type" },
    SharpieClass = { link = "Structure" },
    SharpieInterface = { link = "Type" },
    SharpieStruct = { link = "Structure" },
    SharpieEnum = { link = "Type" },
    SharpieMethod = { link = "Function" },
    SharpieProperty = { link = "Identifier" },
    SharpieField = { link = "Identifier" },
    SharpieConstructor = { link = "Special" },
    SharpieEvent = { link = "Special" },
    SharpieOperator = { link = "Operator" },
    SharpieTypeParameter = { link = "Type" },

    -- Icon highlights
    SharpieIcon = { link = "Special" },

    -- Indicator highlights
    SharpieAsync = { link = "Keyword" },
    SharpieStatic = { link = "Keyword" },
    SharpieGeneric = { link = "Type" },

    -- Search and selection
    SharpieSelected = { link = "Visual" },
    SharpieMatch = { link = "Search" },

    -- Reference highlighting
    SharpieReference = { link = "LspReferenceText" },
    SharpieReferenceRead = { link = "LspReferenceRead" },
    SharpieReferenceWrite = { link = "LspReferenceWrite" },

    -- Preview window
    SharpiePreviewBorder = { link = "FloatBorder" },
    SharpiePreviewTitle = { link = "Title" },

    -- Namespace mode specific highlights
    SharpieNamespaceHeader = { fg = "#61AFEF", bold = true },  -- Blue, bold
    SharpieFileHeader = { fg = "#98C379", bold = true },       -- Green, bold
}

-- Initialize highlight groups
function M.setup()
    for group, opts in pairs(M.highlight_groups) do
        vim.api.nvim_set_hl(0, group, opts)
    end
end

-- Get highlight group for symbol kind
function M.get_hl_for_kind(kind)
    local kind_lower = kind:lower()
    local kind_map = {
        namespace = "SharpieNamespace",
        class = "SharpieClass",
        interface = "SharpieInterface",
        struct = "SharpieStruct",
        enum = "SharpieEnum",
        method = "SharpieMethod",
        ["function"] = "SharpieMethod",
        property = "SharpieProperty",
        field = "SharpieField",
        constructor = "SharpieConstructor",
        event = "SharpieEvent",
        operator = "SharpieOperator",
        typeparameter = "SharpieTypeParameter",
    }

    return kind_map[kind_lower] or "Normal"
end

-- Apply highlight to a line in buffer
function M.highlight_line(bufnr, line, col_start, col_end, hl_group)
    vim.api.nvim_buf_add_highlight(bufnr, M.namespace, hl_group, line, col_start, col_end)
end

-- Clear all highlights in buffer
function M.clear_highlights(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
end

-- Highlight symbol occurrences in buffer
function M.highlight_occurrences(bufnr, positions, hl_group, bg, fg)
    M.clear_highlights(bufnr)

    -- Create custom highlight group if bg/fg provided
    local custom_hl_group = hl_group or "SharpieReference"

    if bg or fg then
        local hl_opts = {}

        -- Parse bg (can be a color or highlight group name)
        if bg then
            if bg:match("^#%x%x%x%x%x%x$") then
                hl_opts.bg = bg
            else
                -- Get bg from another highlight group
                local bg_hl = vim.api.nvim_get_hl(0, {name = bg})
                if bg_hl.bg then
                    hl_opts.bg = string.format("#%06x", bg_hl.bg)
                end
            end
        end

        -- Parse fg (can be a color or highlight group name)
        if fg then
            if fg:match("^#%x%x%x%x%x%x$") then
                hl_opts.fg = fg
            else
                -- Get fg from another highlight group
                local fg_hl = vim.api.nvim_get_hl(0, {name = fg})
                if fg_hl.fg then
                    hl_opts.fg = string.format("#%06x", fg_hl.fg)
                end
            end
        end

        -- Create temporary highlight group
        custom_hl_group = "SharpieCustomHighlight"
        vim.api.nvim_set_hl(0, custom_hl_group, hl_opts)
    end

    -- Apply highlights to all positions
    for _, pos in ipairs(positions) do
        local line = pos.line - 1 -- Convert to 0-indexed
        local col_start = pos.col - 1
        local col_end = pos.col_end or (col_start + pos.length or 0)

        vim.api.nvim_buf_add_highlight(
            bufnr,
            M.namespace,
            custom_hl_group,
            line,
            col_start,
            col_end
        )
    end
end

-- Set extmark for persistent highlight
function M.set_extmark(bufnr, line, col_start, col_end, hl_group)
    return vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line, col_start, {
        end_col = col_end,
        hl_group = hl_group,
        hl_mode = "combine",
    })
end

-- Clear extmark
function M.clear_extmark(bufnr, extmark_id)
    vim.api.nvim_buf_del_extmark(bufnr, M.namespace, extmark_id)
end

-- Get all extmarks in buffer
function M.get_extmarks(bufnr)
    return vim.api.nvim_buf_get_extmarks(bufnr, M.namespace, 0, -1, {})
end

-- Highlight a range in the preview buffer
function M.highlight_preview_line(bufnr, line, hl_group)
    hl_group = hl_group or "SharpieSelected"
    vim.api.nvim_buf_add_highlight(bufnr, M.namespace, hl_group, line - 1, 0, -1)
end

-- Apply syntax highlighting to preview buffer
function M.apply_preview_syntax(bufnr, symbols)
    M.clear_highlights(bufnr)

    for i, symbol in ipairs(symbols) do
        local line = i - 1
        local hl_group = M.get_hl_for_kind(symbol.kind)

        -- Highlight the icon
        local icon_end = symbol.icon and #symbol.icon or 0
        if icon_end > 0 then
            M.highlight_line(bufnr, line, 0, icon_end, "SharpieIcon")
        end

        -- Highlight the symbol name
        -- Find where the actual symbol name starts (after indentation and icon)
        local content = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
        local name_start = content:find("%S", icon_end + 1) or (icon_end + 1)

        M.highlight_line(bufnr, line, name_start - 1, -1, hl_group)
    end
end

return M
