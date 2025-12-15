-- Main plugin module for sharpie.nvim
local config = require('sharpie.config')
local utils = require('sharpie.utils')
local lsp = require('sharpie.lsp-integration')
local queries = require('sharpie.queries')
local hl_groups = require('sharpie.hl_groups')
local fuzzy = require('sharpie.fuzzy')
local logger = require('sharpie.logger')
local symbol_utils = require('sharpie.symbol_utils')

local M = {}

-- Plugin state
M.state = {
    preview_bufnr = nil,
    preview_winnr = nil,
    main_bufnr = nil,
    symbols = {},
    filtered_symbols = {},  -- Filtered symbols for preview
    current_symbol_index = 1,
    current_references = {},
    current_reference_index = 1,
    highlight_enabled = false,
    filter_query = "",  -- Current filter query
    filtering_mode = false,  -- Interactive filtering mode (dired-style)
}

-- Setup function
function M.setup(opts)
    logger.info("init", "Setting up sharpie.nvim")
    config.setup(opts)
    hl_groups.setup()

    -- Set up autocommands if needed
    M.setup_autocommands()

    -- Set up default keybindings if not disabled
    if not config.get().keybindings.disable_default_keybindings then
        logger.debug("init", "Setting up default keybindings")
        M.setup_keybindings()
    else
        logger.debug("init", "Default keybindings disabled")
    end

    logger.info("init", "sharpie.nvim setup complete")
end

-- Debounce timer for buffer changes
local refresh_timer = nil

-- Refresh preview window if it's open
local function refresh_preview_if_open(bufnr)
    -- Only refresh if preview is open and this is the main buffer
    if M.state.preview_winnr and vim.api.nvim_win_is_valid(M.state.preview_winnr) and
       M.state.main_bufnr == bufnr then
        logger.debug("init", "Refreshing preview due to buffer change", { bufnr = bufnr })

        -- Re-fetch symbols and update preview
        lsp.get_document_symbols(bufnr, function(symbols)
            if not symbols then
                logger.warn("init", "Failed to refresh symbols after buffer change")
                return
            end

            M.state.symbols = symbols

            -- If filter is active, re-apply it
            if M.state.filter_query ~= "" then
                M.filter_symbols(M.state.filter_query)
            else
                M.render_preview(symbols)
            end
        end)
    end
end

-- Setup autocommands
function M.setup_autocommands()
    local group = vim.api.nvim_create_augroup('SharpieNvim', { clear = true })

    -- Clean up preview window when buffer is closed
    vim.api.nvim_create_autocmd('BufWipeout', {
        group = group,
        callback = function(ev)
            if M.state.preview_bufnr == ev.buf then
                M.state.preview_bufnr = nil
                M.state.preview_winnr = nil
            end
        end,
    })

    -- Refresh preview when switching to a different buffer
    vim.api.nvim_create_autocmd('BufEnter', {
        group = group,
        pattern = '*.cs',
        callback = function(ev)
            -- Only refresh if preview is open and we switched to a different C# file
            if M.state.preview_winnr and vim.api.nvim_win_is_valid(M.state.preview_winnr) then
                if M.state.main_bufnr ~= ev.buf then
                    logger.debug("init", "Switching to new buffer, refreshing preview", {
                        old_bufnr = M.state.main_bufnr,
                        new_bufnr = ev.buf
                    })

                    -- Update the main buffer reference
                    M.state.main_bufnr = ev.buf

                    -- Clear filter when switching buffers
                    M.state.filter_query = ""
                    M.state.filtered_symbols = {}

                    -- Fetch symbols for the new buffer
                    lsp.get_document_symbols(ev.buf, function(symbols)
                        if symbols then
                            M.state.symbols = symbols
                            M.render_preview(symbols)
                        end
                    end)
                end
            end
        end,
    })

    -- Reload preview when buffer content changes (if enabled)
    local display_config = config.get().display
    if display_config.auto_reload then
        local debounce_time = display_config.auto_reload_debounce or 500

        vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
            group = group,
            pattern = '*.cs',
            callback = function(ev)
                -- Debounce: cancel previous timer and start new one
                if refresh_timer then
                    vim.fn.timer_stop(refresh_timer)
                end

                -- Wait debounce_time after last change before refreshing
                refresh_timer = vim.fn.timer_start(debounce_time, function()
                    refresh_preview_if_open(ev.buf)
                    refresh_timer = nil
                end)
            end,
        })

        -- Also refresh immediately after save
        vim.api.nvim_create_autocmd('BufWritePost', {
            group = group,
            pattern = '*.cs',
            callback = function(ev)
                -- Cancel any pending debounced refresh
                if refresh_timer then
                    vim.fn.timer_stop(refresh_timer)
                    refresh_timer = nil
                end

                -- Refresh immediately after save
                refresh_preview_if_open(ev.buf)
            end,
        })

        logger.info("init", "Auto-reload enabled for preview window", { debounce_ms = debounce_time })
    else
        logger.info("init", "Auto-reload disabled for preview window")
    end
end

-- Setup default keybindings
function M.setup_keybindings()
    local bindings = config.get().keybindings.overrides
    local prefix = config.get().keybindings.sharpie_local_leader

    -- Replace <localleader> with the actual prefix
    for name, mapping in pairs(bindings) do
        local key = mapping:gsub("<localleader>", prefix)

        if name == "show_preview" then
            vim.keymap.set('n', key, function() M.show() end, { desc = "Sharpie: Show preview" })
        elseif name == "hide_preview" then
            vim.keymap.set('n', key, function() M.hide() end, { desc = "Sharpie: Hide preview" })
        elseif name == "step_to_next_symbol" then
            vim.keymap.set('n', key, function() M.step_to_next_symbol() end, { desc = "Sharpie: Next symbol" })
        elseif name == "step_to_prev_symbol" then
            vim.keymap.set('n', key, function() M.step_to_prev_symbol() end, { desc = "Sharpie: Previous symbol" })
        elseif name == "step_to_next_reference" then
            vim.keymap.set('n', key, function() M.step_to_next_reference() end, { desc = "Sharpie: Next reference" })
        elseif name == "step_to_prev_reference" then
            vim.keymap.set('n', key, function() M.step_to_prev_reference() end, { desc = "Sharpie: Previous reference" })
        elseif name == "search_symbols" then
            vim.keymap.set('n', key, function() M.search_symbols() end, { desc = "Sharpie: Search symbols" })
        elseif name == "toggle_highlight" then
            vim.keymap.set('n', key, function() M.toggle_highlight() end, { desc = "Sharpie: Toggle highlight" })
        elseif name == "start_filtering" then
            vim.keymap.set('n', key, function() M.start_filtering() end, { desc = "Sharpie: Start filtering" })
        end
    end
end

-- Show preview window with symbols
function M.show(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    logger.info("init", "show() called", { bufnr = bufnr })
    M.state.main_bufnr = bufnr

    -- Check if buffer is C#
    if not queries.is_csharp_buffer(bufnr) then
        logger.warn("init", "Attempted to show symbols for non-C# buffer", { bufnr = bufnr })
        utils.notify("Not a C# buffer", vim.log.levels.WARN)
        return
    end

    -- Get symbols from LSP
    lsp.get_document_symbols(bufnr, function(symbols)
        if not symbols or #symbols == 0 then
            logger.info("init", "No symbols found in buffer", { bufnr = bufnr })
            utils.notify("No symbols found", vim.log.levels.INFO)
            return
        end

        logger.info("init", "Rendering preview with symbols", { symbol_count = #symbols })
        M.state.symbols = symbols
        M.render_preview(symbols)
    end)
end

-- Hide preview window
function M.hide(bufnr)
    logger.info("init", "hide() called")

    if M.state.preview_winnr and utils.is_window_valid(M.state.preview_winnr) then
        vim.api.nvim_win_close(M.state.preview_winnr, true)
        M.state.preview_winnr = nil
        logger.debug("init", "Preview window closed")
    end

    if M.state.preview_bufnr and utils.is_buffer_valid(M.state.preview_bufnr) then
        vim.api.nvim_buf_delete(M.state.preview_bufnr, { force = true })
        M.state.preview_bufnr = nil
        logger.debug("init", "Preview buffer deleted")
    end
end

-- Render preview window with symbols
-- Visual states based on mode:
-- - Filter Mode: "> query" input line at top
-- - Navigate Mode (filtered): "Filter: X (Y/Z matches)" header
-- - Navigate Mode (no filter): Clean symbol list
function M.render_preview(symbols, use_filtered)
    -- Create or reuse preview buffer
    if not M.state.preview_bufnr or not utils.is_buffer_valid(M.state.preview_bufnr) then
        M.state.preview_bufnr = utils.create_preview_buffer()
    end

    -- Use filtered symbols if filtering is active and we're asked to use them
    local symbols_to_display = use_filtered and M.state.filtered_symbols or symbols

    -- Format symbols for display
    local lines = {}

    -- Visual indicator based on mode
    if M.state.filtering_mode then
        -- FILTER MODE: Show input line
        local prompt = config.get().display.filter_prompt or "> "
        table.insert(lines, prompt .. M.state.filter_query)
        table.insert(lines, string.rep("─", 50))
    elseif M.state.filter_query ~= "" then
        -- NAVIGATE MODE (with filter): Show filter status
        table.insert(lines, string.format("Filter: %s (%d/%d matches)",
            M.state.filter_query,
            #symbols_to_display,
            #M.state.symbols))
        table.insert(lines, string.rep("─", 50))
    end
    -- NAVIGATE MODE (no filter): No header, just symbols

    for _, symbol in ipairs(symbols_to_display) do
        -- Get appropriate icon (handles Task types specially)
        local icon = symbol_utils.get_symbol_icon(symbol, config.get())
        local formatted_name = utils.format_symbol_path(symbol, config.get().symbol_options.path)
        local indicators = utils.get_symbol_indicators(symbol)
        local indicator_str = #indicators > 0 and ("(" .. table.concat(indicators, " ") .. ")") or ""

        local line = string.format("%s %s %s", icon, indicator_str, formatted_name)
        table.insert(lines, line)
    end

    -- Set buffer content
    utils.set_buffer_lines(M.state.preview_bufnr, lines)

    -- Apply syntax highlighting
    hl_groups.apply_preview_syntax(M.state.preview_bufnr, symbols_to_display)

    -- Create or update window
    if not M.state.preview_winnr or not utils.is_window_valid(M.state.preview_winnr) then
        local display_config = config.get().display
        local win_config = utils.calculate_window_config(
            display_config.style,
            display_config.width,
            display_config.height,
            display_config.y_offset,
            display_config.x_offset
        )

        M.state.preview_winnr = utils.create_window(M.state.preview_bufnr, win_config)

        -- Set up buffer-local keymaps for the preview window
        M.setup_preview_keymaps(M.state.preview_bufnr)
    end
end

-- Clear all preview keymaps from the buffer
local function clear_preview_keymaps(bufnr)
    local preview_keys = config.get().keybindings.preview

    -- Remove all preview window keymaps
    if preview_keys.jump_to_symbol then
        pcall(vim.keymap.del, 'n', preview_keys.jump_to_symbol, { buffer = bufnr })
    end
    if preview_keys.next_symbol then
        pcall(vim.keymap.del, 'n', preview_keys.next_symbol, { buffer = bufnr })
    end
    if preview_keys.prev_symbol then
        pcall(vim.keymap.del, 'n', preview_keys.prev_symbol, { buffer = bufnr })
    end
    if preview_keys.close then
        pcall(vim.keymap.del, 'n', preview_keys.close, { buffer = bufnr })
    end
    if preview_keys.filter then
        pcall(vim.keymap.del, 'n', preview_keys.filter, { buffer = bufnr })
    end
    if preview_keys.clear_filter then
        pcall(vim.keymap.del, 'n', preview_keys.clear_filter, { buffer = bufnr })
    end
end

-- Setup keymaps for preview buffer (Navigate Mode)
function M.setup_preview_keymaps(bufnr)
    local preview_keys = config.get().keybindings.preview
    logger.debug("init", "Setting up Navigate Mode keymaps", preview_keys)

    -- Clear any existing keymaps first (prevents duplicates)
    clear_preview_keymaps(bufnr)

    -- Jump to symbol under cursor
    if preview_keys.jump_to_symbol and preview_keys.jump_to_symbol ~= "" then
        vim.keymap.set('n', preview_keys.jump_to_symbol, function()
            local line = vim.api.nvim_win_get_cursor(M.state.preview_winnr)[1]

            -- Check if filtering is active
            local is_filtered = M.state.filter_query ~= ""
            local symbol_list = is_filtered and M.state.filtered_symbols or M.state.symbols

            -- Account for filter status header (2 lines when filtered)
            local symbol_index = line
            if is_filtered and line > 2 then
                symbol_index = line - 2  -- Skip the filter header lines
            end

            if symbol_index > 0 and symbol_index <= #symbol_list then
                M.step_to_symbol_by_index(symbol_index, is_filtered)
            end
        end, { buffer = bufnr, desc = "Sharpie: Jump to symbol" })
    end

    -- Next symbol
    if preview_keys.next_symbol and preview_keys.next_symbol ~= "" then
        vim.keymap.set('n', preview_keys.next_symbol, function()
            M.step_to_next_symbol()
        end, { buffer = bufnr, desc = "Sharpie: Next symbol" })
    end

    -- Previous symbol
    if preview_keys.prev_symbol and preview_keys.prev_symbol ~= "" then
        vim.keymap.set('n', preview_keys.prev_symbol, function()
            M.step_to_prev_symbol()
        end, { buffer = bufnr, desc = "Sharpie: Previous symbol" })
    end

    -- Close preview
    if preview_keys.close and preview_keys.close ~= "" then
        vim.keymap.set('n', preview_keys.close, function()
            M.hide()
        end, { buffer = bufnr, desc = "Sharpie: Close preview" })
    end

    -- Start filtering
    if preview_keys.filter and preview_keys.filter ~= "" then
        vim.keymap.set('n', preview_keys.filter, function()
            M.start_filtering()
        end, { buffer = bufnr, desc = "Sharpie: Filter symbols" })
    end

    -- Clear filter
    if preview_keys.clear_filter and preview_keys.clear_filter ~= "" then
        vim.keymap.set('n', preview_keys.clear_filter, function()
            M.clear_filter()
        end, { buffer = bufnr, desc = "Sharpie: Clear filter" })
    end
end

-- Step to symbol by index
function M.step_to_symbol_by_index(index, use_filtered)
    if not M.state.symbols or #M.state.symbols == 0 then
        return
    end

    -- Use filtered symbols if filtering is active
    local symbol_list = (use_filtered and M.state.filter_query ~= "") and M.state.filtered_symbols or M.state.symbols

    index = math.max(1, math.min(index, #symbol_list))
    M.state.current_symbol_index = index

    local symbol = symbol_list[index]
    logger.info("init", "Jumping to symbol", {
        symbol = symbol.name,
        line = symbol.range and symbol.range.start.line or "unknown",
        col = symbol.range and symbol.range.start.character or "unknown",
        filtered = use_filtered and M.state.filter_query ~= ""
    })
    M.jump_to_symbol(symbol)
end

-- Step to next symbol
function M.step_to_next_symbol(bufnr)
    if not M.state.symbols or #M.state.symbols == 0 then
        return
    end

    -- Use filtered symbols if filtering is active
    local is_filtered = M.state.filter_query ~= ""
    local symbol_list = is_filtered and M.state.filtered_symbols or M.state.symbols

    M.state.current_symbol_index = M.state.current_symbol_index + 1
    if M.state.current_symbol_index > #symbol_list then
        M.state.current_symbol_index = 1
    end

    M.step_to_symbol_by_index(M.state.current_symbol_index, is_filtered)
end

-- Step to previous symbol
function M.step_to_prev_symbol(bufnr)
    if not M.state.symbols or #M.state.symbols == 0 then
        return
    end

    -- Use filtered symbols if filtering is active
    local is_filtered = M.state.filter_query ~= ""
    local symbol_list = is_filtered and M.state.filtered_symbols or M.state.symbols

    M.state.current_symbol_index = M.state.current_symbol_index - 1
    if M.state.current_symbol_index < 1 then
        M.state.current_symbol_index = #symbol_list
    end

    M.step_to_symbol_by_index(M.state.current_symbol_index, is_filtered)
end

-- Jump to symbol location
function M.jump_to_symbol(symbol)
    -- Prefer selectionRange (points to symbol name) over range (whole declaration)
    local target_range = symbol.selectionRange or symbol.range

    if not target_range then
        logger.warn("init", "Attempted to jump to symbol without range", { symbol = symbol.name })
        return
    end

    local line = target_range.start.line + 1
    local col = target_range.start.character

    logger.info("init", "Jumping to symbol", {
        symbol = symbol.name,
        line = line,
        col = col,
        used_selection_range = symbol.selectionRange ~= nil
    })

    -- Get the main window
    local main_winnr = utils.get_main_window(M.state.preview_winnr)

    -- Switch to main window
    vim.api.nvim_set_current_win(main_winnr)

    -- Jump to location
    vim.api.nvim_win_set_cursor(main_winnr, {line, col})

    -- Apply cursor offset
    local cursor_offset = config.get().cursor_offset
    utils.position_cursor(main_winnr, line, cursor_offset)
end

-- Step to next reference
function M.step_to_next_reference(bufnr)
    if not M.state.current_references or #M.state.current_references == 0 then
        -- Get references for current symbol
        M.get_current_symbol_references()
        return
    end

    M.state.current_reference_index = M.state.current_reference_index + 1
    if M.state.current_reference_index > #M.state.current_references then
        M.state.current_reference_index = 1
    end

    local ref = M.state.current_references[M.state.current_reference_index]
    M.jump_to_reference(ref)
end

-- Step to previous reference
function M.step_to_prev_reference(bufnr)
    if not M.state.current_references or #M.state.current_references == 0 then
        -- Get references for current symbol
        M.get_current_symbol_references()
        return
    end

    M.state.current_reference_index = M.state.current_reference_index - 1
    if M.state.current_reference_index < 1 then
        M.state.current_reference_index = #M.state.current_references
    end

    local ref = M.state.current_references[M.state.current_reference_index]
    M.jump_to_reference(ref)
end

-- Jump to reference location
function M.jump_to_reference(ref)
    local filename = vim.uri_to_fname(ref.uri)
    vim.cmd('edit ' .. filename)
    vim.api.nvim_win_set_cursor(0, {ref.line, ref.col - 1})

    local cursor_offset = config.get().cursor_offset
    utils.position_cursor(vim.api.nvim_get_current_win(), ref.line, cursor_offset)
end

-- Get references for current symbol
function M.get_current_symbol_references()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line, col = cursor[1], cursor[2]
    local bufnr = vim.api.nvim_get_current_buf()

    lsp.get_references(bufnr, line, col, function(references)
        if references and #references > 0 then
            M.state.current_references = references
            M.state.current_reference_index = 1
            utils.notify(string.format("Found %d references", #references), vim.log.levels.INFO)
        else
            utils.notify("No references found", vim.log.levels.INFO)
        end
    end)
end

-- Search symbols using fuzzy finder
function M.search_symbols(query, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if not queries.is_csharp_buffer(bufnr) then
        utils.notify("Not a C# buffer", vim.log.levels.WARN)
        return
    end

    lsp.get_document_symbols(bufnr, function(symbols)
        if not symbols or #symbols == 0 then
            utils.notify("No symbols found", vim.log.levels.INFO)
            return
        end

        fuzzy.search_symbols(symbols, {
            prompt = query or "",
        })
    end)
end

-- Filter symbols based on query
function M.filter_symbols(query)
    logger.debug("init", "Filtering symbols", { query = query })

    if query == "" then
        -- Clear filter
        M.state.filter_query = ""
        M.state.filtered_symbols = M.state.symbols
        M.render_preview(M.state.symbols, false)
        return
    end

    -- Case-insensitive filtering
    local query_lower = query:lower()
    M.state.filter_query = query
    M.state.filtered_symbols = {}

    for _, symbol in ipairs(M.state.symbols) do
        local symbol_name = symbol.name or symbol.simple_name or ""
        if symbol_name:lower():find(query_lower, 1, true) then
            table.insert(M.state.filtered_symbols, symbol)
        end
    end

    logger.info("init", "Filtered symbols", {
        query = query,
        total = #M.state.symbols,
        matches = #M.state.filtered_symbols
    })

    -- Re-render with filtered symbols
    M.render_preview(M.state.symbols, true)
end

-- Clear all filtering keymaps from the buffer
local function clear_filtering_keymaps(bufnr)
    -- Remove all printable character keymaps
    local all_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.<>()[]{}!@#$%^&*+=|\\:;'\",?/ "
    for i = 1, #all_chars do
        local char = all_chars:sub(i, i)
        pcall(vim.keymap.del, 'n', char, { buffer = bufnr })
    end

    -- Remove special keys
    pcall(vim.keymap.del, 'n', '<BS>', { buffer = bufnr })
    pcall(vim.keymap.del, 'n', '<CR>', { buffer = bufnr })
    pcall(vim.keymap.del, 'n', '<Esc>', { buffer = bufnr })
    pcall(vim.keymap.del, 'n', 'q', { buffer = bufnr })

    -- Remove navigation keys that might have been set
    local preview_keys = config.get().keybindings.preview
    if preview_keys.next_symbol then
        pcall(vim.keymap.del, 'n', preview_keys.next_symbol, { buffer = bufnr })
    end
    if preview_keys.prev_symbol then
        pcall(vim.keymap.del, 'n', preview_keys.prev_symbol, { buffer = bufnr })
    end
    if preview_keys.jump_to_symbol then
        pcall(vim.keymap.del, 'n', preview_keys.jump_to_symbol, { buffer = bufnr })
    end
end

-- Enter Filter Mode (dired-style interactive filtering)
-- Transitions from Navigate Mode → Filter Mode
-- Visual: Shows input line at top: "> query"
-- Keybindings: Characters input, n/p navigate, Enter/Esc/q exit
function M.enter_filtering_mode()
    if M.state.filtering_mode then
        return  -- Already in Filter Mode
    end

    logger.info("init", "Entering Filter Mode")
    M.state.filtering_mode = true
    M.state.filter_query = ""  -- Start with empty query

    -- Re-render to show the input line
    M.filter_symbols("")

    -- Set up Filter Mode keymaps (characters input, navigation preserved)
    M.setup_filtering_keymaps()

    -- Move cursor to the input line (line 1)
    if M.state.preview_winnr and vim.api.nvim_win_is_valid(M.state.preview_winnr) then
        vim.api.nvim_win_set_cursor(M.state.preview_winnr, {1, #(config.get().display.filter_prompt or "> ") + #M.state.filter_query})
    end
end

-- Exit Filter Mode and return to Navigate Mode
-- Transitions from Filter Mode → Navigate Mode
-- Visual: Removes input line, shows "Filter: X (Y/Z)" if filter active
-- Keybindings: Restores Navigate Mode keymaps (n/p navigate, Enter jumps)
-- Filter: Preserved if query not empty, cleared if empty
function M.exit_filtering_mode()
    if not M.state.filtering_mode then
        return  -- Already in Navigate Mode
    end

    logger.info("init", "Exiting Filter Mode → Navigate Mode", { final_query = M.state.filter_query })
    M.state.filtering_mode = false

    -- CRITICAL: Clear all filtering keymaps before setting up navigate keymaps
    clear_filtering_keymaps(M.state.preview_bufnr)

    -- Restore Navigate Mode keymaps
    M.setup_preview_keymaps(M.state.preview_bufnr)

    -- Re-render to update display
    -- - If filter active: Shows "Filter: X (Y/Z matches)" header
    -- - If no filter: Shows clean symbol list
    if M.state.filter_query ~= "" then
        M.filter_symbols(M.state.filter_query)
    else
        M.render_preview(M.state.symbols, false)
    end
end

-- Handle character input in filtering mode
function M.filter_add_char(char)
    M.state.filter_query = M.state.filter_query .. char
    logger.trace("init", "Added character to filter", { char = char, query = M.state.filter_query })

    -- Filter and re-render
    M.filter_symbols(M.state.filter_query)

    -- Update cursor position to end of input
    if M.state.preview_winnr and vim.api.nvim_win_is_valid(M.state.preview_winnr) then
        local prompt_len = #(config.get().display.filter_prompt or "> ")
        vim.api.nvim_win_set_cursor(M.state.preview_winnr, {1, prompt_len + #M.state.filter_query})
    end
end

-- Handle backspace in filtering mode
function M.filter_backspace()
    if #M.state.filter_query > 0 then
        M.state.filter_query = M.state.filter_query:sub(1, -2)
        logger.trace("init", "Removed character from filter", { query = M.state.filter_query })

        -- Filter and re-render
        M.filter_symbols(M.state.filter_query)

        -- Update cursor position
        if M.state.preview_winnr and vim.api.nvim_win_is_valid(M.state.preview_winnr) then
            local prompt_len = #(config.get().display.filter_prompt or "> ")
            vim.api.nvim_win_set_cursor(M.state.preview_winnr, {1, prompt_len + #M.state.filter_query})
        end
    end
end

-- Set up keymaps for interactive filtering mode
function M.setup_filtering_keymaps()
    local bufnr = M.state.preview_bufnr

    -- Clear all existing keymaps first
    clear_filtering_keymaps(bufnr)

    -- Navigation keys (available during filtering)
    local preview_keys = config.get().keybindings.preview

    -- Next/previous symbol navigation (works during filtering)
    if preview_keys.next_symbol and preview_keys.next_symbol ~= "" then
        vim.keymap.set('n', preview_keys.next_symbol, function()
            M.step_to_next_symbol()
        end, { buffer = bufnr, nowait = true, desc = "Next symbol (while filtering)" })
    end

    if preview_keys.prev_symbol and preview_keys.prev_symbol ~= "" then
        vim.keymap.set('n', preview_keys.prev_symbol, function()
            M.step_to_prev_symbol()
        end, { buffer = bufnr, nowait = true, desc = "Previous symbol (while filtering)" })
    end

    -- Jump to symbol under cursor (works during filtering)
    if preview_keys.jump_to_symbol and preview_keys.jump_to_symbol ~= "" then
        vim.keymap.set('n', preview_keys.jump_to_symbol, function()
            -- Exit filtering mode and jump
            M.exit_filtering_mode()

            -- Now jump to the symbol
            local line = vim.api.nvim_win_get_cursor(M.state.preview_winnr)[1]
            local is_filtered = M.state.filter_query ~= ""
            local symbol_list = is_filtered and M.state.filtered_symbols or M.state.symbols

            -- Account for input line (2 lines when filtering)
            local symbol_index = line
            if line > 2 then
                symbol_index = line - 2
            end

            if symbol_index > 0 and symbol_index <= #symbol_list then
                M.step_to_symbol_by_index(symbol_index, is_filtered)
            end
        end, { buffer = bufnr, nowait = true, desc = "Jump to symbol (exit filter)" })
    end

    -- Printable characters (excluding navigation keys n, p, and CR)
    -- Build list dynamically to exclude configured navigation keys
    local excluded_chars = {}
    if preview_keys.next_symbol then excluded_chars[preview_keys.next_symbol] = true end
    if preview_keys.prev_symbol then excluded_chars[preview_keys.prev_symbol] = true end
    if preview_keys.jump_to_symbol then excluded_chars[preview_keys.jump_to_symbol] = true end
    excluded_chars["q"] = true  -- q exits filtering mode

    local all_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.<>()[]{}!@#$%^&*+=|\\:;'\",?/ "
    for i = 1, #all_chars do
        local char = all_chars:sub(i, i)
        if not excluded_chars[char] then
            vim.keymap.set('n', char, function()
                M.filter_add_char(char)
            end, { buffer = bufnr, nowait = true })
        end
    end

    -- Special keys
    vim.keymap.set('n', '<BS>', function()
        M.filter_backspace()
    end, { buffer = bufnr, nowait = true, desc = "Remove last character" })

    vim.keymap.set('n', '<CR>', function()
        M.exit_filtering_mode()
    end, { buffer = bufnr, nowait = true, desc = "Accept filter and exit filtering mode" })

    vim.keymap.set('n', '<Esc>', function()
        M.state.filter_query = ""
        M.exit_filtering_mode()
    end, { buffer = bufnr, nowait = true, desc = "Clear filter and exit" })

    -- q exits filtering mode (keeps current filter)
    vim.keymap.set('n', 'q', function()
        M.exit_filtering_mode()
    end, { buffer = bufnr, nowait = true, desc = "Exit filtering mode" })
end

-- Start filtering in preview window
function M.start_filtering()
    if not M.state.symbols or #M.state.symbols == 0 then
        utils.notify("No symbols loaded", vim.log.levels.WARN)
        return
    end

    -- If preview is open, use interactive filtering (dired-style)
    if M.state.preview_winnr and utils.is_window_valid(M.state.preview_winnr) then
        logger.info("init", "Starting interactive filtering")

        -- Switch to preview window
        vim.api.nvim_set_current_win(M.state.preview_winnr)

        -- Enter filtering mode
        M.enter_filtering_mode()
    else
        -- Preview not open, use fuzzy finder
        fuzzy.search_symbols(M.state.symbols)
    end
end

-- Clear filter
function M.clear_filter()
    logger.info("init", "Clearing filter")
    M.state.filter_query = ""
    M.state.filtered_symbols = M.state.symbols

    -- Exit filtering mode if active
    if M.state.filtering_mode then
        M.exit_filtering_mode()
    elseif M.state.preview_winnr and utils.is_window_valid(M.state.preview_winnr) then
        M.render_preview(M.state.symbols, false)
    end
end

-- Search and go to reference
function M.search_go_to_reference(symbol_id, bufnr)
    -- Implementation for searching and going to reference
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)

    lsp.get_references(bufnr, cursor[1], cursor[2], function(references)
        if not references or #references == 0 then
            utils.notify("No references found", vim.log.levels.INFO)
            return
        end

        -- Show references picker
        local finder = fuzzy.get_finder()
        if finder and finder.show_references then
            finder.show_references(references)
        end
    end)
end

-- Search and go to definition
function M.search_go_to_definition(symbol_id, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)

    lsp.get_definition(bufnr, cursor[1], cursor[2], function(definition)
        if not definition then
            utils.notify("No definition found", vim.log.levels.INFO)
            return
        end

        M.jump_to_reference(definition)
    end)
end

-- Highlight symbol occurrences
function M.highlight_symbol_occurrences(symbol_id, hl_group, bufnr, bg, fg, on)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    -- If on is nil, toggle
    if on == nil then
        on = not M.state.highlight_enabled
    elseif on == -1 or on == 0 or on == false then
        on = false
    else
        on = true
    end

    M.state.highlight_enabled = on

    if not on then
        -- Clear highlights
        hl_groups.clear_highlights(bufnr)
        return
    end

    -- Get references for symbol under cursor
    local cursor = vim.api.nvim_win_get_cursor(0)
    lsp.get_references(bufnr, cursor[1], cursor[2], function(references)
        if not references or #references == 0 then
            utils.notify("No references found", vim.log.levels.INFO)
            return
        end

        -- Convert references to positions for highlighting
        local positions = {}
        for _, ref in ipairs(references) do
            if vim.uri_to_fname(ref.uri) == vim.api.nvim_buf_get_name(bufnr) then
                table.insert(positions, {
                    line = ref.line,
                    col = ref.col,
                    length = 10, -- Estimate, LSP doesn't always provide length
                })
            end
        end

        hl_groups.highlight_occurrences(bufnr, positions, hl_group, bg, fg)
        utils.notify(string.format("Highlighted %d occurrences", #positions), vim.log.levels.INFO)
    end)
end

-- Toggle highlight
function M.toggle_highlight()
    M.highlight_symbol_occurrences(nil, nil, nil, nil, nil, nil)
end

-- Add occurrences to quickfix list
function M.add_occurences_to_qflist(symbol_id, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)

    lsp.get_references(bufnr, cursor[1], cursor[2], function(references)
        if not references or #references == 0 then
            utils.notify("No references found", vim.log.levels.INFO)
            return
        end

        -- Convert references to quickfix format
        local qf_list = {}
        for _, ref in ipairs(references) do
            table.insert(qf_list, {
                filename = vim.uri_to_fname(ref.uri),
                lnum = ref.line,
                col = ref.col,
                text = "Reference",
            })
        end

        vim.fn.setqflist(qf_list)
        vim.cmd("copen")
        utils.notify(string.format("Added %d references to quickfix", #qf_list), vim.log.levels.INFO)
    end)
end

-- Health check
function M.checkhealth()
    vim.health = vim.health or require('health')
    local health = vim.health

    health.report_start("sharpie.nvim")

    -- Check LSP
    local has_lsp = #vim.lsp.get_clients() > 0
    if has_lsp then
        health.report_ok("LSP is active")
    else
        health.report_warn("No LSP clients active")
    end

    -- Check for C# LSP
    local has_csharp_lsp = utils.get_csharp_client(vim.api.nvim_get_current_buf()) ~= nil
    if has_csharp_lsp then
        health.report_ok("C# LSP client found")
    else
        health.report_warn("No C# LSP client found (omnisharp or csharp)")
    end

    -- Check treesitter
    if queries.has_treesitter() then
        health.report_ok("Treesitter is available")
    else
        health.report_info("Treesitter is not available (optional)")
    end

    -- Check fuzzy finder
    local fuzzy_config = config.get().fuzzy_finder
    if fuzzy_config == "telescope" then
        local has_telescope = pcall(require, 'telescope')
        if has_telescope then
            health.report_ok("Telescope is available")
        else
            health.report_error("Telescope is not installed but configured")
        end
    elseif fuzzy_config == "fzf" then
        local has_fzf = pcall(require, 'fzf-lua')
        if has_fzf then
            health.report_ok("FZF-lua is available")
        else
            health.report_error("FZF-lua is not installed but configured")
        end
    end
end

return M
