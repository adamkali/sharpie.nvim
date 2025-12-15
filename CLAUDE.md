# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

sharpie.nvim is a Neovim plugin for viewing and navigating C# class structure using LSP symbols with a TUI interface. It provides a symbol tree view, LSP integration, quick navigation, fuzzy search, and symbol highlighting capabilities.

**Important Note**: The plugin name is `sharpie.nvim` (not sharpier). The Lua module is `sharpie`. This is critical for proper loading with plugin managers like lazy.nvim.

**Lazy.nvim Support**: The plugin fully supports lazy.nvim's `opts` parameter. When `opts` is provided, lazy.nvim automatically calls `require('sharpie').setup(opts)`. This is the preferred configuration method.

## Development Commands

### Testing
```bash
make test              # Run all tests with busted
make test-watch        # Run tests in watch mode with entr
busted tests/          # Run tests directly
```

### Code Quality
```bash
make lint              # Run luacheck on lua/ directory
make format            # Format code with stylua
make clean             # Clean up generated files (luacov coverage)
```

### Manual Testing in Neovim
Since this is a Neovim plugin, manual testing requires:
1. Set up a test C# project or file
2. Ensure a C# LSP server is running (OmniSharp or csharp-ls)
3. Source the plugin: `:luafile lua/sharpie/init.lua`
4. Call functions directly: `:lua require('sharpie').show()`
5. Run health check: `:checkhealth sharpie`

### Debugging with Logs
Enable debug logging to trace execution:
```vim
:SharpieLogLevel DEBUG
:SharpieShow
:SharpieLog
```

Check logging statistics:
```vim
:SharpieLogStats
```

View logs in follow mode:
```vim
:SharpieLog tail
```

## Architecture Overview

### Core Module Structure

The plugin follows a modular architecture with clear separation of concerns:

- **`lua/sharpie/init.lua`**: Main entry point, orchestrates all functionality
  - Manages plugin state (preview buffer/window, symbols, navigation indices)
  - Coordinates between LSP, UI, and user input
  - Implements navigation (next/prev symbol, next/prev reference)
  - Sets up keybindings and autocommands

- **`lua/sharpie/config.lua`**: Configuration management
  - Defines default configuration structure
  - Deep-merges user config with defaults
  - Maps LSP symbol kinds to display icons
  - Provides config accessors

- **`lua/sharpie/lsp-integration.lua`**: LSP communication layer
  - Wraps `vim.lsp.buf_request` for document symbols, references, definitions
  - Flattens hierarchical LSP symbol trees into flat lists
  - Converts LSP symbol kind numbers to human-readable strings
  - Provides LSP readiness checks and client info

- **`lua/sharpie/utils.lua`**: Shared utilities
  - Window/buffer creation and validation
  - Symbol path formatting based on depth configuration
  - LSP <-> Vim position conversions
  - C# LSP client detection (matches "omnisharp" or "csharp")
  - Cursor positioning with configurable offsets

- **`lua/sharpie/fuzzy/`**: Fuzzy finder abstraction
  - `init.lua`: Facade that selects telescope or fzf-lua based on config
  - `telescope/init.lua`: Telescope.nvim integration
  - `fzf/init.lua`: fzf-lua integration
  - Formats symbols for picker display with icons and details

- **`lua/sharpie/hl_groups.lua`**: Syntax highlighting
  - Defines highlight groups for symbol types
  - Applies buffer-local highlighting to preview window
  - Manages symbol occurrence highlighting in source buffer

- **`lua/sharpie/queries.lua`**: Treesitter integration (fallback)
  - Checks if buffer is C# (for validation)
  - Optional treesitter support if LSP unavailable

### Data Flow

1. **Symbol Retrieval**: User invokes `show()` → LSP request via `lsp-integration.lua` → hierarchical symbols flattened → stored in plugin state
2. **Preview Rendering**: Symbols formatted with icons/indicators → buffer created → window positioned → syntax highlighting applied
3. **Navigation**: Cursor movement through symbol list → LSP range lookup → jump to main buffer → apply cursor offset
4. **Reference Navigation**: Get references at cursor position → store in state → cycle through with next/prev
5. **Search**: Symbols passed to fuzzy finder facade → appropriate picker shown → selection jumps to symbol

### State Management

Global plugin state in `init.lua:M.state`:
- `preview_bufnr/winnr`: Preview window handles
- `main_bufnr`: Source buffer being analyzed
- `symbols`: Flattened list of document symbols
- `filtered_symbols`: Symbols matching current filter query
- `filter_query`: Current filter string (empty when no filter active)
- `filtering_mode`: Boolean flag for interactive filtering mode (dired-style)
- `current_symbol_index`: Navigation position in symbol list
- `current_references/current_reference_index`: Reference navigation state
- `highlight_enabled`: Toggle state for highlighting

### Auto-Reload Behavior

The plugin automatically refreshes the preview window in the following scenarios:

1. **Buffer Content Changes** (if `display.auto_reload` is enabled):
   - Triggers on `TextChanged` and `TextChangedI` events for `*.cs` files
   - Uses debounced refresh (configurable via `display.auto_reload_debounce`, default 500ms)
   - Cancels pending debounced refresh and refreshes immediately on `BufWritePost` (save)
   - Only refreshes if preview window is currently open and valid
   - Re-applies active filter after refresh

2. **Buffer Switching**:
   - Triggers on `BufEnter` for `*.cs` files
   - Refreshes immediately when switching to a different C# buffer
   - Updates `main_bufnr` to track the new buffer
   - Clears any active filter when switching buffers
   - Only triggers if preview window is already open

Implementation in `init.lua:refresh_preview_if_open()`:
- Validates preview window is open and valid
- Re-fetches symbols from LSP for the buffer
- Re-renders preview with updated symbols
- Preserves or clears filter state as appropriate

### Two-Mode Preview System

The preview window operates in two distinct modes with clean state transitions:

**Navigate Mode** (default):
- Browse symbol tree with full navigation
- Visual state: Either clean symbol list or "Filter: X (Y/Z matches)" header
- Keybindings: n/p navigate, Enter jumps, / enters Filter Mode, q closes, Esc clears filter
- State: `filtering_mode = false`

**Filter Mode** (interactive):
- Build filter query by typing directly in preview (dired-style)
- Visual state: Input line at top: `> query`
- Keybindings: Characters input, n/p navigate filtered results, Enter/q/Esc exit to Navigate Mode
- State: `filtering_mode = true`

**Symbol Search Modes** (separate from preview modes):
1. **Fuzzy Finder Mode**: When preview is closed, uses telescope/fzf for symbol search
2. **Interactive Filter Mode**: When preview is open, uses dired-style inline filtering

**Mode Transitions:**

```
┌─────────────────┐         Press '/'         ┌─────────────────┐
│  Navigate Mode  │ ───────────────────────> │   Filter Mode   │
│                 │                           │                 │
│ - Browse tree   │ <─────────────────────── │ - Type query    │
│ - Jump symbols  │   Enter / q / Esc        │ - Live filter   │
│ - Clear filter  │                           │ - Navigate      │
└─────────────────┘                           └─────────────────┘
   filtering_mode = false                        filtering_mode = true
```

**Filter Mode Workflow** (`init.lua`):
- User presses `/` (configurable) → `start_filtering()` → `enter_filtering_mode()`
- `filtering_mode` state flag set to `true`
- Preview re-renders with input line at top: `<prompt><query>`
- Keymaps intelligently configured:
  - Navigation keys (n/p) remain mapped to `step_to_next_symbol()` / `step_to_prev_symbol()`
  - All other printable characters mapped to `filter_add_char(char)`
  - Jump key (<CR> by default) exits filtering mode then jumps to symbol
- Each character triggers: update query → `filter_symbols()` → re-render → update cursor
- Navigation works on filtered list while in filtering mode
- Special keys:
  - `n` / `p`: Navigate through filtered symbols (works during filtering)
  - `<Backspace>`: `filter_backspace()` removes last character
  - `<Enter>`: `exit_filtering_mode()` accepts filter (keeps filter active, exits input mode)
  - `<Esc>`: Clears query and exits filtering mode
  - `q`: Exits filtering mode (keeps current filter)

**Implementation Details**:
- `setup_filtering_keymaps()`: Creates temporary buffer-local keymaps
  - Excludes configured navigation keys (n/p by default) from character input
  - Dynamically builds excluded list based on user's preview keybindings
- Cursor automatically positioned at end of input line (after prompt)
- Filter is case-insensitive substring match
- Results update incrementally as you type (no debouncing needed - fast enough)
- On exit, restores normal preview keymaps via `setup_preview_keymaps()`
- Navigation during filtering uses the filtered symbol list

**Symbol Jumping** (`jump_to_symbol()`):
- Prefers `selectionRange` over `range` for more accurate cursor placement
- `selectionRange` points to the symbol name itself
- `range` includes the entire declaration (attributes, modifiers, etc.)
- Using `selectionRange` ensures cursor lands on the actual symbol, not attributes above it

**Display Logic** (`render_preview()`):
- If `filtering_mode == true`: Show input line with prompt (configurable, default `"> "`)
- Else if `filter_query != ""`: Show filter status line with match count
- Else: Show all symbols normally

**Configuration**:
- `display.filter_prompt`: Customize the prompt icon/text (default: `"> "`)

### Symbol Path Formatting

The `symbol_options.path` setting controls display depth:
- `0`: Symbol name only - `Main(string[] args)`
- `1`: Class.Symbol - `Program.Main(string[] args)`
- `2`: Namespace.Class.Symbol - `MyNamespace.Program.Main(string[] args)` (default)
- `3`: Full path - all namespace components

Implementation in `utils.format_symbol_path()` splits on `.` and slices based on depth.

### LSP Symbol Flattening

`lsp-integration.flatten_symbols()` converts hierarchical LSP DocumentSymbol trees into flat lists:
- Recursively traverses children
- Builds dotted full names (`parent.child.grandchild`)
- Preserves both `full_name` and `simple_name`
- Maintains range information for jumping

### Window Layout Strategies

`utils.calculate_window_config()` supports multiple display styles:
- **Splits**: `left/right/top/bottom` - Uses vim split commands
- **Float**: Centered floating window with configurable offsets
- Offsets can be absolute or percentage-based (0.0-1.0)

## Testing Strategy

Uses busted for unit testing. Test structure:
- `describe()` blocks for logical grouping
- `before_each()` to clear package cache for isolated tests
- Focus on testing config merging, icon mapping, validation

To add new tests:
1. Create `tests/<module>_spec.lua`
2. Clear `package.loaded` in `before_each` for isolation
3. Use assertions: `assert.equals()`, `assert.is_not_nil()`, etc.
4. Run with `make test`

## Key Implementation Details

### Keybinding System

Default keybindings use a configurable local leader prefix (default `+`):
- Template bindings use `<localleader>` placeholder
- `setup_keybindings()` replaces placeholder with actual prefix
- Can disable defaults via `keybindings.disable_default_keybindings`
- Preview buffer has separate buffer-local keymaps

### LSP Client Detection

The plugin specifically looks for C# LSP servers:
```lua
client.name:match("omnisharp") or client.name:match("csharp")
```
This matches both OmniSharp and csharp-ls server names.

### Symbol Indicators

`utils.get_symbol_indicators()` parses `symbol.detail` strings to add visual indicators:
- `async` keyword → `` (async indicator)
- `static` keyword → `` (static indicator)
- Generic types `<...>` → `<>` indicator

These appear in preview as `( <> )` prefix before symbol name.

### Autocommands

Single autogroup `SharpieNvim` handles multiple events:
- **BufWipeout**: Clears state variables when preview buffer is deleted
- **BufEnter** (*.cs): Refreshes preview when switching to different C# file
- **TextChanged/TextChangedI** (*.cs): Debounced preview refresh during editing (if `display.auto_reload` enabled)
- **BufWritePost** (*.cs): Immediate preview refresh on file save (if auto-reload enabled)

All autocommands check if preview window is valid before acting to prevent errors.

## Common Development Patterns

### Adding New LSP Requests

1. Add function to `lsp-integration.lua` following existing pattern:
   - Check LSP client availability with `utils.has_lsp_client()`
   - Build params using `vim.lsp.util` helpers
   - Use `vim.lsp.buf_request()` with callback
   - Process results and invoke callback

2. Call from `init.lua` coordinating with state management

### Adding Configuration Options

1. Add to `config.defaults` with sensible default
2. Access via `config.get().<your_option>`
3. Document in README.md configuration section
4. Add test in `tests/config_spec.lua`

### Extending Fuzzy Finder Support

1. Create `lua/sharpie/fuzzy/<finder>/init.lua`
2. Implement interface: `search_symbols()`, `show_picker()`, `show_references()`
3. Update `fuzzy/init.lua` to detect and load new finder
4. Add fallback logic for when finder unavailable

## Logging System

### Architecture

The logging system (`lua/sharpie/logger.lua`) provides:
- **Multiple log levels**: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
- **Structured logging**: Context data attached to log messages
- **File rotation**: Automatic rotation when log exceeds max size
- **Performance tracking**: Built-in duration measurement
- **Statistics**: Track log counts by level and last error
- **Multiple formats**: Default human-readable or JSON

### Integration Points

Logging is integrated throughout the codebase:
- **config.lua**: Logs configuration loading and changes
- **lsp-integration.lua**: Logs all LSP requests/responses with timing
- **init.lua**: Logs plugin lifecycle events, symbol operations, navigation

### Usage Patterns

```lua
local logger = require('sharpie.logger')

-- Basic logging
logger.info("module_name", "Something happened")
logger.error("module_name", "Error occurred", { details = "..." })

-- Performance tracking
logger.measure("module_name", "operation_name", function()
    -- expensive operation
end)

-- State changes
logger.log_state_change("module", "state_name", old_val, new_val)

-- LSP operations (specialized)
logger.log_lsp_request("textDocument/documentSymbol", params)
logger.log_lsp_response("textDocument/documentSymbol", true, result)
```

### Configuration

Logger is configured via `config.logging` section:
- `enabled`: Master switch for logging
- `level`: Minimum level to log (numeric constant from `logger.levels`)
- `file`: Path to log file (default: `$XDG_DATA_HOME/sharpie.log`)
- `max_file_size`: Rotation threshold in bytes
- `include_timestamp`: Prepend ISO8601 timestamp
- `include_location`: Add file:line caller information
- `console_output`: Also send logs to `vim.notify`
- `format`: "default" (human-readable) or "json"

### User Commands

Exposed via `plugin/sharpie.lua`:
- `:SharpieLog [tail]`: View log file (optionally in follow mode)
- `:SharpieLogClear`: Truncate log file
- `:SharpieLogStats`: Display statistics in floating window
- `:SharpieLogLevel [LEVEL]`: Get/set current log level

## Health Check System

The health check (`lua/health/sharpie.lua`) validates:
1. Neovim version compatibility
2. Active LSP clients and C# language server
3. LSP server capabilities
4. Treesitter availability and C# parser
5. Fuzzy finder installation
6. Configuration validity
7. Logging directory permissions

Run with `:checkhealth sharpie`

The health check uses `vim.health` API:
- `vim.health.ok()`: Green checkmark
- `vim.health.warn()`: Yellow warning with suggestions
- `vim.health.error()`: Red error with remediation steps
- `vim.health.info()`: Informational message
