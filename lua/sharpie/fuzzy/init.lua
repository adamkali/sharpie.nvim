-- Fuzzy finder interface for sharpie.nvim
local config = require('sharpie.config')
local utils = require('sharpie.utils')
local symbol_utils = require('sharpie.symbol_utils')
local M = {}

-- Get the appropriate fuzzy finder implementation
function M.get_finder()
    local finder_type = config.get().fuzzy_finder

    if finder_type == "telescope" then
        local ok, telescope = pcall(require, 'sharpie.fuzzy.telescope')
        if ok then
            return telescope
        else
            utils.notify("Telescope not available, falling back to fzf", vim.log.levels.WARN)
            finder_type = "fzf"
        end
    end

    if finder_type == "fzf" then
        local ok, fzf = pcall(require, 'sharpie.fuzzy.fzf')
        if ok then
            return fzf
        else
            utils.notify("FZF not available", vim.log.levels.ERROR)
            return nil
        end
    end

    utils.notify("Unknown fuzzy finder: " .. finder_type, vim.log.levels.ERROR)
    return nil
end

-- Search for symbols using the configured fuzzy finder
function M.search_symbols(symbols, opts)
    opts = opts or {}
    local finder = M.get_finder()

    if not finder then
        utils.notify("No fuzzy finder available", vim.log.levels.ERROR)
        return
    end

    if not symbols or #symbols == 0 then
        utils.notify("No symbols to search", vim.log.levels.WARN)
        return
    end

    finder.search_symbols(symbols, opts)
end

-- Show symbol picker with actions
function M.show_picker(symbols, actions)
    local finder = M.get_finder()

    if not finder then
        utils.notify("No fuzzy finder available", vim.log.levels.ERROR)
        return
    end

    if not symbols or #symbols == 0 then
        utils.notify("No symbols available", vim.log.levels.WARN)
        return
    end

    finder.show_picker(symbols, actions)
end

-- Format symbol for display in fuzzy finder
function M.format_symbol_for_picker(symbol)
    -- Use smart icon detection (handles Task types)
    local icon = symbol_utils.get_symbol_icon(symbol, config.get())
    local name = symbol.name or symbol.simple_name or "Unknown"

    -- Add detail if available
    local detail = symbol.detail and (" " .. symbol.detail) or ""

    return string.format("%s %s%s", icon, name, detail)
end

-- Parse user selection from fuzzy finder
function M.parse_selection(selection, symbols)
    -- Try to find the symbol that matches the selection
    for i, symbol in ipairs(symbols) do
        local formatted = M.format_symbol_for_picker(symbol)
        if formatted == selection or symbol.name == selection then
            return symbol, i
        end
    end
    return nil, nil
end

return M
