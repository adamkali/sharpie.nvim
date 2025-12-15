-- Example lazy.nvim configuration for sharpie.nvim
-- Place this in your lazy.nvim plugin spec (e.g., ~/.config/nvim/lua/plugins/sharpie.lua)

-- ============================================================================
-- RECOMMENDED: Using 'opts' (lazy.nvim preferred style)
-- ============================================================================
return {
    'yourusername/sharpie.nvim',

    -- Lazy load on C# filetypes for better startup time
    ft = { 'cs', 'csharp' },

    -- Alternative: Load when LSP attaches
    -- event = 'LspAttach',

    -- Alternative: Load when commands are used
    -- cmd = {
    --     'SharpieShow',
    --     'SharpieHide',
    --     'SharpieSearch',
    --     'SharpieToggleHighlight',
    --     'SharpieLog',
    -- },

    -- Dependencies
    dependencies = {
        'nvim-telescope/telescope.nvim',  -- For fuzzy finding
        -- OR use fzf-lua instead:
        -- 'ibhagwan/fzf-lua',
    },

    -- Configuration using 'opts' (automatically calls setup)
    opts = {
            -- Fuzzy finder: "telescope" or "fzf"
            fuzzy_finder = "telescope",

            -- Preview window display
            display = {
                style = "bottom",  -- left|right|top|bottom|float
                width = 60,
                height = 20,
            },

            -- Cursor positioning after jump
            cursor_offset = nil,  -- nil = center (zz), or number/percentage

            -- Symbol display options
            symbol_options = {
                namespace = true,  -- Show all classes in namespace
                path = 2,  -- Symbol path depth (0-3)
            },

            -- Keybindings
            keybindings = {
                sharpie_local_leader = '+',  -- Prefix for keybindings
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
                },
            },

            -- Logging configuration
            logging = {
                enabled = true,
                level = "INFO",  -- TRACE, DEBUG, INFO, WARN, ERROR, FATAL
                file = vim.fn.stdpath('data') .. '/sharpie.log',
                max_file_size = 10 * 1024 * 1024,  -- 10MB
                include_timestamp = true,
                include_location = true,  -- Include file:line in logs
                console_output = false,  -- Also output to vim.notify
                format = "default",  -- "default" or "json"
            },
    },
}

-- ============================================================================
-- ALTERNATIVE: Using 'config' function for custom setup
-- ============================================================================
--[[
return {
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
        -- Setup the plugin
        require('sharpie').setup({
            fuzzy_finder = "telescope",
            display = { style = "bottom", height = 20 },
            logging = { enabled = true, level = "INFO" },
        })

        -- Add custom keybindings
        vim.keymap.set('n', '<leader>cs', '<cmd>SharpieShow<cr>', { desc = 'C#: Show symbols' })
        vim.keymap.set('n', '<leader>ch', '<cmd>SharpieHide<cr>', { desc = 'C#: Hide symbols' })
        vim.keymap.set('n', '<leader>cf', '<cmd>SharpieSearch<cr>', { desc = 'C#: Search symbols' })
    end,
}
]]

-- ============================================================================
-- MINIMAL: Use all defaults
-- ============================================================================
--[[
return {
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {},  -- Use all defaults
}
]]

-- ============================================================================
-- CUSTOM KEYBINDINGS: Change the local leader prefix
-- ============================================================================
--[[
return {
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            sharpie_local_leader = '<leader>s',  -- Change from '+' to '<leader>s'
            overrides = {
                show_preview = "<localleader>s",
                hide_preview = "<localleader>h",
                search_symbols = "<localleader>f",
            },
        },
    },
}
]]

-- ============================================================================
-- WITH FZF: Using fzf-lua instead of telescope
-- ============================================================================
--[[
return {
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'ibhagwan/fzf-lua' },
    opts = {
        fuzzy_finder = "fzf",
    },
}
]]

-- ============================================================================
-- FLOATING WINDOW: Use floating window instead of bottom split
-- ============================================================================
--[[
return {
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        display = {
            style = "float",
            width = 60,
            height = 30,
        },
    },
}
]]

-- ============================================================================
-- DEBUG MODE: Enable debug logging from the start
-- ============================================================================
--[[
return {
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        logging = {
            enabled = true,
            level = "DEBUG",
            console_output = true,  -- Also show in vim.notify
        },
    },
}
]]
