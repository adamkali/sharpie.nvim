-- Plugin commands and setup for sharpie.nvim

-- Create user commands
vim.api.nvim_create_user_command('SharpieShow', function()
    require('sharpie').show()
end, {
    desc = "Show sharpie preview window with symbols"
})

vim.api.nvim_create_user_command('SharpieHide', function()
    require('sharpie').hide()
end, {
    desc = "Hide sharpie preview window"
})

vim.api.nvim_create_user_command('SharpieSearch', function()
    require('sharpie').search_symbols()
end, {
    desc = "Search symbols with fuzzy finder"
})

vim.api.nvim_create_user_command('SharpieToggleHighlight', function()
    require('sharpie').toggle_highlight()
end, {
    desc = "Toggle symbol highlighting"
})

vim.api.nvim_create_user_command('SharpieNextSymbol', function()
    require('sharpie').step_to_next_symbol()
end, {
    desc = "Jump to next symbol"
})

vim.api.nvim_create_user_command('SharpiePrevSymbol', function()
    require('sharpie').step_to_prev_symbol()
end, {
    desc = "Jump to previous symbol"
})

vim.api.nvim_create_user_command('SharpieNextReference', function()
    require('sharpie').step_to_next_reference()
end, {
    desc = "Jump to next reference"
})

vim.api.nvim_create_user_command('SharpiePrevReference', function()
    require('sharpie').step_to_prev_reference()
end, {
    desc = "Jump to previous reference"
})

vim.api.nvim_create_user_command('SharpieFilterClear', function()
    require('sharpie').clear_filter()
end, {
    desc = "Clear symbol filter in preview"
})

vim.api.nvim_create_user_command('SharpieToggleNamespaceMode', function()
    require('sharpie').toggle_namespace_mode()
end, {
    desc = "Toggle between file-only and namespace-wide symbol view"
})

-- Logging commands
vim.api.nvim_create_user_command('SharpieLog', function(opts)
    local logger = require('sharpie.logger')
    if opts.args == "tail" then
        logger.tail_log()
    else
        logger.view_log()
    end
end, {
    nargs = '?',
    complete = function()
        return { 'tail' }
    end,
    desc = "View sharpie log file (use 'tail' for follow mode)"
})

vim.api.nvim_create_user_command('SharpieLogClear', function()
    local logger = require('sharpie.logger')
    if logger.clear_log() then
        vim.notify("[sharpie] Log cleared", vim.log.levels.INFO)
    else
        vim.notify("[sharpie] Failed to clear log", vim.log.levels.ERROR)
    end
end, {
    desc = "Clear sharpie log file"
})

vim.api.nvim_create_user_command('SharpieLogStats', function()
    local logger = require('sharpie.logger')
    local stats = logger.get_stats()

    local lines = {
        "=== sharpie.nvim Logging Statistics ===",
        "",
        string.format("Session started: %s", stats.session_start),
        string.format("Total log entries: %d", stats.total_logs),
        "",
        "Entries by level:",
    }

    for level = 0, 5 do
        table.insert(lines, string.format("  %-6s: %d", logger.level_names[level], stats.by_level[level]))
    end

    if stats.last_error then
        table.insert(lines, "")
        table.insert(lines, "Last error:")
        table.insert(lines, string.format("  Time: %s", stats.last_error.timestamp))
        table.insert(lines, string.format("  Module: %s", stats.last_error.module))
        table.insert(lines, string.format("  Message: %s", stats.last_error.message))
    end

    table.insert(lines, "")
    table.insert(lines, string.format("Log file: %s", logger.get_config().file))

    -- Display in a floating window
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

    local width = 60
    local height = #lines + 2
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' Logging Statistics ',
        title_pos = 'center',
    })

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
end, {
    desc = "Show sharpie logging statistics"
})

vim.api.nvim_create_user_command('SharpieLogLevel', function(opts)
    local logger = require('sharpie.logger')
    local config = require('sharpie.config')

    if opts.args == "" then
        local current_level = logger.level_names[logger.get_config().level]
        vim.notify(string.format("[sharpie] Current log level: %s", current_level), vim.log.levels.INFO)
        return
    end

    local level = opts.args:upper()
    if not logger.levels[level] then
        vim.notify(string.format("[sharpie] Invalid log level: %s", opts.args), vim.log.levels.ERROR)
        vim.notify("[sharpie] Valid levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL", vim.log.levels.INFO)
        return
    end

    logger.setup({ level = logger.levels[level] })
    vim.notify(string.format("[sharpie] Log level set to: %s", level), vim.log.levels.INFO)
    logger.info("init", "Log level changed via command", { new_level = level })
end, {
    nargs = '?',
    complete = function()
        return { 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL' }
    end,
    desc = "Get or set sharpie log level"
})
