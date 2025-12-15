-- Utility functions for sharpie.nvim
local M = {}

-- Create a new buffer for the preview window
function M.create_preview_buffer()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'sharpie')
    return bufnr
end

-- Calculate window dimensions and position based on style
function M.calculate_window_config(style, width, height, y_offset, x_offset)
    local editor_width = vim.o.columns
    local editor_height = vim.o.lines

    if style == "float" then
        -- Calculate centered floating window position
        local win_width = width
        local win_height = height

        -- Handle offsets as percentages or absolute values
        local row = type(y_offset) == "number" and y_offset < 1 and y_offset or
                    math.floor((editor_height - win_height) / 2)
        local col = type(x_offset) == "number" and x_offset < 1 and x_offset or
                    math.floor((editor_width - win_width) / 2)

        return {
            relative = 'editor',
            width = win_width,
            height = win_height,
            row = row,
            col = col,
            style = 'minimal',
            border = 'rounded',
        }
    else
        -- For split windows, return configuration for vim.cmd
        return {
            style = style,
            width = width,
            height = height,
        }
    end
end

-- Create window based on style
function M.create_window(bufnr, config)
    local winnr

    if config.relative then
        -- Floating window
        winnr = vim.api.nvim_open_win(bufnr, true, config)
    else
        -- Split window
        local split_cmd
        if config.style == "left" then
            split_cmd = "topleft vertical " .. config.width .. "split"
        elseif config.style == "right" then
            split_cmd = "botright vertical " .. config.width .. "split"
        elseif config.style == "top" then
            split_cmd = "topleft " .. config.height .. "split"
        elseif config.style == "bottom" then
            split_cmd = "botright " .. config.height .. "split"
        end

        vim.cmd(split_cmd)
        winnr = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(winnr, bufnr)
    end

    -- Set window options
    vim.api.nvim_win_set_option(winnr, 'number', false)
    vim.api.nvim_win_set_option(winnr, 'relativenumber', false)
    vim.api.nvim_win_set_option(winnr, 'cursorline', true)
    vim.api.nvim_win_set_option(winnr, 'wrap', false)

    return winnr
end

-- Set buffer contents
function M.set_buffer_lines(bufnr, lines)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

-- Position cursor in window with offset
function M.position_cursor(winnr, line, cursor_offset)
    vim.api.nvim_win_set_cursor(winnr, {line, 0})

    -- Apply cursor offset (like zz, zt, etc.)
    if cursor_offset == nil then
        -- Default: center the line (like zz)
        vim.cmd("normal! zz")
    elseif type(cursor_offset) == "number" then
        if cursor_offset >= 0 and cursor_offset < 1 then
            -- Percentage from top
            local win_height = vim.api.nvim_win_get_height(winnr)
            local target_line = math.floor(win_height * cursor_offset)
            vim.fn.winrestview({topline = math.max(1, line - target_line)})
        else
            -- Absolute row offset from top
            vim.fn.winrestview({topline = math.max(1, line - cursor_offset)})
        end
    end
end

-- Get the main window (the one we're viewing symbols from)
function M.get_main_window(preview_winnr)
    local windows = vim.api.nvim_list_wins()
    for _, winnr in ipairs(windows) do
        if winnr ~= preview_winnr and vim.api.nvim_win_get_config(winnr).relative == "" then
            return winnr
        end
    end
    return vim.api.nvim_get_current_win()
end

-- Check if buffer is valid and loaded
function M.is_buffer_valid(bufnr)
    return bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)
end

-- Check if window is valid
function M.is_window_valid(winnr)
    return winnr and vim.api.nvim_win_is_valid(winnr)
end

-- Format symbol path based on depth configuration
function M.format_symbol_path(symbol, depth)
    local parts = vim.split(symbol.name or "", ".", {plain = true})

    if depth == 0 then
        -- Just the symbol name
        return parts[#parts] or symbol.name
    elseif depth == 1 then
        -- Class.Symbol
        return table.concat({parts[#parts - 1] or "", parts[#parts] or ""}, ".")
    elseif depth == 2 then
        -- Namespace.Class.Symbol
        local start = math.max(1, #parts - 2)
        return table.concat(vim.list_slice(parts, start), ".")
    else
        -- Full path
        return symbol.name
    end
end

-- Parse symbol signature to add type indicators
function M.get_symbol_indicators(symbol)
    local indicators = {}

    -- Check for async
    if symbol.detail and symbol.detail:match("async") then
        table.insert(indicators, "")
    end

    -- Check for static
    if symbol.detail and symbol.detail:match("static") then
        table.insert(indicators, "")
    end

    -- Check for generic types (< >)
    if symbol.detail and symbol.detail:match("<.*>") then
        table.insert(indicators, "<>")
    end

    return indicators
end

-- Escape special characters for lua pattern matching
function M.escape_pattern(text)
    return text:gsub("([^%w])", "%%%1")
end

-- Convert LSP position to vim position (0-indexed to 1-indexed)
function M.lsp_pos_to_vim(pos)
    return {
        line = pos.line + 1,
        col = pos.character + 1
    }
end

-- Convert vim position to LSP position (1-indexed to 0-indexed)
function M.vim_pos_to_lsp(pos)
    return {
        line = pos.line - 1,
        character = pos.col - 1
    }
end

-- Check if LSP client is attached to buffer
function M.has_lsp_client(bufnr, client_name)
    local clients = vim.lsp.get_active_clients({bufnr = bufnr})
    for _, client in ipairs(clients) do
        if client_name == nil or client.name == client_name then
            return true
        end
    end
    return false
end

-- Get C# LSP client for buffer
function M.get_csharp_client(bufnr)
    local clients = vim.lsp.get_active_clients({bufnr = bufnr})
    for _, client in ipairs(clients) do
        if client.name:match("omnisharp") or client.name:match("csharp") then
            return client
        end
    end
    return nil
end

-- Debounce function
function M.debounce(func, delay)
    local timer = nil
    return function(...)
        local args = {...}
        if timer then
            timer:stop()
        end
        timer = vim.defer_fn(function()
            func(unpack(args))
        end, delay)
    end
end

-- Notify user with message
function M.notify(message, level)
    level = level or vim.log.levels.INFO
    vim.notify("[sharpie.nvim] " .. message, level)
end

return M
