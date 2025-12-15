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
    },

    -- Cursor positioning after jump
    -- nil = same as 'zz' (center), can be percentage (0.0-1.0) or number of rows from top
    cursor_offset = nil,

    -- Style settings
    style = {
        icon_set = {
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
    },

    -- Keybinding settings
    keybindings = {
        sharpie_local_leader = '+', -- prefix for all keybindings
        disable_default_keybindings = false,
        overrides = {
            show_preview = "<localleader>ss",
            hide_preview = "<localleader>sh",
            step_to_next_symbol = "<localleader>sn",
            step_to_prev_symbol = "<localleader>sp",
            step_to_next_reference = "<localleader>sN",
            step_to_prev_reference = "<localleader>sP",
            search_symbols = "<localleader>sf",
            toggle_highlight = "<localleader>sH",
            start_filtering = "<localleader>s.",
        }
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
