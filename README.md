# Marksman for Neovim

![Marksman Thumbnail](https://github.com/user-attachments/assets/57625e07-2284-4155-b5bb-edd252e5f2cd)

## What is Marksman?

**Marksman** is a Neovim plugin that enhances the native Vim mark system with visual feedback and modern UI. The flagship feature is **Night Vision** - a real-time visual highlighting system that shows you exactly where your marks are placed in the buffer.

## Core Philosophy

Here's the thing. Vim marks are powerful but invisible. You set them with `ma`, `mb`, etc., but then you forget where they are and which letters are for what. This becomes even more unwieldy when working with marks across multiple files/buffers. Such drawbacks are cumbersome and typically limit manual mark usage to only 3-5 at most. Marksman completely solves this problem by providing you with an intuitive interface that eliminates the mental overhead of managing vim marks, and even enhances your editor experience with useful visuals.

- Provides visual cues, making marks easy to see, navigate, and manage
- Highlights marked lines in real-time
- Shows indicators in the gutter (sign column)
- Adds virtual text icons as visual anchors
- Provides a Telescope picker to browse marks
- Remembers when marks were created (timestamps)

The result is an intuitive, seamless experience that makes working with marks painless and efficient. You can now set as many marks as you want and let Marksman do the rest. Effortlessly navigate between them, set/remove them, quickly identify and distinguish between Neovim's builtin marks, and focus on your code instead of trying to remember a bunch of letters.

In short, you've been setting and forgetting. Don't lie to me. Don't lie to your family. We all know the truth. Fortunately, this is **exactly** what Marksman **wants** you to do. See? You don't even have to change your habits. You know you're going to set 'em and forget 'em anyway. So go on then. Forget.

## Contents
- [Key Features at a Glance](#key-features-at-a-glance)
- [Installation](#installation)
- [Basic Setup](#basic-setup)
- [Essential API Functions](#essential-api-functions)
- [Default Keymaps](#default-keymaps)
- [Configuration](#configuration)
    - [Night Vision](#night-vision)
    - [Telescope Picker](#telescope-picker)
    - [Telescope Picker Layout](#telescope-picker-layout)
- [How Night Vision Works](#how-night-vision-works)
    - [Visual Components](#visual-components)
    - [Per-Buffer State](#per-buffer-state)
- [Storage and Persistence](#storage-and-persistence)
    - [Mark Timestamps](#mark-timestamps)
    - [Why Timestamps?](#why-timestamps)
- [Dependencies](#dependencies)
- [File Locations](#file-locations)
- [Configuration Examples](#configuration-examples)
    - [Minimal Setup (Marks Only, No Night Vision)](#minimal-setup-marks-only-no-night-vision)
    - [Visual-Heavy Setup (Everything Highlighted)](#visual-heavy-setup-everything-highlighted)
- [Keyboard Cheat Sheet](#keyboard-cheat-sheet)
- [Resources](#resources)


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
        virtual_text =  "●",         -- Virtual text icon (set to "" to disable)
        silent = true,               -- Suppress mark operation notifications
    }
})
```

## Essential API Functions

```lua
local marksman = require('marksman')

-- Mark Operations
marksman.set_mark('a')           -- Set mark 'a' at cursor
marksman.auto_mark()             -- Auto-assign next free letter
marksman.next_mark(true)         -- Jump to next mark
marksman.next_mark(false)        -- Jump to previous mark
marksman.delete_mark()           -- Delete mark on current line
marksman.delete_by_letter('a')   -- Delete specific mark
marksman.delete_all_marks()      -- Clear all marks in buffer

-- Night Vision Control
marksman.night_vision()          -- Toggle Night Vision on/off
marksman.refresh()               -- Refresh Night Vision display
```

## Default Keymaps

### Main Keymaps
```lua
require('marksman').setup({
    keymaps = {
        open_picker = "<leader>mp",          -- Open Telescope picker
        next_mark = "<]m>",                  -- Jump to next mark (w/ wraparound)
        prev_mark = "<[m>",                  -- Jump to previous mark (w/ wraparound)
        toggle_mark = "<leader>m",           -- Toggle mark at cursor (set/delete)
        delete_all_marks = "<leader>dam",    -- Delete all marks in buffer
        toggle_night_vision = "<leader>nv",  -- Toggle Night Vision on/off
        set_manual_marks = true,             -- Set marks manually (ma, mb, ..., mz)
        del_manual_marks = true,             -- Delete marks manually (dma, dmb, ..., dmz)
    }
})
```

### Telescope Picker Keymaps

Open with `:Telescope marksman marks` or mapped key (e.g., `<leader>mp`)

**In the picker:**
- Type letter (e.g., `a`) - Jump to that mark instantly
- `<CR>` - Select and jump to highlighted mark
- `<C-d>` - Delete selected mark
- `<C-i>` - Switch to insert mode for filtering
- `<C-k>/<C-j>` - Move selection up/down

> [!NOTE]
> You can send marks to quickfix from the Telescope picker with `<C-q>`.

![QF List Integration](https://github.com/user-attachments/assets/ea36219b-f762-49ac-9d22-af10407f47a9)

## Configuration

### Night Vision

```lua
require('marksman').setup({
    night_vision = {
        enabled = true,                 -- Auto-enable on plugin load
        line_highlight = true,          -- Background color on marked lines
        line_nr_highlight = true,       -- Highlight line numbers
        sign_column = "letter",         -- Show in gutter: "letter" (mark a-z), custom character, or "none"
        virtual_text = "●",             -- Virtual text icon (set to "" to disable)
        sort_by = "line",               -- Sort marks: "line", "alphabetical", "recency"
        silent = true,                  -- Suppress mark operation notifications
        highlights = {
            line = { fg = "#000000", bg = "#00ffaf" },
            line_nr = { fg = "#00ffaf", bg = "NONE", bold = true },
            virtual_text = { fg = "#00ffaf", bg = "NONE" },
        },
    }
})
```

**Silent Mode**: Using `silent = true` suppresses notifications.

> [!NOTE]
> For a visual enhancement, it recommended to use Nerd Font symbols for sign column and/or virtual text icons as they can be more useful indicators (See screenshots).

![Night Vision](https://github.com/user-attachments/assets/2d136aa8-1881-4285-b03d-f429aa557ad4)



### Telescope Picker

This section configures the appearance of marks and selections in the Telescope picker UI:

```lua
require('marksman').setup({
    highlights = {
        mark = {
            fg = "#00aeff",
            bg = "NONE",
            bold = true,
        },
        mark_selected = {
            fg = "NONE",
            bg = "#2A314C",
            bold = true,
        },
        line_nr = {
            fg = "#00ffaf",
            bg = "NONE",
            bold = true,
        }
    }
})
```

### Telescope Picker Layout

```lua
require('marksman').setup({
    layout_config = {
        width = 0.95,        -- Width as percentage of screen
        height = 0.5,        -- Height as percentage of screen
        preview_width = 0.7, -- Preview column width
    }
})
```
![Marksman Picker](https://github.com/user-attachments/assets/e49d98f3-c862-47d7-8469-fd26a7acc8dc)



## How Night Vision Works

### Visual Components

When Night Vision is **ON**, marked lines can display:

- **Line Background** - Colored background across entire line
- **Line Number** - Colored line number in gutter
- **Sign Column** - Mark letter or icon in left gutter
- **Virtual Text** - Visual indicator inside the editor (right-aligned)
    - Auto-hides on cursor hover (this reduces visual clutter while editing marked lines).


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


## Dependencies

- **Required**: Neovim 0.8.0+
- **Optional**: nvim-telescope/telescope.nvim (for picker UI)

Without Telescope, core mark operations still work - just no picker.

## File Locations

- **Plugin files**: `~/.config/nvim/lua/marksman/`
- **Timestamp storage**: `~/.local/share/nvim/marksman/`
- **Telescope extension**: `lua/telescope/_extensions/marksman/`


## Configuration Examples

### Minimal Setup (Marks Only, No Night Vision)
```lua
require('marksman').setup({
    night_vision = {
        enabled = false
    },
    keymaps = {
        open_picker = "<leader>mp",
        next_mark = "<]m>",
        prev_mark = "<[m>",
        toggle_mark = "<leader>m",
        delete_all_marks = "<leader>dam",
        set_manual_marks = true,
        del_manual_marks = true,
        picker = {
            next_item = "<C-j>",
            prev_item = "<C-k>",
            delete_mark = "<C-d>",
            insert_mode = "<C-i>"
        }
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
            fg = "#00aeff",
            bg = "NONE",
            bold = true,
        },
        mark_selected = {
            fg = "NONE",
            bg = "#2A314C",
            bold = true,
        },
        line_nr = {
            fg = "#00ffaf",
            bg = "NONE",
            bold = true,
        },
    },
    night_vision = {
        enabled = true,
        line_highlight = true,
        line_nr_highlight = true,
        sign_column = "letter",
        virtual_text =  "●",
        sort_by = "line",
        silent = true,
        highlights = {
            line = { fg = "#000000", bg = "#00ffaf", },
            line_nr = { fg = "#00ffaf", bg = "NONE", bold = true, },
            virtual_text = { fg = "#00ffaf", bg = "NONE", bold = true, },
            last_change = { fg = "#f7768e", bg = "NONE", bold = true },
            last_insert = { fg = "#ff875f", bg = "NONE", bold = true },
            visual_start = { fg = "#a6e87d", bg = "NONE", bold = true },
            visual_end = { fg = "#a6e87d", bg = "NONE", bold = true },
            last_jump_line = { fg = "#53adf9", bg = "NONE", bold = true },
            last_jump = { fg = "#53adf9", bg = "NONE", bold = true },
            last_exit = { fg = "#be86f7", bg = "NONE", bold = true },
        },
    },
})
```

## Keyboard Cheat Sheet

| Action | Default |
|--------|---------|
| Toggle mark | `<leader>m` |
| Next mark | `]m` |
| Prev mark | `[m` |
| Toggle Night Vision | `<leader>nv` |
| Open picker | `<leader>mp` |
| Delete all marks | `<leader>dam` |
| Manual mark | `m` + letter (built-in) |


## Resources

- **GitHub**: `jinks908/marksman.nvim`
- **Issues**: Report bugs and feature requests
- **Documentation**: See inline comments in `lua/marksman/*.lua`
- **Similar Plugins**:
    - [marks.nvim](https://github.com/chentoast/marks.nvim)
    - [Harpoon](https://github.com/ThePrimeagen/harpoon/tree/harpoon2)
    - [vim-signature](https://github.com/kshenoy/vim-signature)
    - [vim-bookmarks](https://github.com/MattesGroeger/vim-bookmarks)

---

*Last Updated: 2025-12-30 | Plugin Version: 1.4.4 | Neovim: 0.8.0+*
