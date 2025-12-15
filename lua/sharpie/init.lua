-- Main plugin module for sharpie.nvim
local config = require('sharpie.config')
local utils = require('sharpie.utils')
local lsp = require('sharpie.lsp-integration')
local queries = require('sharpie.queries')
local hl_groups = require('sharpie.hl_groups')
local fuzzy = require('sharpie.fuzzy')

local M = {}

-- Plugin state
M.state = {
    preview_bufnr = nil,
    preview_winnr = nil,
    main_bufnr = nil,
    symbols = {},
    current_symbol_index = 1,
    current_references = {},
    current_reference_index = 1,
    highlight_enabled = false,
}

-- Setup function
function M.setup(opts)
    config.setup(opts)
    hl_groups.setup()

    -- Set up autocommands if needed
    M.setup_autocommands()

    -- Set up default keybindings if not disabled
    if not config.get().keybindings.disable_default_keybindings then
        M.setup_keybindings()
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
    M.state.main_bufnr = bufnr

    -- Check if buffer is C#
    if not queries.is_csharp_buffer(bufnr) then
        utils.notify("Not a C# buffer", vim.log.levels.WARN)
        return
    end

    -- Get symbols from LSP
    lsp.get_document_symbols(bufnr, function(symbols)
        if not symbols or #symbols == 0 then
            utils.notify("No symbols found", vim.log.levels.INFO)
            return
        end

        M.state.symbols = symbols
        M.render_preview(symbols)
    end)
end

-- Hide preview window
function M.hide(bufnr)
    if M.state.preview_winnr and utils.is_window_valid(M.state.preview_winnr) then
        vim.api.nvim_win_close(M.state.preview_winnr, true)
        M.state.preview_winnr = nil
    end

    if M.state.preview_bufnr and utils.is_buffer_valid(M.state.preview_bufnr) then
        vim.api.nvim_buf_delete(M.state.preview_bufnr, { force = true })
        M.state.preview_bufnr = nil
    end
end

-- Render preview window with symbols
function M.render_preview(symbols)
    -- Create or reuse preview buffer
    if not M.state.preview_bufnr or not utils.is_buffer_valid(M.state.preview_bufnr) then
        M.state.preview_bufnr = utils.create_preview_buffer()
    end

    -- Format symbols for display
    local lines = {}
    for _, symbol in ipairs(symbols) do
        local icon = config.get_icon(symbol.kind)
        local formatted_name = utils.format_symbol_path(symbol, config.get().symbol_options.path)
        local indicators = utils.get_symbol_indicators(symbol)
        local indicator_str = #indicators > 0 and ("(" .. table.concat(indicators, " ") .. ")") or ""

        local line = string.format("%s %s %s", icon, indicator_str, formatted_name)
        table.insert(lines, line)
    end

    -- Set buffer content
    utils.set_buffer_lines(M.state.preview_bufnr, lines)

    -- Apply syntax highlighting
    hl_groups.apply_preview_syntax(M.state.preview_bufnr, symbols)

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

-- Setup keymaps for preview buffer
function M.setup_preview_keymaps(bufnr)
    -- Enter on a line to jump to that symbol
    vim.keymap.set('n', '<CR>', function()
        local line = vim.api.nvim_win_get_cursor(M.state.preview_winnr)[1]
        if line <= #M.state.symbols then
            M.step_to_symbol_by_index(line)
        end
    end, { buffer = bufnr, desc = "Jump to symbol" })

    -- n/p for next/previous symbol
    vim.keymap.set('n', 'n', function() M.step_to_next_symbol() end, { buffer = bufnr, desc = "Next symbol" })
    vim.keymap.set('n', 'p', function() M.step_to_prev_symbol() end, { buffer = bufnr, desc = "Previous symbol" })

    -- q to close
    vim.keymap.set('n', 'q', function() M.hide() end, { buffer = bufnr, desc = "Close preview" })

    -- / to start filtering (search)
    vim.keymap.set('n', '/', function() M.start_filtering() end, { buffer = bufnr, desc = "Filter symbols" })
end

-- Step to symbol by index
function M.step_to_symbol_by_index(index)
    if not M.state.symbols or #M.state.symbols == 0 then
        return
    end

    index = math.max(1, math.min(index, #M.state.symbols))
    M.state.current_symbol_index = index

    local symbol = M.state.symbols[index]
    M.jump_to_symbol(symbol)
end

-- Step to next symbol
function M.step_to_next_symbol(bufnr)
    if not M.state.symbols or #M.state.symbols == 0 then
        return
    end

    M.state.current_symbol_index = M.state.current_symbol_index + 1
    if M.state.current_symbol_index > #M.state.symbols then
        M.state.current_symbol_index = 1
    end

    M.step_to_symbol_by_index(M.state.current_symbol_index)
end

-- Step to previous symbol
function M.step_to_prev_symbol(bufnr)
    if not M.state.symbols or #M.state.symbols == 0 then
        return
    end

    M.state.current_symbol_index = M.state.current_symbol_index - 1
    if M.state.current_symbol_index < 1 then
        M.state.current_symbol_index = #M.state.symbols
    end

    M.step_to_symbol_by_index(M.state.current_symbol_index)
end

-- Jump to symbol location
function M.jump_to_symbol(symbol)
    if not symbol.range then
        return
    end

    local line = symbol.range.start.line + 1
    local col = symbol.range.start.character

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

-- Start filtering in preview window
function M.start_filtering()
    if not M.state.symbols or #M.state.symbols == 0 then
        utils.notify("No symbols loaded", vim.log.levels.WARN)
        return
    end

    fuzzy.search_symbols(M.state.symbols)
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
    local has_lsp = #vim.lsp.get_active_clients() > 0
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
