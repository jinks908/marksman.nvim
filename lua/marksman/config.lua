--- lua/marksman/config.lua
---
--- Configuration module for Marksman plugin
---
--- Handles configuration loading, merging defaults with user options,
--- and validating configuration values.
---
--- Default configuration includes:
---   - Highlight colors for marks and Night Vision
---   - Layout configuration for Telescope picker
---   - Night Vision settings (enabled, line highlighting, sort order, etc.)
---   - Keymap settings (enable/disable manual mark keymaps)

local M = {}

-- Default Config
M.defaults = {
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
            fg = "#5fd700",
            bg = "NONE",
            bold = true,
        },
    },
    layout_config = {
        width = 0.9,
        height = 0.5,
        preview_width = 0.5,
    },
    night_vision = {
        enabled = true,
        line_highlight = true,
        line_nr_highlight = true,
        sign_column = "letter",
        virtual_text =  "  ",
        sort_by = "line",
        silent = true,
        highlights = {
            line = {
                fg = "#000000",
                bg = "#5fd700",
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
    keymaps = {
        enabled = true,  -- Enable manual mark keymaps (ma, mb, ..., mz)
    }
}

-- Store valid config options
local valid_sign_options = {
    icon = true,
    letter = true,
    none = true,
}
local valid_sort_options = {
    line = true,
    alphabetical = true,
    recency = true,
}

--- Merge user configuration options with defaults and validate
--- @param opts? table User configuration options to merge with defaults
--- @return nil
function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
    -- Validate after setup
    M.validate_config()
end

--- Validate configuration values and notify user of invalid options
--- @return boolean true if configuration is valid, false otherwise
function M.validate_config()
    local options = M.options or M.defaults

    if not valid_sign_options[options.night_vision.sign_column] then
        vim.notify({ 'Invalid sign_column option: "' .. options.night_vision.sign_column .. '"', 'Must be either: "icon", "letter", or "none"', 'Defaulting to "icon"' }, vim.log.levels.ERROR, { timeout = 4000 })
        options.night_vision.sign_column = "icon"
        return false
    end
    if not valid_sort_options[options.night_vision.sort_by] then
        vim.notify({ 'Invalid sort_by option: "' .. options.night_vision.sort_by .. '"', 'Must be: "line", "alphabetical", or "recency"', 'Defaulting to "line"' }, vim.log.levels.ERROR, { timeout = 4000 })
        options.night_vision.sort_by = "line"
        return false
    end
    return true
end

return M
