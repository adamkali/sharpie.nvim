-- ============================================================================
-- sharpie.nvim - Custom Keybindings Examples
-- ============================================================================
-- This file shows various ways to customize keybindings for sharpie.nvim,
-- including both global keybindings and preview window keybindings.
-- ============================================================================

-- ============================================================================
-- EXAMPLE 1: Change local leader prefix
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            sharpie_local_leader = ',',  -- Use comma instead of +
            -- All keybindings will now use , as prefix (,ss, ,sh, etc.)
        }
    }
}

-- ============================================================================
-- EXAMPLE 2: Vim-like preview navigation (j/k instead of n/p)
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            preview = {
                jump_to_symbol = "<CR>",
                next_symbol = "j",        -- Vim-like: j for down/next
                prev_symbol = "k",        -- Vim-like: k for up/previous
                close = "q",
                filter = "/",
            }
        }
    }
}

-- ============================================================================
-- EXAMPLE 3: Use Escape to close preview
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            preview = {
                close = "<Esc>",  -- Press Esc to close instead of q
            }
        }
    }
}

-- ============================================================================
-- EXAMPLE 4: Disable default keybindings (use commands only)
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            disable_default_keybindings = true,  -- Disable all global keybindings
            -- Preview keybindings still work
            preview = {
                jump_to_symbol = "<CR>",
                close = "q",
            }
        }
    },
    -- Set up your own custom keybindings
    keys = {
        { '<leader>cs', '<cmd>SharpieShow<cr>', desc = 'C#: Show symbols', ft = 'cs' },
        { '<leader>ch', '<cmd>SharpieHide<cr>', desc = 'C#: Hide symbols', ft = 'cs' },
    }
}

-- ============================================================================
-- EXAMPLE 5: Minimal preview keybindings (only jump and close)
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            preview = {
                jump_to_symbol = "<CR>",
                next_symbol = "",      -- Disabled
                prev_symbol = "",      -- Disabled
                close = "q",
                filter = "",           -- Disabled
            }
        }
    }
}

-- ============================================================================
-- EXAMPLE 6: Alternative preview keys (Space to jump, Esc to close)
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            preview = {
                jump_to_symbol = "<Space>",  -- Space to jump
                next_symbol = "<Tab>",       -- Tab for next
                prev_symbol = "<S-Tab>",     -- Shift-Tab for previous
                close = "<Esc>",             -- Esc to close
                filter = ":",                -- : for filtering
            }
        }
    }
}

-- ============================================================================
-- EXAMPLE 7: Custom global keybindings with leader key
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            sharpie_local_leader = '<leader>c',  -- Use <leader>c as prefix
            overrides = {
                show_preview = "<localleader>s",          -- <leader>cs
                hide_preview = "<localleader>h",          -- <leader>ch
                search_symbols = "<localleader>f",        -- <leader>cf
                step_to_next_symbol = "<localleader>]",   -- <leader>c]
                step_to_prev_symbol = "<localleader>[",   -- <leader>c[
            }
        }
    }
}

-- ============================================================================
-- EXAMPLE 8: Complete custom keybinding setup
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            sharpie_local_leader = ',',
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
                start_filtering = "<localleader>/",
            },
            preview = {
                jump_to_symbol = "<CR>",
                next_symbol = "j",
                prev_symbol = "k",
                close = "<Esc>",
                filter = "/",
            }
        }
    }
}

-- ============================================================================
-- EXAMPLE 9: Arrow keys for preview navigation
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            preview = {
                jump_to_symbol = "<CR>",
                next_symbol = "<Down>",    -- Down arrow for next
                prev_symbol = "<Up>",      -- Up arrow for previous
                close = "q",
                filter = "/",
            }
        }
    }
}

-- ============================================================================
-- EXAMPLE 10: IDE-like keybindings (F-keys)
-- ============================================================================
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        keybindings = {
            sharpie_local_leader = '<F12>',  -- F12 as prefix (like Go to Definition)
            overrides = {
                show_preview = "<F12>",            -- F12 to show
                search_symbols = "<localleader>f", -- F12 f to search
            },
            preview = {
                jump_to_symbol = "<CR>",
                next_symbol = "n",
                prev_symbol = "p",
                close = "<F12>",  -- F12 again to close
                filter = "/",
            }
        }
    }
}

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. Global keybindings use the `sharpie_local_leader` prefix
-- 2. Preview keybindings are buffer-local to the preview window
-- 3. Set any keybinding to "" to disable it
-- 4. Use <localleader> in override values, which gets replaced with the prefix
-- 5. Preview keybindings support all Vim key notation (<CR>, <Esc>, <Tab>, etc.)
-- 6. Check active keybindings with :map in the preview window
-- ============================================================================
