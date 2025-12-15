-- Telescope integration for sharpie.nvim
local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
    return {}
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local entry_display = require('telescope.pickers.entry_display')

local config = require('sharpie.config')
local utils = require('sharpie.utils')
local lsp = require('sharpie.lsp-integration')

local M = {}

-- Create entry maker for symbols
local function make_entry_maker()
    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 3 },  -- icon
            { width = 30 }, -- name
            { remaining = true }, -- detail
        },
    })

    return function(symbol)
        local icon = config.get_icon(symbol.kind)
        local name = symbol.name or symbol.simple_name or "Unknown"
        local detail = symbol.detail or ""

        return {
            value = symbol,
            display = function(entry)
                return displayer({
                    icon,
                    name,
                    detail,
                })
            end,
            ordinal = name .. " " .. detail,
            symbol = symbol,
        }
    end
end

-- Show symbol picker
function M.show_picker(symbols, custom_actions)
    custom_actions = custom_actions or {}

    pickers.new({}, {
        prompt_title = "Sharpie Symbols",
        finder = finders.new_table({
            results = symbols,
            entry_maker = make_entry_maker(),
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            -- Default action: go to definition
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                if selection and selection.symbol then
                    if custom_actions.on_select then
                        custom_actions.on_select(selection.symbol)
                    else
                        M.default_goto_symbol(selection.symbol)
                    end
                end
            end)

            -- Custom action: find references
            if custom_actions.find_references then
                map('i', '<C-r>', function()
                    local selection = action_state.get_selected_entry()
                    if selection and selection.symbol then
                        custom_actions.find_references(selection.symbol)
                    end
                end)
            end

            -- Custom action: highlight occurrences
            if custom_actions.highlight then
                map('i', '<C-h>', function()
                    local selection = action_state.get_selected_entry()
                    if selection and selection.symbol then
                        custom_actions.highlight(selection.symbol)
                    end
                end)
            end

            return true
        end,
    }):find()
end

-- Search symbols with telescope
function M.search_symbols(symbols, opts)
    opts = opts or {}

    pickers.new(opts, {
        prompt_title = "Search Symbols",
        finder = finders.new_table({
            results = symbols,
            entry_maker = make_entry_maker(),
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                if selection and selection.symbol then
                    M.default_goto_symbol(selection.symbol)
                end
            end)

            return true
        end,
    }):find()
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

    pickers.new({}, {
        prompt_title = "Symbol References",
        finder = finders.new_table({
            results = references,
            entry_maker = function(ref)
                local filename = vim.fn.fnamemodify(vim.uri_to_fname(ref.uri), ':.')
                return {
                    value = ref,
                    display = string.format("%s:%d:%d", filename, ref.line, ref.col),
                    ordinal = filename,
                    filename = vim.uri_to_fname(ref.uri),
                    lnum = ref.line,
                    col = ref.col,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = conf.grep_previewer({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                if selection then
                    vim.cmd('edit ' .. selection.filename)
                    vim.api.nvim_win_set_cursor(0, {selection.lnum, selection.col - 1})
                    vim.cmd("normal! zz")
                end
            end)

            return true
        end,
    }):find()
end

return M
