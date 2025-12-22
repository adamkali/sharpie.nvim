# sharpie.nvim

A Neovim plugin for viewing and navigating C# and Go code structure using LSP symbols with a TUI interface.

## Features

- **Multi-Language Support**: Works with both C# and Go files with automatic language detection
- **Symbol Tree View**: Display namespaces, classes, methods, properties, functions, structs, interfaces, and more in a structured preview window
- **Namespace-Wide View**: Toggle between file-only and namespace-wide symbol viewing to see all symbols across an entire namespace/package
- **LSP Integration**:
  - C#: OmniSharp or csharp-ls
  - Go: gopls
- **Language-Specific Features**:
  - **C#**: Async/await indicators, Task<T> return types, access modifiers
  - **Go**: Method receivers, channel directions, exported/unexported symbols, goroutine detection, error returns
- **Quick Navigation**: Jump to symbol definitions and navigate through references (works across files in namespace mode)
- **Fuzzy Search**: Search symbols using Telescope or FZF
- **Symbol Highlighting**: Highlight all occurrences of a symbol in the buffer
- **Quickfix Integration**: Add symbol references to the quickfix list
- **Customizable Display**: Configure window style, icons, symbol path depth, and file separator styles

## Requirements

- Neovim >= 0.8.0
- At least one LSP server:
  - **C#**: OmniSharp or csharp-ls
  - **Go**: gopls
- Optional: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or [fzf-lua](https://github.com/ibhagwan/fzf-lua) for fuzzy finding
- Optional: [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with C# (`c_sharp`) or Go (`go`) parser (fallback)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

**Important:** The plugin name is `sharpie.nvim` (not sharpier). The plugin fully supports lazy.nvim's `opts` parameter.

#### Option 1: Using `opts` (Recommended - lazy.nvim style)
```lua
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp', 'go' },  -- Lazy load on C# and Go files
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        fuzzy_finder = "telescope",
        display = {
            style = "bottom",
            height = 20,
        },
        logging = {
            enabled = true,
            level = "INFO",
        },
    },
}
```

#### Option 2: Using `opts` with defaults
```lua
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp', 'go' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {},  -- Use all defaults
}
```

#### Option 3: Using `config` function (for custom setup)
```lua
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp', 'go' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
        require('sharpie').setup({
            fuzzy_finder = "telescope",
            display = { style = "bottom", height = 20 },
            -- Language-specific features
            language = {
                go = {
                    show_receiver_types = true,
                    show_channel_direction = true,
                },
            },
        })

        -- Add custom keybindings or additional setup
        vim.keymap.set('n', '<leader>cs', '<cmd>SharpieShow<cr>', { desc = 'Show symbols' })
    end,
}
```

#### Option 4: Lazy load with LSP event
```lua
{
    'yourusername/sharpie.nvim',
    event = 'LspAttach',  -- Load when LSP attaches
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        display = { style = "bottom" },
    },
}
```

#### Option 5: Lazy load with commands
```lua
{
    'yourusername/sharpie.nvim',
    cmd = { 'SharpieShow', 'SharpieHide', 'SharpieSearch' },
    ft = { 'cs', 'csharp', 'go' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        logging = { level = "DEBUG" },
    },
}
```

#### Option 6: Using fzf-lua instead of telescope
```lua
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'ibhagwan/fzf-lua' },
    opts = {
        fuzzy_finder = "fzf",
    },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
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
        auto_reload = true, -- Automatically reload preview when buffer changes
        auto_reload_debounce = 500, -- Debounce time in ms for auto-reload
        filter_prompt = "> ", -- Prompt shown when in interactive filtering mode
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
            task = "⏳",  -- Hourglass for Task/async methods
        }
    },

    -- Symbol display options
    symbol_options = {
        namespace = true, -- Enable namespace-wide view (when toggled)
        path = 2, -- 0-3, controls symbol path depth
        workspace_symbols = true, -- Required for namespace mode
        show_file_location = true, -- Show file path for symbols from other files
        namespace_mode_separator_style = "line", -- "line" | "box" | "bold"
    },

    -- Keybinding settings
    keybindings = {
        sharpie_local_leader = '+',
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
            jump_to_symbol = "<CR>",   -- Jump to symbol under cursor
            next_symbol = "n",         -- Navigate to next symbol
            prev_symbol = "p",         -- Navigate to previous symbol
            close = "q",               -- Close preview window
            filter = "/",              -- Start filtering/searching
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

-- Toggle between file-only and namespace-wide view
require('sharpie').toggle_namespace_mode()

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

- `+s` - Show the preview window
- `+h` - Hide the preview window
- `+n` - Step to the next symbol
- `+p` - Step to the previous symbol
- `+N` - Step to the next reference
- `+P` - Step to the previous reference
- `+H` - Toggle highlighting
- `+t` - Toggle namespace mode (file-only ↔ namespace-wide)
- `+s.` - Start filtering symbols
- `+f` - Search for symbols

### Preview Window Keybindings

When focused on the preview window (fully configurable via `keybindings.preview`):

- `<CR>` - Jump to symbol under cursor
- `n` - Next symbol
- `p` - Previous symbol
- `q` - Close preview window
- `/` - Start filtering symbols (live filtering in preview)
- `<Esc>` - Clear filter and show all symbols

**Two-Mode System:**

The preview window operates in two distinct modes:

### Navigate Mode (Default)
Browse and explore symbols with full navigation:
- `n` / `p`: Navigate to next/previous symbol
- `<CR>`: Jump to symbol under cursor
- `/`: Enter Filter Mode
- `q`: Close preview window
- `<Esc>`: Clear any active filter (if present)

**Visual indicator:**
- No filter: Clean symbol list
- Filter active: `Filter: query (X/Y matches)` at top

### Filter Mode (Interactive)
Build a filter query by typing directly in the preview (dired-style):
- Type any character: Add to filter query
- `n` / `p`: Navigate through filtered results (while typing!)
- `<Backspace>`: Remove last character
- `<Enter>`: Exit to Navigate Mode (keeps filter)
- `<Esc>`: Clear filter and exit to Navigate Mode
- `q`: Exit to Navigate Mode (keeps filter)

**Visual indicator:** Input line with prompt at top: `> query`

### Mode Transitions

```
Navigate Mode ──[/]──> Filter Mode ──[Enter/q/Esc]──> Navigate Mode
     ↑                                                      |
     └──────────────────────────────────────────────────────┘
```

**Customize Filter Prompt:**

```lua
require('sharpie').setup({
    display = {
        filter_prompt = "🔍 ",  -- Use any icon or text
    }
})
```

**Example Workflow:**

**1. Navigate Mode** (browsing all symbols):
```
──────────────────────────────
  Program
  User
  UserService
  GetUser(int id)
  GetUserAsync(int id)          ← Press '/' to enter Filter Mode
  UpdateUser()
  DeleteUser()
```

**2. Filter Mode** (type "Get"):
```
> Get                           ← FILTER MODE - typing query
──────────────────────────────
  GetUser(int id)              ← Press 'n' to navigate while typing
→ GetUserAsync(int id)
```

**3. Navigate Mode** (after pressing Enter):
```
Filter: Get (2/50 matches)      ← NAVIGATE MODE - filter applied
──────────────────────────────
→ GetUser(int id)               ← Press 'n'/'p' to navigate
  GetUserAsync(int id)          ← Press Enter to jump to symbol
```

**4. Back to Navigate Mode** (press Esc to clear filter):
```
──────────────────────────────  ← NAVIGATE MODE - all symbols
  Program
  User
→ UserService                   ← Back to browsing full tree
  GetUser(int id)
  GetUserAsync(int id)
```

**Customizing Preview Keybindings:**

```lua
require('sharpie').setup({
    keybindings = {
        preview = {
            jump_to_symbol = "<CR>",   -- Change to any key
            next_symbol = "j",         -- Use j instead of n
            prev_symbol = "k",         -- Use k instead of p
            close = "<Esc>",           -- Use Esc instead of q
            filter = "?",              -- Use ? instead of /
            clear_filter = "c",        -- Use c to clear filter
        }
    }
})
```

To disable a preview keybinding, set it to an empty string:

```lua
preview = {
    filter = "",  -- Disable the filter keybinding
}
```

### Auto-Reload Preview Window

The preview window automatically reloads in two scenarios:

1. **Buffer Content Changes**: When you edit the current C# file (add/remove methods, etc.), the preview updates automatically after a short debounce period (default 500ms). This is triggered immediately when you save the file.

2. **Buffer Switching**: When you switch to a different C# file (e.g., via `:bnext`, `:bprev`, or opening a new file), the preview window automatically shows the symbols for the new file.

**Configuration**:

```lua
require('sharpie').setup({
    display = {
        auto_reload = true,  -- Enable/disable auto-reload (default: true)
        auto_reload_debounce = 500,  -- Debounce time in ms (default: 500)
    }
})
```

**Disable auto-reload**:

```lua
require('sharpie').setup({
    display = {
        auto_reload = false,  -- Disable auto-reload
    }
})
```

**Adjust debounce time** (for faster/slower updates during editing):

```lua
require('sharpie').setup({
    display = {
        auto_reload_debounce = 1000,  -- Wait 1 second after typing stops
    }
})
```

**Behavior Details**:
- When you edit a file, the preview waits `auto_reload_debounce` milliseconds after your last change before refreshing (to avoid constant updates while typing)
- When you save a file (`:w`), the preview refreshes immediately
- When you switch to a different C# file, the preview refreshes immediately and any active filter is cleared
- Auto-reload only works when the preview window is already open - it won't open the preview automatically

### Namespace-Wide Symbol View

sharpie.nvim supports two viewing modes that you can toggle between:

#### File-Only Mode (Default)
Shows symbols only from the current file, just like traditional symbol viewers.

#### Namespace-Wide Mode
Shows all symbols from the current file's namespace/package across all files in your workspace. This is perfect for exploring large namespaces or packages without switching between files.

**How it works:**

1. **Auto-detection**: Automatically detects the namespace from your current file
   - **C#**: Supports both file-scoped (`namespace MyApp.Services;`) and block-scoped (`namespace MyApp.Services { }`) namespaces
   - **Go**: Detects package name (`package mypackage`)

2. **Workspace Symbols**: Queries your LSP server for all symbols in the detected namespace

3. **File Grouping**: Groups symbols by file with visual separators:
   ```
   Namespace: MyApp.Services (42 symbols across 5 files)
   ══════════════════════════════════════════════════════════

   ─── src/Services/UserService.cs (8 symbols) ───
     󰊕  UserService
     󰊕  GetUser(int id)
     󰊕  CreateUser(User user)

   ─── src/Services/EmailService.cs (6 symbols) ───
     󰊕  EmailService
     󰊕  SendEmail(string to, string subject)
   ```

4. **Seamless Navigation**: Navigate with `n`/`p` (automatically skips file headers) and jump with `<CR>` to symbols in any file

**Toggle between modes:**
- Press `+t` (or run `:SharpieToggleNamespaceMode`)
- The preview window updates immediately with symbols from the current mode
- Mode persists until you toggle again

**Configuration:**

```lua
require('sharpie').setup({
    symbol_options = {
        namespace = true,  -- Enable namespace mode capability
        workspace_symbols = true,  -- Required for namespace mode
        namespace_mode_separator_style = "line",  -- "line" | "box" | "bold"
    }
})
```

**Separator Styles:**

```lua
-- Line style (default)
─── src/Services/UserService.cs (8 symbols) ───

-- Box style
┌─── src/Services/UserService.cs (8 symbols)

-- Bold style
▶ src/Services/UserService.cs (8 symbols)
```

**Features in Namespace Mode:**
- ✅ Auto-reload when editing files
- ✅ Interactive filtering with `/`
- ✅ Cross-file navigation
- ✅ Relative file paths for cleaner display
- ✅ Symbol count per file

**Limitations:**
- Requires LSP server with workspace symbol support (OmniSharp, csharp-ls, and gopls all support this)
- Query performance depends on workspace size and LSP server
- For Go, packages spanning multiple directories are shown separately per directory

## Example Workflow

**Understanding the Modes:**

sharpie.nvim has two independent mode systems:

1. **View Modes** (File-Only vs Namespace-Wide)
2. **Preview Modes** (Navigate vs Filter)

### View Modes Workflow

1. **File-Only Mode** (Default)
   - Press `+s` to show symbols from the current file
   - Navigate with `n`/`p` through all symbols
   - Press `<CR>` to jump to any symbol

2. **Switch to Namespace-Wide Mode**
   - Press `+t` to toggle namespace mode
   - View updates to show all symbols from the current namespace across all files
   - File headers separate symbols by file

3. **Navigate Across Files**
   - Use `n`/`p` to browse symbols (automatically skips file headers)
   - Press `<CR>` to jump to a symbol in any file
   - Press `+t` again to return to file-only mode

### Preview Modes Workflow

1. **Navigate Mode** (Default)
   - Browse symbols with `n`/`p`
   - Press `<CR>` to jump to any symbol

2. **Filter Symbols** (Enter Filter Mode)
   - Press `/` to enter Filter Mode
   - Type directly in the preview: "Get"
   - Navigate filtered results with `n`/`p` while typing
   - Press `<Enter>` to return to Navigate Mode (filter stays active)

3. **Navigate Filtered Results** (Navigate Mode with filter)
   - Use `n`/`p` to browse only matching symbols
   - Press `<CR>` to jump to a filtered symbol
   - Press `<Esc>` to clear filter and see all symbols again

### Complete Workflow Example

1. Open a C# file and press `+s` to show symbols (file-only mode)
2. Press `+t` to switch to namespace-wide view
3. Press `/` and type "User" to filter symbols containing "User"
4. Navigate filtered results with `n`/`p` across all files in the namespace
5. Press `<CR>` to jump to a symbol in another file
6. Edit your code - preview automatically refreshes
7. Press `+H` to highlight all occurrences of the symbol under cursor
8. Use `+N`/`+P` to cycle through references

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
   ⏳ (  ) MyNamespace.MyClass.MyAsyncMethod()      # Task return type
   ⏳ (  <> ) MyNamespace.MyClass.MyAsyncMethod2()   # Task<T> return type
```

**Smart Icon Detection:**
- Methods returning `Task` (no generic) get the hourglass icon (⏳)
- Methods returning `Task<T>` show the icon for type `T`:
  - `Task<int>` →  (integer icon)
  - `Task<string>` → 󰀬 (string icon)
  - `Task<bool>` →  (boolean icon)
  - `Task<User>` →  (class icon)
  - `Task<List<T>>` → 󰅪 (array icon)
- Classes, structs, and interfaces get the class icon ()
- Async methods are detected and marked appropriately

## Health Check

Run `:checkhealth sharpie` to verify:

- Neovim version compatibility (>= 0.8.0)
- LSP is active and configured
- C# LSP client is available (OmniSharp or csharp-ls)
- LSP server capabilities (symbols, references, definitions)
- Current buffer filetype
- Treesitter is available (optional)
- C# treesitter parser installed (optional)
- Configured fuzzy finder is installed
- Plugin configuration validity
- Logging setup and log directory

## Logging and Debugging

sharpie.nvim includes a comprehensive logging system for troubleshooting and debugging.

### Configuration

```lua
require('sharpie').setup({
    logging = {
        enabled = true,              -- Enable/disable logging
        level = "INFO",              -- TRACE, DEBUG, INFO, WARN, ERROR, FATAL
        file = vim.fn.stdpath('data') .. '/sharpie.log',
        max_file_size = 10 * 1024 * 1024,  -- 10MB, auto-rotates
        include_timestamp = true,    -- Include timestamps in logs
        include_location = true,     -- Include file:line in logs
        console_output = false,      -- Also output to vim.notify
        format = "default",          -- "default" or "json"
    }
})
```

### Log Commands

- `:SharpieLog` - View log file in a split window
- `:SharpieLog tail` - View log file in follow mode (auto-updates)
- `:SharpieLogClear` - Clear the log file
- `:SharpieLogStats` - Show logging statistics in a floating window
- `:SharpieLogLevel [LEVEL]` - Get or set the log level

### Log Levels

- **TRACE**: Detailed execution flow (function entry/exit)
- **DEBUG**: Detailed debugging information (LSP requests/responses)
- **INFO**: General informational messages (default)
- **WARN**: Warning messages for potential issues
- **ERROR**: Error messages for failures
- **FATAL**: Critical errors

### Example: Debugging LSP Issues

```vim
" Enable debug logging
:SharpieLogLevel DEBUG

" Try to show symbols
:SharpieShow

" View the log to see detailed LSP communication
:SharpieLog

" Check statistics
:SharpieLogStats
```

## User Commands

In addition to the API functions, sharpie.nvim provides user commands:

- `:SharpieShow` - Show the preview window
- `:SharpieHide` - Hide the preview window
- `:SharpieSearch` - Search symbols with fuzzy finder
- `:SharpieToggleHighlight` - Toggle symbol highlighting
- `:SharpieToggleNamespaceMode` - Toggle between file-only and namespace-wide view
- `:SharpieNextSymbol` - Jump to next symbol
- `:SharpiePrevSymbol` - Jump to previous symbol
- `:SharpieNextReference` - Jump to next reference
- `:SharpiePrevReference` - Jump to previous reference
- `:SharpieFilterClear` - Clear symbol filter in preview

## Troubleshooting

### "Lua module not found" error with lazy.nvim

If you see an error like `Lua module not found for config of sharpier.nvim`, ensure:

1. **Correct plugin name**: It's `sharpie.nvim` not `sharpier.nvim`
2. **Using `dir` with different directory name**: If your directory is named differently than the module, explicitly set the `name`:
   ```lua
   {
       dir = '/path/to/sharpier.nvim',  -- Directory name is sharpier.nvim
       name = 'sharpie.nvim',           -- But module name is sharpie
       ft = { 'cs', 'csharp' },
       dependencies = { 'nvim-telescope/telescope.nvim' },
       opts = {},
   }
   ```
3. **Use a `config` function**: Instead of a string, use:
   ```lua
   config = function()
       require('sharpie').setup()
   end
   ```
4. **Check the module name**: The Lua module is `sharpie` (without `.nvim`)

### LSP not working

1. Check that a C# LSP server is installed and running:
   ```vim
   :LspInfo
   ```
2. Run the health check:
   ```vim
   :checkhealth sharpie
   ```
3. Enable debug logging:
   ```vim
   :SharpieLogLevel DEBUG
   :SharpieShow
   :SharpieLog
   ```

### No symbols found

1. Ensure you're in a C# file (`.cs` extension)
2. Check that LSP is attached to the buffer
3. Verify the LSP server supports `textDocument/documentSymbol`:
   ```vim
   :checkhealth sharpie
   ```

### Performance issues

Check log file for slow operations:
```vim
:SharpieLog
```

Look for lines with high `duration_ms` values. Consider:
- Reducing `symbol_options.path` depth
- Disabling logging in production: `logging.enabled = false`

## Examples

See the `examples/` directory for complete configuration examples:
- `examples/lazy.lua` - lazy.nvim configuration with all options
- `examples/packer.lua` - packer.nvim configuration

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Inspired by the dired interface in Emacs and various LSP symbol viewers.
