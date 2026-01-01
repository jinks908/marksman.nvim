# Marksman for Neovim

![marksman_header_2](https://github.com/user-attachments/assets/57625e07-2284-4155-b5bb-edd252e5f2cd)

## What is Marksman?

**Marksman** is a Neovim plugin that enhances the native Vim mark system with visual feedback and modern UI. The flagship feature is **Night Vision** - a real-time visual highlighting system that shows you exactly where your marks are placed in the buffer.

## Core Problem Solved

Vim marks are powerful but invisible. You set them with `ma`, `mb`, etc., but then you forget where they are and which letters are for what. Marksman solves this by:
- Highlighting marked lines in real-time
- Showing indicators in the gutter
- Adding virtual text icons as visual anchors
- Providing a Telescope picker to browse marks
- Remembering when marks were created (timestamps)

## Key Features at a Glance

| Feature | Purpose | Highlight |
|---------|---------|-----------|
| **Manual Marks** | Set marks with `ma`, `mb`, etc. (a-z) | Native Vim integration |
| **Auto-mark** | Automatically assign next free letter | Smart: finds a-z gaps |
| **Night Vision** | Visual highlighting of marked lines | Smart icon toggling |
| **Mark Navigation** | Jump forward/backward between marks | Wraparound at edges |
| **Telescope Picker** | Browse and jump to marks | Fast letter hotkeys |
| **Timestamps** | Track when marks were created | Sort by recency |
| **Smart Deletion** | Delete single marks or all marks | Preserves visual state |
| **Per-Buffer State** | Independent Night Vision per buffer | Multi-window friendly |

## Installation

### Using Lazy.nvim
```lua
{
    "jinks908/marksman.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        require('marksman').setup()
    end
}
```

### Using Packer
```lua
use {
    'jinks908/marksman.nvim',
    requires = 'nvim-telescope/telescope.nvim'
}
```

### Using Vim-Plug
```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'jinks908/marksman.nvim'
```

## Basic Setup

```lua
require('marksman').setup({
    night_vision = {
        enabled = true,              -- Enable Night Vision on startup
        line_highlight = true,       -- Highlight line background
        line_nr_highlight = true,    -- Highlight line numbers
        sign_column = "letter",      -- Show in gutter: "letter" (mark a-z), custom character, or "none"
        sort_by = "line",            -- Sort by "line", "alphabetical", or "recency"
        silent = true,               -- Suppress mark operation notifications
    }
})
```

## Essential API Functions

```lua
local marksman = require('marksman')

-- Mark Operations
marksman.set_mark('a')              -- Set mark 'a' at cursor
marksman.auto_mark()                -- Auto-assign next free letter
marksman.next_mark(true)            -- Jump to next mark
marksman.next_mark(false)           -- Jump to previous mark
marksman.delete_mark()              -- Delete mark on current line
marksman.delete_by_letter('a')      -- Delete specific mark
marksman.delete_all_marks()         -- Clear all marks in buffer

-- Night Vision Control
marksman.night_vision()             -- Toggle Night Vision on/off
marksman.refresh()                  -- Refresh Night Vision display
```

## Default Keymaps

```lua
marksman.setup({
    keymaps = {
        open_picker = "<leader>mp",
        next_mark = "<]m>",
        prev_mark = "<[m>",
        toggle_mark = "<leader>m",
        delete_all_marks = "<leader>dam",
        toggle_night_vision = "<leader>nv",
        set_manual_marks = true,  -- Set marks manually (ma, mb, ..., mz)
        del_manual_marks = true,  -- Delete marks manually (dma, dmb, ..., dmz)
    }
})
```

## Telescope Picker Usage

Open with `:Telescope marksman marks` or mapped key (e.g., `<leader>mp`)

**In the picker:**
- Type letter (e.g., `a`) - Jump to that mark instantly
- `<CR>` - Select and jump to highlighted mark
- `<C-d>` - Delete selected mark
- `<C-i>` - Switch to insert mode for filtering
- `<C-k>/<C-j>` - Move selection up/down

## Configuration Options

### Night Vision Settings

```lua
night_vision = {
    enabled = true,                 -- Auto-enable on plugin load
    line_highlight = true,          -- Background color on marked lines
    line_nr_highlight = true,       -- Highlight line numbers
    sign_column = "letter",      -- Show in gutter: "letter" (mark a-z), custom character, or "none"
    virtual_text = "  ",           -- Virtual text icon (set to "" to disable)
    sort_by = "line",               -- Sort marks: "line", "alphabetical", "recency"
    silent = true,                  -- Suppress mark operation notifications
    highlights = {
        line = { fg = "#000000", bg = "#5fd700" },
        line_nr = { fg = "#5fd700", bg = "NONE", bold = true },
        virtual_text = { fg = "#5fd700", bg = "NONE" },
    },
}
```

**Silent Mode**: When `silent = true`, the following operations are suppressed:
- Mark setting/updating (from `set_mark()`, `auto_mark()`)
- Mark deletion (from `delete_mark()`, `delete_by_letter()`, `delete_all_marks()`)
- Night Vision toggle notifications
- Navigation warnings (e.g., no marks in buffer)

### Telescope Picker Highlights

This section configures the appearance of marks and selections in the Telescope picker UI:

```lua
highlights = {
    mark = {
        fg = "#ffaf00",
        bg = "NONE",
        bold = true,
    },
    mark_selected = {
        fg = "NONE",
        bg = "#2A314C",
        bold = true,
    },
    line_nr = {
        fg = "#00aeff",
        bg = "NONE",
        bold = true,
    },
}
```

### Telescope Picker Layout

```lua
layout_config = {
    width = 0.95,        -- Width as percentage of screen
    height = 0.5,        -- Height as percentage of screen
    preview_width = 0.7, -- Preview column width
}
```

### Configuration Validation

The plugin validates certain configuration values and will reset invalid values to defaults with an error notification:

- **`sign_column`**: Must be one of `"letter"` (default), `"none"`, or a single character string (e.g., `"*"`).
- **`sort_by`**: Must be one of `"line"` (default), `"alphabetical"`, or `"recency"`

Invalid values will trigger an error notification and reset to their defaults.

## How Night Vision Works

### Visual Components

When Night Vision is **ON**, marked lines display:

1. **Line Background** - Colored background across entire line
2. **Line Number** - Colored line number in gutter
3. **Sign Column** - Mark letter or icon in left gutter
4. **Virtual Text Icon** - Decorative icon (right-aligned, auto-hides when cursor on line)

### Smart Icon Behavior

The virtual text icon:
- **Appears** when cursor is NOT on the line (visual anchor)
- **Disappears** when cursor IS on the line (clean editing)
- Updates smoothly as you navigate

This reduces visual clutter while editing marked lines.

### Per-Buffer State

Each buffer maintains independent Night Vision state:
- You can toggle NV on for file A and off for file B
- Multi-window editing shows different visual states per window
- Marks persist even when NV is off

## Storage and Persistence

### Mark Timestamps
- Stored in: `~/.local/share/nvim/marksman/`
- One JSON file per buffer (hashed by file path)
- Format: `{mark_letter: unix_timestamp}`
- Auto-cleanup: Files older than 30 days removed

### Why Timestamps?
- Enable "recency" sorting (`sort_by = "recency"`)
- Track when marks were created
- Find recently-modified locations quickly

## Use Cases

### Development
- Mark important functions/classes
- Highlight bug locations during debugging
- Visual anchors during code review
- Jump between related code sections

### Writing
- Mark sections under review
- Highlight areas needing rewrite
- Navigate between work locations
- Track editing progress

### Research
- Mark relevant sections
- Highlight key findings
- Quick navigation between sources
- Visual reference points

## Performance Notes

- **Minimal overhead**: ~1-2% CPU when idle with Night Vision on
- **Fast cursor tracking**: Sub-millisecond virtual text updates
- **Efficient storage**: JSON files ~100 bytes per mark
- **Smart updates**: Only updates changed lines on cursor move

## Common Workflows

### Quick Navigation Workflow
```
1. ma               ← Mark section A
2. mb               ← Mark section B
3. <M-]>            ← Jump to next mark
4. <M-[>            ← Jump to previous mark
5. <C-m>            ← Open picker to browse all marks
6. <leader>dm       ← Delete mark when done
```

### Debugging Workflow
```
1. <leader>m        ← Auto-mark error line
2. <leader>m        ← Auto-mark suspicious line
3. <C-m>            ← Open picker to see all problem areas
4. <M-]>/<M-[>      ← Jump between marked locations
5. <leader>dam      ← Clear all marks after fixing
```

### Multi-File Workflow
```
1. ma (file1)       ← Mark location in file 1
2. :e file2         ← Open file 2
3. mb (file2)       ← Mark location in file 2
4. <leader>nv       ← Toggle Night Vision
5. <C-m>            ← Jump between files using picker
```

## Troubleshooting

### Night Vision not showing
- Ensure `night_vision.enabled = true` in setup
- Check that marks exist in current buffer (`:marks`)
- Try `<leader>nv` to toggle on if toggled off

### Icons not disappearing when cursor on line
- This is expected behavior - virtual text icons hide when editing marked lines
- Move cursor away to see icons reappear

### Marks not persisting across sessions
- Marks are Vim native - they don't persist by default
- Plugin only adds visual feedback and timestamps
- Use a session plugin if persistence needed

### Telescope picker not working
- Ensure telescope.nvim is installed
- Check that `require('telescope').load_extension('marksman')` called
- Try `:Telescope marksman marks` directly

## Dependencies

- **Required**: Neovim 0.8.0+
- **Optional**: nvim-telescope/telescope.nvim (for picker UI)

Without Telescope, core mark operations still work - just no picker.

## File Locations

- **Plugin files**: `~/.config/nvim/lua/marksman/`
- **Timestamp storage**: `~/.local/share/nvim/marksman/`
- **Telescope extension**: `lua/telescope/_extensions/marksman/`

## Architecture Overview

```
init.lua (Plugin initialization & orchestration)
    ├── marks.lua ↔ night_vision.lua (circular dependency, resolved via init())
    │   ├── Mark operations (set, auto, delete, navigate)
    │   └── Visual highlights (line, virtual text, signs)
    ├── data.lua (Timestamp persistence)
    │   └── JSON storage: ~/.local/share/nvim/marksman/
    └── [Optional] telescope extension
        └── picker.lua (Mark browsing UI)
```

Each core module is designed to work independently, with init.lua serving as the orchestrator that handles autocommands and configuration management.

## Advanced Configuration Examples

### Minimal Setup (Marks Only, No Night Vision)
```lua
require('marksman').setup({
    night_vision = {
        enabled = false
    }
})
```

### Visual-Heavy Setup (Everything Highlighted)
```lua
require('marksman').setup({
    layout_config = {
        width = 0.95,
        height = 0.5,
        preview_width = 0.7,
    },
    highlights = {
        mark = {
            fg = "#ffaf00",
            bg = "NONE",
            bold = true,
        },
        line_nr = {
            fg = "#00aeff",
            bg = "NONE",
            bold = true,
        },
        mark_selected = {
            fg = "NONE",
            bg = "#2A314C",
            bold = true,
        },
    },
    night_vision = {
        enabled = true,
        line_highlight = false,
        line_nr_highlight = true,
        sign_column = "letter",
        sort_by = "line",
        virtual_text =  "  ",
        silent = true,
        highlights = {
            line = {
                fg = "#000000",
                bg = "#5fd700",
                bold = true,
                italic = true,
            },
            line_nr = {
                fg = "#5fd700",
                bg = "NONE",
                bold = true,
            },
            virtual_text = {
                fg = "#5fd700",
                bg = "NONE",
                bold = true,
            },
        },
    },
})
```

## Keyboard Cheat Sheet

| Action | Default | Custom Option |
|--------|---------|---------------|
| Auto-mark | None | `<leader>m` |
| Next mark | None | `<M-]>` |
| Prev mark | None | `<M-[>` |
| Toggle NV | None | `<leader>nv` |
| Open picker | None | `<C-m>` |
| Delete mark | None | `<leader>dm` |
| Delete all | None | `<leader>dam` |
| Manual mark | `m{a-z}` | `m` + letter (built-in) |

## Best Practices

1. **Use Auto-mark for Speed**: `<leader>m` is faster than `ma`, `mb`, etc.
2. **Sort by Recency**: Great for resuming work after interruptions
3. **Keep Mark Count Low**: 5-10 marks per file is ideal
4. **Toggle NV as Needed**: Turn off if visual clutter bothers you
5. **Use Picker for Browsing**: Fastest way to see all marks at once

## Resources

- **GitHub**: `jinks908/marksman.nvim`
- **Issues**: Report bugs and feature requests
- **Documentation**: See inline comments in `lua/marksman/*.lua`

---

*Last Updated: 2025-12-30 | Plugin Version: 1.3.3 | Neovim: 0.8.0+*
