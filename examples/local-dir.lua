-- ============================================================================
-- sharpie.nvim - Loading from Local Directory
-- ============================================================================
-- This file shows how to configure sharpie.nvim when loading from a local
-- directory using lazy.nvim's 'dir' parameter.
--
-- IMPORTANT: If your directory name differs from the module name, you MUST
-- explicitly set the 'name' field to avoid "Lua module not found" errors.
-- ============================================================================

-- ============================================================================
-- PROBLEM: Directory name doesn't match module name
-- ============================================================================
-- If your directory is named:    sharpier.nvim (or any other name)
-- But the Lua module is:         sharpie
--
-- Lazy.nvim will try to require:  'sharpier' (inferred from directory name)
-- But the actual module is:        'sharpie'
-- Result: "Lua module not found for config of sharpier.nvim"
-- ============================================================================

-- ============================================================================
-- SOLUTION: Explicitly set the 'name' field
-- ============================================================================
{
    dir = '/home/user/projects/sharpier.nvim',  -- Your actual directory name
    name = 'sharpie.nvim',                       -- Explicit name (matches the module)
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        fuzzy_finder = "telescope",
        display = { style = "bottom", height = 20 },
    },
}

-- ============================================================================
-- ALTERNATIVE: Use config function (also works)
-- ============================================================================
{
    dir = '/home/user/projects/sharpier.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
        -- Explicitly require the correct module name
        require('sharpie').setup({
            fuzzy_finder = "telescope",
            display = { style = "bottom", height = 20 },
        })
    end,
}

-- ============================================================================
-- BEST PRACTICE: Rename directory to match module
-- ============================================================================
-- If possible, rename your directory to match the module name:
--   mv ~/projects/sharpier.nvim ~/projects/sharpie.nvim
--
-- Then you can use the simpler configuration:
{
    dir = '/home/user/projects/sharpie.nvim',  -- Now matches module name
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {},  -- No 'name' field needed!
}

-- ============================================================================
-- DEVELOPMENT: Hot-reload from local directory
-- ============================================================================
{
    dir = vim.fn.expand('~/projects/sharpie.nvim'),  -- Use expand for ~
    name = 'sharpie.nvim',
    dev = true,  -- Tells lazy.nvim this is a development plugin
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        logging = {
            enabled = true,
            level = "DEBUG",  -- Enable debug logging during development
        },
    },
}

-- ============================================================================
-- FULL EXAMPLE: Development setup with all features
-- ============================================================================
{
    -- Local directory (could be sharpier.nvim or any name)
    dir = vim.fn.expand('~/projects/sharpier.nvim'),

    -- Explicitly set name to avoid confusion
    name = 'sharpie.nvim',

    -- Mark as development plugin for hot-reload
    dev = true,

    -- Lazy load on C# files
    ft = { 'cs', 'csharp' },

    -- Dependencies
    dependencies = { 'nvim-telescope/telescope.nvim' },

    -- Configuration
    opts = {
        fuzzy_finder = "telescope",
        display = {
            style = "bottom",
            height = 20,
        },
        logging = {
            enabled = true,
            level = "DEBUG",
            console_output = true,  -- See logs in vim.notify during development
        },
    },

    -- Optional: Custom keybindings for development
    keys = {
        { ',s', '<cmd>SharpieShow<cr>', desc = 'Sharpie: Show symbols', ft = 'cs' },
        { ',h', '<cmd>SharpieHide<cr>', desc = 'Sharpie: Hide symbols', ft = 'cs' },
        { ',l', '<cmd>SharpieLog<cr>', desc = 'Sharpie: View log', ft = 'cs' },
        { ',L', '<cmd>SharpieLogStats<cr>', desc = 'Sharpie: Log stats', ft = 'cs' },
    },
}

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. The 'name' field tells lazy.nvim what module to require
-- 2. Without 'name', lazy infers the module name from the directory name
-- 3. If directory is 'sharpier.nvim', lazy will try to require 'sharpier'
-- 4. But the actual module is 'sharpie', causing the error
-- 5. Setting 'name = "sharpie.nvim"' fixes this mismatch
-- 6. The .nvim suffix in 'name' is stripped by lazy to get the module name
-- ============================================================================
