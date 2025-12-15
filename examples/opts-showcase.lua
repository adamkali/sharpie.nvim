-- ============================================================================
-- sharpie.nvim - lazy.nvim 'opts' Configuration Showcase
-- ============================================================================
-- This file demonstrates various ways to configure sharpie.nvim using the
-- 'opts' parameter, which is the lazy.nvim preferred style.
--
-- When you use 'opts', lazy.nvim automatically calls:
--   require('sharpie').setup(opts)
-- ============================================================================

-- ============================================================================
-- 1. SIMPLEST: Default configuration
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {},
}

-- ============================================================================
-- 2. MINIMAL: Just change one setting
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        display = { style = "float" },  -- Use floating window
    },
}

-- ============================================================================
-- 3. CUSTOM KEYBINDINGS: Change prefix
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            sharpie_local_leader = '<leader>c',  -- Use <leader>c instead of +
        },
    },
}

-- ============================================================================
-- 4. FZF USER: Use fzf-lua instead of telescope
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'ibhagwan/fzf-lua' },
    opts = {
        fuzzy_finder = "fzf",
    },
}

-- ============================================================================
-- 5. DEBUGGING: Enable debug logging
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        logging = {
            enabled = true,
            level = "DEBUG",
            console_output = true,  -- Show logs in vim.notify too
        },
    },
}

-- ============================================================================
-- 6. CUSTOM DISPLAY: Floating window with custom size
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        display = {
            style = "float",
            width = 80,
            height = 40,
        },
    },
}

-- ============================================================================
-- 7. MINIMAL SYMBOLS: Show only symbol name without namespace
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        symbol_options = {
            path = 0,  -- Just symbol name: Main() instead of Program.Main()
        },
    },
}

-- ============================================================================
-- 8. FULL PATH: Show complete namespace path
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        symbol_options = {
            path = 3,  -- Full path: Root.Namespace.Class.Method()
        },
    },
}

-- ============================================================================
-- 9. DISABLE LOGGING: No log file created
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        logging = {
            enabled = false,
        },
    },
}

-- ============================================================================
-- 10. PRODUCTION: Optimized for performance
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        display = {
            style = "bottom",
            height = 15,  -- Smaller window
        },
        symbol_options = {
            path = 1,  -- Less verbose: Class.Method()
        },
        logging = {
            enabled = false,  -- No logging overhead
        },
    },
}

-- ============================================================================
-- 11. COMPLETE: All options configured
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        fuzzy_finder = "telescope",
        display = {
            style = "bottom",
            width = 60,
            height = 20,
            y_offset = 1,
            x_offset = 1,
        },
        cursor_offset = nil,
        style = {
            icon_set = {
                class = "",
                method = "",
                property = "",
                -- ... other icons
            }
        },
        symbol_options = {
            namespace = true,
            path = 2,
        },
        keybindings = {
            sharpie_local_leader = '+',
            disable_default_keybindings = false,
            overrides = {
                show_preview = "<localleader>ss",
                hide_preview = "<localleader>sh",
                -- ... other keybindings
            }
        },
        logging = {
            enabled = true,
            level = "INFO",
            file = vim.fn.stdpath('data') .. '/sharpie.log',
            max_file_size = 10 * 1024 * 1024,
            include_timestamp = true,
            include_location = true,
            console_output = false,
            format = "default",
        },
    },
}

-- ============================================================================
-- 12. LAZY LOAD ON COMMAND: Only load when needed
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    cmd = { 'SharpieShow', 'SharpieSearch' },
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {},  -- Use defaults
}

-- ============================================================================
-- 13. LAZY LOAD ON LSP: Load when C# LSP attaches
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    event = 'LspAttach',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        display = { style = "right", width = 50 },
    },
}

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. All examples use 'opts' which is lazy.nvim's preferred style
-- 2. Any option not specified will use the default value
-- 3. You can combine any options from different examples
-- 4. If you need to run custom code after setup, use 'config' instead:
--
--    config = function(_, opts)
--        require('sharpie').setup(opts)
--        -- Your custom code here
--    end
-- ============================================================================
