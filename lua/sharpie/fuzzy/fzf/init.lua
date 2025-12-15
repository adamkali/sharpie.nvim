-- FZF integration for sharpie.nvim
local has_fzf, fzf = pcall(require, 'fzf-lua')
if not has_fzf then
    return {}
end

local config = require('sharpie.config')
local utils = require('sharpie.utils')

local M = {}

-- Format symbol for FZF display
local function format_symbol(symbol)
    local icon = config.get_icon(symbol.kind)
    local name = symbol.name or symbol.simple_name or "Unknown"
    local detail = symbol.detail or ""

    return string.format("%s %s %s", icon, name, detail)
end

-- Parse FZF selection back to symbol
local function parse_selection(line, symbols)
    -- Try to match the line with a symbol
    for _, symbol in ipairs(symbols) do
        local formatted = format_symbol(symbol)
        if formatted == line then
            return symbol
        end
    end

    -- Fallback: try to match by name
    for _, symbol in ipairs(symbols) do
        if line:match(symbol.name or symbol.simple_name or "") then
            return symbol
        end
    end

    return nil
end

-- Show symbol picker
function M.show_picker(symbols, custom_actions)
    custom_actions = custom_actions or {}

    -- Format symbols for FZF
    local entries = {}
    for i, symbol in ipairs(symbols) do
        table.insert(entries, format_symbol(symbol))
    end

    -- Create FZF options
    local fzf_opts = {
        prompt = "Symbols> ",
        fzf_opts = {
            ['--layout'] = 'reverse',
            ['--info'] = 'inline',
        },
        actions = {
            ['default'] = function(selected)
                if not selected or #selected == 0 then
                    return
                end

                local symbol = parse_selection(selected[1], symbols)
                if symbol then
                    if custom_actions.on_select then
                        custom_actions.on_select(symbol)
                    else
                        M.default_goto_symbol(symbol)
                    end
                end
            end,
            ['ctrl-r'] = function(selected)
                if not selected or #selected == 0 then
                    return
                end

                local symbol = parse_selection(selected[1], symbols)
                if symbol and custom_actions.find_references then
                    custom_actions.find_references(symbol)
                end
            end,
            ['ctrl-h'] = function(selected)
                if not selected or #selected == 0 then
                    return
                end

                local symbol = parse_selection(selected[1], symbols)
                if symbol and custom_actions.highlight then
                    custom_actions.highlight(symbol)
                end
            end,
        }
    }

    fzf.fzf_exec(entries, fzf_opts)
end

-- Search symbols with FZF
function M.search_symbols(symbols, opts)
    opts = opts or {}

    -- Format symbols for FZF
    local entries = {}
    for i, symbol in ipairs(symbols) do
        table.insert(entries, format_symbol(symbol))
    end

    -- Create FZF options
    local fzf_opts = {
        prompt = "Search Symbols> ",
        fzf_opts = {
            ['--layout'] = 'reverse',
            ['--info'] = 'inline',
        },
        actions = {
            ['default'] = function(selected)
                if not selected or #selected == 0 then
                    return
                end

                local symbol = parse_selection(selected[1], symbols)
                if symbol then
                    M.default_goto_symbol(symbol)
                end
            end,
        }
    }

    fzf.fzf_exec(entries, fzf_opts)
end

-- Default goto symbol action
function M.default_goto_symbol(symbol)
    if not symbol.range then
        utils.notify("Symbol has no location information", vim.log.levels.WARN)
        return
    end

    local line = symbol.range.start.line + 1
    local col = symbol.range.start.character

    -- Jump to the symbol location
    vim.api.nvim_win_set_cursor(0, {line, col})

    -- Apply cursor offset
    local cursor_offset = config.get().cursor_offset
    utils.position_cursor(vim.api.nvim_get_current_win(), line, cursor_offset)

    -- Flash the line
    vim.cmd("normal! zz")
end

-- Show references picker
function M.show_references(references)
    if not references or #references == 0 then
        utils.notify("No references found", vim.log.levels.INFO)
        return
    end

    -- Format references for FZF
    local entries = {}
    for _, ref in ipairs(references) do
        local filename = vim.fn.fnamemodify(vim.uri_to_fname(ref.uri), ':.')
        table.insert(entries, string.format("%s:%d:%d", filename, ref.line, ref.col))
    end

    -- Create FZF options
    local fzf_opts = {
        prompt = "References> ",
        fzf_opts = {
            ['--layout'] = 'reverse',
            ['--info'] = 'inline',
        },
        actions = {
            ['default'] = function(selected)
                if not selected or #selected == 0 then
                    return
                end

                -- Parse the selection (format: filename:line:col)
                local parts = vim.split(selected[1], ":", {plain = true})
                if #parts >= 2 then
                    local filename = parts[1]
                    local line = tonumber(parts[2])
                    local col = tonumber(parts[3]) or 1

                    vim.cmd('edit ' .. filename)
                    vim.api.nvim_win_set_cursor(0, {line, col - 1})
                    vim.cmd("normal! zz")
                end
            end,
        }
    }

    fzf.fzf_exec(entries, fzf_opts)
end

return M
