# sharpie.nvim

A Neovim plugin for viewing and navigating C# class structure using LSP symbols with a TUI interface.

## Features

- **Symbol Tree View**: Display namespaces, classes, methods, properties, and more in a structured preview window
- **LSP Integration**: Uses C# language server (OmniSharp, csharp-ls) for accurate symbol information
- **Quick Navigation**: Jump to symbol definitions and navigate through references
- **Fuzzy Search**: Search symbols using Telescope or FZF
- **Symbol Highlighting**: Highlight all occurrences of a symbol in the buffer
- **Quickfix Integration**: Add symbol references to the quickfix list
- **Customizable Display**: Configure window style, icons, and symbol path depth

## Requirements

- Neovim >= 0.8.0
- C# LSP server (OmniSharp or csharp-ls)
- Optional: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or [fzf-lua](https://github.com/ibhagwan/fzf-lua) for fuzzy finding
- Optional: [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with C# parser (fallback)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'yourusername/sharpie.nvim',
    dependencies = {
        'nvim-telescope/telescope.nvim', -- or 'ibhagwan/fzf-lua'
    },
    config = function()
        require('sharpie').setup({
            -- your configuration here
        })
    end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'yourusername/sharpie.nvim',
    requires = {
        'nvim-telescope/telescope.nvim', -- or 'ibhagwan/fzf-lua'
    },
    config = function()
        require('sharpie').setup()
    end
}
```

## Configuration

### Default Configuration

```lua
require('sharpie').setup({
    -- Fuzzy finder to use: "telescope" or "fzf"
    fuzzy_finder = "telescope",

    -- Display settings for the preview window
    display = {
        style = "bottom", -- left|right|top|bottom|float
        width = 60,
        height = 20,
        y_offset = 1,
        x_offset = 1,
    },

    -- Cursor positioning after jump (nil = center like 'zz')
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
        namespace = true, -- show all classes in namespace
        path = 2, -- 0-3, controls symbol path depth
    },

    -- Keybinding settings
    keybindings = {
        sharpie_local_leader = '+',
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
})
```

## Usage

### API Functions

```lua
-- Show preview window with symbols
require('sharpie').show(bufnr)

-- Hide preview window
require('sharpie').hide(bufnr)

-- Navigate symbols
require('sharpie').step_to_next_symbol(bufnr)
require('sharpie').step_to_prev_symbol(bufnr)

-- Navigate references
require('sharpie').step_to_next_reference(bufnr)
require('sharpie').step_to_prev_reference(bufnr)

-- Search symbols with fuzzy finder
require('sharpie').search_symbols(query, bufnr)

-- Go to reference/definition
require('sharpie').search_go_to_reference(symbol_id, bufnr)
require('sharpie').search_go_to_definition(symbol_id, bufnr)

-- Highlight symbol occurrences
-- on: true/false/nil (nil = toggle), hl_group can be custom, bg/fg can be #RRGGBB or HL group name
require('sharpie').highlight_symbol_occurrences(symbol_id, hl_group, bufnr, bg, fg, on)

-- Add occurrences to quickfix list
require('sharpie').add_occurences_to_qflist(symbol_id, bufnr)

-- Run health check
require('sharpie').checkhealth()
```

### Default Keybindings

With default configuration (using `+` as local leader prefix):

- `+ss` - Show the preview window
- `+sh` - Hide the preview window
- `+sn` - Step to the next symbol
- `+sp` - Step to the previous symbol
- `+sN` - Step to the next reference
- `+sP` - Step to the previous reference
- `+sH` - Toggle highlighting
- `+s.` - Start filtering symbols
- `+sf` - Search for symbols

### Preview Window Keybindings

When focused on the preview window:

- `<CR>` - Jump to symbol under cursor
- `n` - Next symbol
- `p` - Previous symbol
- `q` - Close preview window
- `/` - Start filtering/searching

## Example Workflow

1. Open a C# file
2. Press `+ss` to show the symbol tree
3. Navigate through symbols with `n`/`p` or press `<CR>` to jump
4. Press `/` to fuzzy search symbols
5. Press `+sH` to highlight all occurrences of the symbol under cursor
6. Use `+sN`/`+sP` to cycle through references

## Symbol Path Depth

The `symbol_options.path` setting controls how much of the symbol path is displayed:

- `0`: Just the symbol name - `Main(string[] args)`
- `1`: Class.Symbol - `Program.Main(string[] args)`
- `2`: Namespace.Class.Symbol - `MyNamespace.Program.Main(string[] args)` (default)
- `3`: Full path - `FullNamespace.Leading.To.MyNamespace.Program.Main(string[] args)`

## Display Example

```
 MyNamespace
    MyNamespace.Program
    ( 󰟢 ) MyNamespace.Program.Main(string[] args)
    MyNamespace.MyClass
    (  ) MyNamespace.MyClass.MyProperty
    (  ) MyNamespace.MyClass.MyStaticInt()
    (  ) MyNamespace.MyClass.MyAsyncMethod()
    (  <> ) MyNamespace.MyClass.MyAsyncMethod2()
```

## Health Check

Run `:checkhealth sharpie` to verify:

- LSP is active
- C# LSP client is available
- Treesitter is available (optional)
- Configured fuzzy finder is installed

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Inspired by the dired interface in Emacs and various LSP symbol viewers.
