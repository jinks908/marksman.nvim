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
    -- Highlights for Telescope picker
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
    -- Telescope layout configuration
    layout_config = {
        width = 0.9,
        height = 0.5,
        preview_width = 0.5,
    },
    -- Use Neovim's builtin marks
    builtin_marks = {
        enabled = true,
        show_signs = {
            last_change = ".",
            last_insert = "^",
            visual_start = "<",
            visual_end = ">",
        },
        show_virtual_text = {
            last_change = ".",
            last_insert = "^",
            visual_start = "<",
            visual_end = ">",
        },
    },
    -- Night Vision configuration and highlights
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
    -- Leave empty to disable keymap
    keymaps = {
        open_picker = "<leader>mp",
        next_mark = "]m",
        prev_mark = "[m",
        toggle_mark = "<leader>m",
        delete_all_marks = "<leader>dam",
        toggle_night_vision = "<leader>nv",
        set_manual_marks = true,  -- Set marks manually (ma, mb, ..., mz)
        del_manual_marks = true,  -- Delete marks manually (dma, dmb, ..., dmz)
        picker = {
            next_item = "<C-j>",
            prev_item = "<C-k>",
            delete_mark = "<C-d>",
            insert_mode = "<C-i>"
        }
    }
}

-- Store valid config options
local valid_sign_options = {
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
        if #options.night_vision.sign_column > 1 then
            ---@diagnostic disable-next-line: param-type-mismatch
            vim.notify({ 'Invalid sign_column option: "' .. options.night_vision.sign_column .. '"', 'Must be either: "none", "letter", or a single character', 'Defaulting to "letter"' }, vim.log.levels.ERROR, { timeout = 4000 })
            options.night_vision.sign_column = "letter"
            return false
        end
    end
    if not valid_sort_options[options.night_vision.sort_by] then
        ---@diagnostic disable-next-line: param-type-mismatch
        vim.notify({ 'Invalid sort_by option: "' .. options.night_vision.sort_by .. '"', 'Must be: "line", "alphabetical", or "recency"', 'Defaulting to "line"' }, vim.log.levels.ERROR, { timeout = 4000 })
        options.night_vision.sort_by = "line"
        return false
    end
    return true
end

return M
