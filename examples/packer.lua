-- Example packer.nvim configuration for sharpie.nvim
-- Add this to your packer startup function

use {
    'yourusername/sharpie.nvim',

    -- Lazy load on C# filetypes
    ft = { 'cs', 'csharp' },

    -- Dependencies
    requires = {
        'nvim-telescope/telescope.nvim',
        -- OR:
        -- 'ibhagwan/fzf-lua',
    },

    -- Configuration
    config = function()
        require('sharpie').setup({
            fuzzy_finder = "telescope",
            display = {
                style = "bottom",
                height = 20,
            },
            logging = {
                enabled = true,
                level = "INFO",
            },
        })
    end
}

-- Minimal configuration:
--[[
use {
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    requires = { 'nvim-telescope/telescope.nvim' },
    config = function()
        require('sharpie').setup()
    end
}
]]
