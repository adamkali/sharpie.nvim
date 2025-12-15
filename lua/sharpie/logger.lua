-- Comprehensive logging system for sharpie.nvim
-- Provides structured logging with multiple levels and file output

local M = {}

-- Log levels (matching syslog severity levels)
M.levels = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5,
}

-- Level names for display
M.level_names = {
    [0] = "TRACE",
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "FATAL",
}

-- Default configuration
M.config = {
    enabled = true,
    level = M.levels.INFO, -- Only log INFO and above by default
    file = vim.fn.stdpath('data') .. '/sharpie.log',
    max_file_size = 10 * 1024 * 1024, -- 10MB
    include_timestamp = true,
    include_location = true, -- Include file:line information
    console_output = false, -- Also output to console (vim.notify)
    format = "default", -- "default" or "json"
}

-- Current configuration (will be overridden by setup)
M.current_config = vim.deepcopy(M.config)

-- Statistics tracking
M.stats = {
    total_logs = 0,
    by_level = {
        [0] = 0,
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
    },
    last_error = nil,
    session_start = os.date("%Y-%m-%d %H:%M:%S"),
}

-- Setup function to configure logger
function M.setup(user_config)
    user_config = user_config or {}
    for key, value in pairs(user_config) do
        M.current_config[key] = value
    end

    -- Ensure log directory exists
    local log_dir = vim.fn.fnamemodify(M.current_config.file, ':h')
    if vim.fn.isdirectory(log_dir) == 0 then
        vim.fn.mkdir(log_dir, 'p')
    end

    -- Write session start marker
    if M.current_config.enabled then
        M._write_to_file(string.format(
            "\n=== sharpie.nvim session started at %s ===\n",
            M.stats.session_start
        ))
    end
end

-- Get current configuration
function M.get_config()
    return M.current_config
end

-- Get logging statistics
function M.get_stats()
    return M.stats
end

-- Internal function to write to log file
function M._write_to_file(content)
    if not M.current_config.enabled then
        return
    end

    -- Check file size and rotate if necessary
    local file_size = vim.fn.getfsize(M.current_config.file)
    if file_size > M.current_config.max_file_size then
        M._rotate_log_file()
    end

    -- Write to file
    local file = io.open(M.current_config.file, 'a')
    if file then
        file:write(content .. '\n')
        file:close()
    else
        -- Fallback to vim.notify if file write fails
        vim.notify(
            "[sharpie.nvim] Failed to write to log file: " .. M.current_config.file,
            vim.log.levels.ERROR
        )
    end
end

-- Rotate log file when it gets too large
function M._rotate_log_file()
    local backup_file = M.current_config.file .. '.old'

    -- Remove old backup if it exists
    if vim.fn.filereadable(backup_file) == 1 then
        os.remove(backup_file)
    end

    -- Rename current log to backup
    os.rename(M.current_config.file, backup_file)

    -- Log rotation notice
    M._write_to_file(string.format(
        "=== Log rotated at %s ===",
        os.date("%Y-%m-%d %H:%M:%S")
    ))
end

-- Get caller information for logging context
function M._get_caller_info(level)
    if not M.current_config.include_location then
        return nil
    end

    local info = debug.getinfo(level or 4, "Sl")
    if info then
        local source = info.source
        if source:sub(1, 1) == '@' then
            source = source:sub(2) -- Remove @ prefix
        end

        -- Simplify path to just filename
        source = vim.fn.fnamemodify(source, ':t')

        return string.format("%s:%d", source, info.currentline)
    end
    return nil
end

-- Format log message
function M._format_message(level, module, message, context)
    local parts = {}

    -- Timestamp
    if M.current_config.include_timestamp then
        table.insert(parts, os.date("%Y-%m-%d %H:%M:%S"))
    end

    -- Level
    table.insert(parts, string.format("[%-5s]", M.level_names[level]))

    -- Module
    if module and module ~= "" then
        table.insert(parts, string.format("[%s]", module))
    end

    -- Caller location
    local caller = M._get_caller_info(5)
    if caller then
        table.insert(parts, string.format("(%s)", caller))
    end

    -- Message
    table.insert(parts, message)

    -- Context (additional data)
    if context and type(context) == "table" then
        local context_str = vim.inspect(context, { depth = 3, newline = ' ', indent = '' })
        table.insert(parts, "Context: " .. context_str)
    elseif context then
        table.insert(parts, "Context: " .. tostring(context))
    end

    if M.current_config.format == "json" then
        return vim.json.encode({
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            level = M.level_names[level],
            module = module,
            caller = caller,
            message = message,
            context = context,
        })
    else
        return table.concat(parts, " ")
    end
end

-- Core logging function
function M.log(level, module, message, context)
    if not M.current_config.enabled then
        return
    end

    if level < M.current_config.level then
        return
    end

    -- Update statistics
    M.stats.total_logs = M.stats.total_logs + 1
    M.stats.by_level[level] = M.stats.by_level[level] + 1

    if level >= M.levels.ERROR then
        M.stats.last_error = {
            message = message,
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            module = module,
        }
    end

    -- Format and write log message
    local formatted = M._format_message(level, module, message, context)
    M._write_to_file(formatted)

    -- Also output to console if configured
    if M.current_config.console_output then
        local vim_level = vim.log.levels.INFO
        if level >= M.levels.ERROR then
            vim_level = vim.log.levels.ERROR
        elseif level >= M.levels.WARN then
            vim_level = vim.log.levels.WARN
        end
        vim.notify("[sharpie] " .. message, vim_level)
    end
end

-- Convenience functions for each log level
function M.trace(module, message, context)
    M.log(M.levels.TRACE, module, message, context)
end

function M.debug(module, message, context)
    M.log(M.levels.DEBUG, module, message, context)
end

function M.info(module, message, context)
    M.log(M.levels.INFO, module, message, context)
end

function M.warn(module, message, context)
    M.log(M.levels.WARN, module, message, context)
end

function M.error(module, message, context)
    M.log(M.levels.ERROR, module, message, context)
end

function M.fatal(module, message, context)
    M.log(M.levels.FATAL, module, message, context)
end

-- Log function entry/exit for tracing execution flow
function M.trace_call(module, func_name, args)
    if M.current_config.level <= M.levels.TRACE then
        M.trace(module, string.format("-> %s()", func_name), args)
    end
end

function M.trace_return(module, func_name, result)
    if M.current_config.level <= M.levels.TRACE then
        M.trace(module, string.format("<- %s()", func_name), result)
    end
end

-- Log LSP requests/responses
function M.log_lsp_request(method, params)
    M.debug("lsp", string.format("LSP Request: %s", method), { params = params })
end

function M.log_lsp_response(method, success, result_or_error)
    if success then
        M.debug("lsp", string.format("LSP Response: %s [OK]", method), { result = result_or_error })
    else
        M.error("lsp", string.format("LSP Error: %s", method), { error = result_or_error })
    end
end

-- Log state changes
function M.log_state_change(module, state_name, old_value, new_value)
    M.debug(module, string.format("State change: %s", state_name), {
        old = old_value,
        new = new_value,
    })
end

-- Log performance metrics
function M.log_performance(module, operation, duration_ms, details)
    local level = M.levels.DEBUG
    if duration_ms > 1000 then
        level = M.levels.WARN -- Warn if operation takes more than 1 second
    end

    M.log(level, module, string.format("Performance: %s took %.2fms", operation, duration_ms), details)
end

-- Measure and log function execution time
function M.measure(module, operation, func)
    local start_time = vim.loop.hrtime()
    local result = func()
    local duration_ms = (vim.loop.hrtime() - start_time) / 1000000

    M.log_performance(module, operation, duration_ms)

    return result
end

-- Clear log file
function M.clear_log()
    local file = io.open(M.current_config.file, 'w')
    if file then
        file:write(string.format(
            "=== Log cleared at %s ===\n",
            os.date("%Y-%m-%d %H:%M:%S")
        ))
        file:close()
        M.stats = {
            total_logs = 0,
            by_level = {
                [0] = 0,
                [1] = 0,
                [2] = 0,
                [3] = 0,
                [4] = 0,
                [5] = 0,
            },
            last_error = nil,
            session_start = os.date("%Y-%m-%d %H:%M:%S"),
        }
        return true
    end
    return false
end

-- View log file in a split
function M.view_log()
    if vim.fn.filereadable(M.current_config.file) == 0 then
        vim.notify("[sharpie] Log file does not exist: " .. M.current_config.file, vim.log.levels.WARN)
        return
    end

    vim.cmd(string.format('split %s', M.current_config.file))
    vim.cmd('normal! G') -- Jump to end
    vim.bo.readonly = true
    vim.bo.modifiable = false
end

-- Tail log file (follow mode)
function M.tail_log()
    if vim.fn.filereadable(M.current_config.file) == 0 then
        vim.notify("[sharpie] Log file does not exist: " .. M.current_config.file, vim.log.levels.WARN)
        return
    end

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')

    vim.cmd('split')
    local winnr = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(winnr, bufnr)

    -- Load initial content
    local lines = vim.fn.readfile(M.current_config.file)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    -- Auto-update on file change (simple implementation)
    local timer = vim.loop.new_timer()
    timer:start(1000, 1000, vim.schedule_wrap(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
            timer:stop()
            return
        end

        lines = vim.fn.readfile(M.current_config.file)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_win_set_cursor(winnr, {#lines, 0})
    end))
end

-- Print statistics to log
function M.print_stats()
    M.info("logger", "=== Logging Statistics ===")
    M.info("logger", string.format("Session started: %s", M.stats.session_start))
    M.info("logger", string.format("Total log entries: %d", M.stats.total_logs))
    M.info("logger", "Entries by level:")
    for level = 0, 5 do
        M.info("logger", string.format("  %s: %d", M.level_names[level], M.stats.by_level[level]))
    end
    if M.stats.last_error then
        M.info("logger", "Last error:", M.stats.last_error)
    end
    M.info("logger", "===========================")
end

-- Initialize with default config
M.setup({})

return M
