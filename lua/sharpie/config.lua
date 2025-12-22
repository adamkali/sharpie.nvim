-- Configuration module for sharpie.nvim
local M = {}

-- Default configuration
M.defaults = {
    -- Fuzzy finder to use: "telescope" or "fzf"
    fuzzy_finder = "telescope",

    -- Display settings for the preview window
    display = {
        style = "bottom", -- left|right|top|bottom|float
        width = 60, -- width of the preview window (ignored if style is top or bottom)
        height = 20, -- height of the preview window (ignored if style is left or right)
        y_offset = 1, -- y offset (floats interpreted as percentage) (ignored if style is left, right, top, or bottom)
        x_offset = 1, -- x offset (floats interpreted as percentage) (ignored if style is left, right, top, or bottom)
        auto_reload = true, -- Automatically reload preview when buffer changes
        auto_reload_debounce = 500, -- Debounce time in ms for auto-reload (default: 500ms)
        filter_prompt = "> ", -- Prompt shown when filtering (dired-style)
    },

    -- Cursor positioning after jump
    -- nil = same as 'zz' (center), can be percentage (0.0-1.0) or number of rows from top
    cursor_offset = nil,

    -- Style settings
    style = {
        icon_set = {
            -- Generic LSP symbol kinds
            namespace = "",
            class = "",
            method = "",
            property = "",
            field = "",
            constructor = "",
            enum = "",
            interface = "",
            struct = "",
            event = "",
            operator = "",
            type_parameter = "",
            search = "",
            -- Generic type icons
            integer = "",
            string = "󰀬",
            boolean = "",
            array = "󰅪",
            number = "",
            null = "󰟢",
            void = "󰟢",
            object = "",
            dictionary = "",
            key = "",
            -- C# specific
            task = "⏳",  -- Hourglass for Task/async methods
            -- Go specific
            go_slice = "󰅪",  -- Slice (similar to array but distinct)
            go_map = "",  -- Map/dictionary
            go_channel = "󰘖",  -- Channel
            go_interface = "",  -- Interface
            go_struct = "",  -- Struct
            go_error = "",  -- Error type
        }
    },

    -- Symbol display options
    symbol_options = {
        namespace = true, -- show all classes in the namespace and not just the classes in the current buffer
        -- Path display depth:
        -- 3: FullNamespace.Leading.To.MyNamespace.Program.Main(string[] args)
        -- 2: MyNamespace.Program.Main(string[] args)
        -- 1: Program.Main(string[] args)
        -- 0: Main(string[] args)
        path = 2,
        workspace_symbols = true, -- Query symbols from entire workspace/project, not just current file
        show_file_location = true, -- Show file path for symbols from other files
        namespace_mode_separator_style = "line", -- Style for file separators in namespace mode: "line" | "box" | "bold"
    },

    -- Keybinding settings
    keybindings = {
        sharpie_local_leader = '+', -- prefix for all keybindings
        disable_default_keybindings = false,
        overrides = {
            show_preview = "<localleader>s",
            hide_preview = "<localleader>h",
            step_to_next_symbol = "<localleader>n",
            step_to_prev_symbol = "<localleader>p",
            step_to_next_reference = "<localleader>N",
            step_to_prev_reference = "<localleader>P",
            search_symbols = "<localleader>f",
            toggle_highlight = "<localleader>H",
            toggle_namespace_mode = "<localleader>t",
            start_filtering = "<localleader>s.",
        },
        -- Preview window keybindings (buffer-local)
        preview = {
            jump_to_symbol = "<CR>",       -- Jump to symbol under cursor
            next_symbol = "n",             -- Navigate to next symbol
            prev_symbol = "p",             -- Navigate to previous symbol
            close = "q",                   -- Close preview window
            filter = "/",                  -- Start filtering/searching
            clear_filter = "<Esc>",        -- Clear filter and show all symbols
        }
    },

    -- Language-specific feature configuration
    language = {
        -- Auto-detect language from buffer filetype (default behavior)
        auto_detect = true,

        -- Force a specific language: "csharp" | "go" | nil
        -- nil = use auto-detection based on filetype
        force = nil,

        -- C# specific features
        csharp = {
            show_async_indicators = true,  -- Show async/await indicators
            show_access_modifiers = true,  -- Show public/private/protected
            show_task_types = true,        -- Show Task<T> return type icons
        },

        -- Go specific features
        go = {
            show_receiver_types = true,        -- Show method receiver types
            show_channel_direction = true,     -- Show channel direction indicators
            show_exported_indicator = true,    -- Show exported vs unexported symbols
            detect_goroutine_funcs = true,     -- Detect and mark goroutine functions
            show_error_returns = true,         -- Highlight functions returning errors
        },
    },

    -- Logging configuration
    logging = {
        enabled = true,
        level = "INFO", -- TRACE, DEBUG, INFO, WARN, ERROR, FATAL
        file = vim.fn.stdpath('data') .. '/sharpie.log',
        max_file_size = 10 * 1024 * 1024, -- 10MB
        include_timestamp = true,
        include_location = true,
        console_output = false, -- Also output to vim.notify
        format = "default", -- "default" or "json"
    }
}

-- Current configuration (will be merged with user config)
M.options = vim.deepcopy(M.defaults)

-- Deep merge function
local function deep_merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            target[key] = deep_merge(target[key], value)
        else
            target[key] = value
        end
    end
    return target
end

-- Setup function to merge user configuration
function M.setup(user_config)
    user_config = user_config or {}
    M.options = deep_merge(vim.deepcopy(M.defaults), user_config)

    -- Setup logger with merged config
    local logger = require('sharpie.logger')
    local log_config = M.options.logging
    logger.setup({
        enabled = log_config.enabled,
        level = logger.levels[log_config.level] or logger.levels.INFO,
        file = log_config.file,
        max_file_size = log_config.max_file_size,
        include_timestamp = log_config.include_timestamp,
        include_location = log_config.include_location,
        console_output = log_config.console_output,
        format = log_config.format,
    })

    logger.info("config", "Configuration loaded", {
        fuzzy_finder = M.options.fuzzy_finder,
        display_style = M.options.display.style,
        logging_enabled = log_config.enabled,
    })

    return M.options
end

-- Get current configuration
function M.get()
    return M.options
end

-- Get icon for symbol kind
function M.get_icon(kind)
    local icons = M.options.style.icon_set
    local kind_lower = kind:lower()

    -- Map LSP symbol kinds to icon names
    local kind_map = {
        file = "file",
        module = "namespace",
        namespace = "namespace",
        package = "namespace",
        class = "class",
        method = "method",
        property = "property",
        field = "field",
        constructor = "constructor",
        enum = "enum",
        interface = "interface",
        ["function"] = "method",
        variable = "field",
        constant = "field",
        string = "string",
        number = "number",
        boolean = "boolean",
        array = "array",
        object = "object",
        key = "key",
        null = "null",
        enummember = "field",
        struct = "struct",
        event = "event",
        operator = "operator",
        typeparameter = "type_parameter",
    }

    local icon_key = kind_map[kind_lower] or "object"
    return icons[icon_key] or ""
end

return M
