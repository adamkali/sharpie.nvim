# sharpie.nvim Quick Start Guide

## Installation (lazy.nvim)

Add to your lazy.nvim plugin spec. Use `opts` for the lazy.nvim preferred style:

### Using `opts` (Recommended)
```lua
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    opts = {
        -- your configuration here, or {} for defaults
    },
}
```

### Using `config` function
```lua
{
    'yourusername/sharpie.nvim',
    ft = { 'cs', 'csharp' },
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
        require('sharpie').setup({
            -- your configuration here
        })
    end,
}
```

## First Steps

1. **Check setup**:
   ```vim
   :checkhealth sharpie
   ```

2. **Open a C# file** with an LSP server running

3. **Show symbols**:
   ```vim
   :SharpieShow
   ```
   Or use default keybinding: `+ss`

## Essential Commands

| Command | Description | Default Key |
|---------|-------------|-------------|
| `:SharpieShow` | Show symbol preview | `+ss` |
| `:SharpieHide` | Hide preview | `+sh` |
| `:SharpieSearch` | Fuzzy search symbols | `+sf` |
| `<CR>` (in preview) | Jump to symbol | - |
| `n` / `p` (in preview) | Next/Previous symbol | - |
| `q` (in preview) | Close preview | - |

## Debugging

If something isn't working:

```vim
" Enable debug logging
:SharpieLogLevel DEBUG

" Try the operation
:SharpieShow

" View logs
:SharpieLog

" Check statistics
:SharpieLogStats
```

## Common Issues

### "Module not found" error
- Plugin name is `sharpie.nvim` not `sharpier.nvim`
- Module name is `sharpie` (without .nvim)
- Use `config = function() require('sharpie').setup() end`

### No symbols showing
1. Check LSP: `:LspInfo`
2. Verify C# file: Must be `.cs` extension
3. Run health check: `:checkhealth sharpie`

### Preview not appearing
1. Check display style in config
2. Look at logs: `:SharpieLog`
3. Try different style: `display.style = "float"`

## Next Steps

- Read [README.md](README.md) for full configuration options
- Check [examples/lazy.lua](examples/lazy.lua) for advanced setup
- See [CLAUDE.md](CLAUDE.md) for architecture details
