-- lua/marksman/init.lua

local M = {}

M.version = "1.0.0"
M.min_nvim_version = "0.8.0"

-- Store setup state
local setup_done = false

-- Setup function
function M.setup(opts)
    -- Check Neovim version
    if vim.fn.has("nvim-" .. M.min_nvim_version) == 0 then
        vim.notify("Marksman requires Neovim " .. M.min_nvim_version, vim.log.levels.ERROR)
        return
    end

    -- Prevent multiple setups
    if setup_done then
        return
    end

    -- Apply configuration
    local config = require('marksman.config')
    config.setup(opts)

    -- Load required modules
    local night_vision = require('marksman.night_vision')
    local marks = require('marksman.marks')

    marks.init()

    -- Require data module once at setup
    local data = require('marksman.data')

    -- Load timestamps on BufEnter
    vim.api.nvim_create_autocmd('BufEnter', {
        group = vim.api.nvim_create_augroup('Marksman', { clear = true }),
        callback = function()
            data.load_timestamps()
        end
    })

    -- Load timestamps on VimEnter
    vim.api.nvim_create_autocmd('VimEnter', {
        group = vim.api.nvim_create_augroup('Marksman', { clear = true }),
        callback = function()
            data.load_timestamps()
            data.cleanup_timestamp_files()
        end,
        once = true
    })

    -- Set up the autocommand for direct cursor tracking with per-line state
    -- This replaces the debounce approach with immediate, per-line state updates
    vim.api.nvim_create_autocmd({'CursorMovedI', 'CursorMoved'}, {
        group = vim.api.nvim_create_augroup('MarksmanCursor', { clear = true }),
        callback = function()
            night_vision.update_virtual_text_for_cursor()
        end
    })

    -- Activate Night Vision if enabled
    if config.options.night_vision.enabled then
        vim.defer_fn(function()
            night_vision.refresh()
        end, 100)
    end

    -- Track previous mark count per buffer
    local mark_counts = {}

    -- Update NV when marked lines are deleted/restored (n.b., only on write)
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = vim.api.nvim_create_augroup('MarksmanRefresh', { clear = true }),
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()

            -- Count marks if NV active
            if night_vision.nv_state[bufnr] then
                local current_marks = marks.get_marks()
                local current_count = #current_marks
                local previous_count = mark_counts[bufnr] or 0

                -- Refresh if mark count changed (line deletion removed a mark)
                if current_count ~= previous_count then
                    night_vision.refresh()
                    mark_counts[bufnr] = current_count
                end
            end
        end
    })

    -- Try to load telescope extension
    local has_telescope, telescope = pcall(require, 'telescope')
    if has_telescope then
        telescope.load_extension('marksman')
    end

    -- Register manual mark keymaps (ma, mb, ..., mz) if enabled
    if config.options.keymaps.enabled then
        local opts = { noremap = true, silent = true }
        for i = 97, 122 do
            local key = string.char(i)
            vim.keymap.set('n', 'm' .. key, function()
                marks.set_mark(key)
            end, opts)
        end
    end

    -- Export all public functions
    M.set_mark = marks.set_mark
    M.auto_mark = marks.auto_mark
    M.next_mark = marks.next_mark
    M.delete_mark = marks.delete_mark
    M.delete_by_letter = marks.delete_by_letter
    M.delete_all_marks = marks.delete_all_marks
    M.night_vision = night_vision.toggle
    M.refresh = night_vision.refresh
    M.hide_line = night_vision.hide_line
    M.show_line = night_vision.show_line

    setup_done = true
end

-- Return module
return M
