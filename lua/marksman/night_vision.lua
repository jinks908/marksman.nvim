-- lua/marksman/night_vision.lua

local M = {}
local config = require('marksman.config')
local marks = require('marksman.marks')

M.mark_lines = {}

-- State management
M.nv_state = {}

-- Create new namespace
local ns_id = vim.api.nvim_create_namespace('Marksman')
local ns_id_vt = vim.api.nvim_create_namespace('MarksmanVT')

-- Define the virtual text icon for Night Vision
local nv_icon = '  '

-- Buffer-specific sign tracking
local buffer_signs = {}

-- Per-line cursor state tracking: buffer -> {line -> is_cursor_on_line}
local cursor_on_marked_lines = {}

-- Virtual text extmark IDs tracking: buffer -> {line -> extmark_id}
local vt_extmark_ids = {}

-- Helper function to safely get config options
local function get_config_options()
    return config.options or config.defaults
end

-- Helper function to validate line number
local function is_valid_line(bufnr, lnum)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    return lnum > 0 and lnum <= line_count
end

-- Helper function to get unique sign name for buffer and mark
local function get_sign_name(bufnr, mark)
    return string.format('Marksman_%d_%s', bufnr, mark or 'base')
end

-- Helper function to clear buffer-specific signs
local function clear_buffer_signs(bufnr)
    if buffer_signs[bufnr] then
        for extmark_id, _ in pairs(buffer_signs[bufnr]) do
            pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
        end
        buffer_signs[bufnr] = {}
    end
    -- Clear cursor state tracking for this buffer
    cursor_on_marked_lines[bufnr] = nil
    -- Clear virtual text extmark IDs for this buffer
    vt_extmark_ids[bufnr] = nil
end

-- Helper function to refresh all virtual text icons
local function refresh_all_virtual_text()
    local bufnr = vim.api.nvim_get_current_buf()
    local current_marks = marks.get_marks()
    local current_cursor = vim.api.nvim_win_get_cursor(0)[1]

    -- Initialize VT extmark IDs for this buffer if needed
    if not vt_extmark_ids[bufnr] then
        vt_extmark_ids[bufnr] = {}
    end

    -- Initialize cursor state for this buffer if needed
    if not cursor_on_marked_lines[bufnr] then
        cursor_on_marked_lines[bufnr] = {}
    end

    -- Clear all virtual text for this buffer
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id_vt, 0, -1)
    vt_extmark_ids[bufnr] = {}

    -- Re-add virtual text for all marked lines
    for _, mark in ipairs(current_marks) do
        if is_valid_line(bufnr, mark.lnum) then
            -- Hide icon when cursor is on a marked line
            local virt_text_content = ''
            local cursor_is_on = (current_cursor == mark.lnum)
            -- Show icon when cursor is NOT on a marked line
            if not cursor_is_on then
                virt_text_content = nv_icon
            end

            local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id_vt, mark.lnum - 1, 0, {
                virt_text = {{virt_text_content, 'NightVisionVirtualText'}},
                virt_text_pos = 'right_align',
            })
            vt_extmark_ids[bufnr][mark.lnum] = extmark_id
            -- Track the initial cursor state for this line
            cursor_on_marked_lines[bufnr][mark.lnum] = cursor_is_on
        end
    end
end

-- Setup highlight groups
function M.setup_highlights()
    local options = get_config_options()
    vim.api.nvim_set_hl(0, 'MarksmanMark', options.highlights.mark)
    vim.api.nvim_set_hl(0, 'MarksmanMarkSelected', options.highlights.mark_selected)
    vim.api.nvim_set_hl(0, 'MarksmanLine', options.highlights.line_nr)
    vim.api.nvim_set_hl(0, 'NightVision', options.night_vision.highlights.line)
    vim.api.nvim_set_hl(0, 'NightVisionLineNr', options.night_vision.highlights.line_nr)
    vim.api.nvim_set_hl(0, 'NightVisionVirtualText', options.night_vision.highlights.virtual_text)
end

-- #:# Update Virtual Text Based on Cursor Position
-- Direct cursor tracking with per-line state management
function M.update_virtual_text_for_cursor()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Early exit if Night Vision is not active
    if not M.nv_state[bufnr] then
        return
    end

    -- Validate buffer
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    -- Initialize cursor state for this buffer if needed
    if not cursor_on_marked_lines[bufnr] then
        cursor_on_marked_lines[bufnr] = {}
    end

    -- Initialize VT extmark IDs for this buffer if needed
    if not vt_extmark_ids[bufnr] then
        vt_extmark_ids[bufnr] = {}
    end

    -- Get current cursor position safely
    local ok, cursor_pos = pcall(vim.api.nvim_win_get_cursor, 0)
    if not ok or not cursor_pos then
        return
    end

    local current_cursor = cursor_pos[1]

    -- Validate cursor position
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if current_cursor < 1 or current_cursor > line_count then
        return
    end

    local current_marks = marks.get_marks()
    if not current_marks or #current_marks == 0 then
        return
    end

    -- Update virtual text for each marked line
    for _, mark in ipairs(current_marks) do
        if not is_valid_line(bufnr, mark.lnum) then
            goto continue
        end

        local cursor_was_on = cursor_on_marked_lines[bufnr][mark.lnum] or false
        local cursor_is_on = (current_cursor == mark.lnum)

        -- Only update if state changed
        if cursor_was_on ~= cursor_is_on then
            local virt_text_content = cursor_is_on and '' or nv_icon

            -- Delete old extmark if it exists
            local old_id = vt_extmark_ids[bufnr][mark.lnum]
            if old_id then
                pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id_vt, old_id)
            end

            -- Set new extmark and store its ID
            local new_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id_vt, mark.lnum - 1, 0, {
                virt_text = {{virt_text_content, 'NightVisionVirtualText'}},
                virt_text_pos = 'right_align',
            })
            vt_extmark_ids[bufnr][mark.lnum] = new_id
            cursor_on_marked_lines[bufnr][mark.lnum] = cursor_is_on
        end

        ::continue::
    end
end


-- #:# Toggle Night Vision
function M.toggle()
    local current_marks = marks.get_marks()
    local options = get_config_options()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Initialize buffer signs tracking if needed
    if not buffer_signs[bufnr] then
        buffer_signs[bufnr] = {}
    end

    -- Toggle off
    if M.nv_state[bufnr] then
        -- Clear highlighting namespaces for this buffer only
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id_vt, 0, -1)
        -- Clear buffer-specific signs only
        clear_buffer_signs(bufnr)
        -- Clear mark_lines array
        M.mark_lines = {}
        if not options.night_vision.silent then
            vim.notify(' Night Vision off', vim.log.levels.INFO,
                {
                    title = " Marksman " .. nv_icon,
                    timeout = 500
                })
        end
    -- Toggle on
    else
        -- Call highlight groups
        M.setup_highlights()
        -- Clear mark_lines array before repopulating
        M.mark_lines = {}
        -- Apply NightVision highlight groups
        for _, mark in ipairs(current_marks) do
            if is_valid_line(bufnr, mark.lnum) then
                table.insert(M.mark_lines, mark.lnum)
                if options.night_vision.line_highlight then
                    -- Highlight marked lines
                    vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                        {
                            line_hl_group = "NightVision",
                        })
                end
                if options.night_vision.line_nr_highlight then
                    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                        {
                            number_hl_group = "NightVisionLineNr",
                            priority = 5000
                        })
                    buffer_signs[bufnr][extmark_id] = true
                end
                if options.night_vision.sign_column and options.night_vision.sign_column ~= "none" then
                    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                        {
                            sign_text = mark.mark,
                            sign_hl_group = "NightVisionLineNr",
                            priority = 5000
                        })
                    buffer_signs[bufnr][extmark_id] = true
                end
            end
        end

        -- Set up virtual text for all marked lines
        if options.night_vision.sign_column and options.night_vision.sign_column ~= "none" then
            refresh_all_virtual_text()
        end

        if not options.night_vision.silent then
            -- Notify user
            vim.notify(' Night Vision on', vim.log.levels.INFO,
                {
                    title = " Marksman " .. nv_icon,
                    timeout = 500
                })
        end
    end
    M.nv_state[bufnr] = not M.nv_state[bufnr]
end

-- #:# Refresh Night Vision
function M.refresh()
    local current_marks = marks.get_marks()
    local options = get_config_options()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Initialize buffer signs tracking if needed
    if not buffer_signs[bufnr] then
        buffer_signs[bufnr] = {}
    end

    -- Clear highlighting namespaces for this buffer only
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id_vt, 0, -1)
    -- Clear buffer-specific signs only
    clear_buffer_signs(bufnr)

    -- Clear mark_lines array before repopulating
    M.mark_lines = {}

    M.setup_highlights()

    for _, mark in ipairs(current_marks) do
        if is_valid_line(bufnr, mark.lnum) then
            table.insert(M.mark_lines, mark.lnum)
            if options.night_vision.line_highlight then
                -- Highlight marked lines
                vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                    {
                        line_hl_group = "NightVision",
                        priority = 200
                    })
            end
            if options.night_vision.line_nr_highlight then
                local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                    {
                        number_hl_group = "NightVisionLineNr",
                        priority = 5000
                    })
                buffer_signs[bufnr][extmark_id] = true
            end
            if options.night_vision.sign_column and options.night_vision.sign_column ~= "none" then
                local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                    {
                        sign_text = mark.mark,
                        sign_hl_group = "NightVisionLineNr",
                        priority = 5000
                    })
                buffer_signs[bufnr][extmark_id] = true
            end
        end
    end

    -- Set up virtual text for all marked lines
    if options.night_vision.sign_column and options.night_vision.sign_column ~= "none" then
        refresh_all_virtual_text()
    end

    M.nv_state[bufnr] = true
end

-- #:# VT Toggle Functions
-- ## Show Line
-- Replace virtual text icon when cursor moves off the line
M.show_line = function(lnum)
    local bufnr = vim.api.nvim_get_current_buf()

    -- Validate line number before proceeding
    if not is_valid_line(bufnr, lnum) then
        return
    end

    -- Refresh all virtual text instead of just one line
    refresh_all_virtual_text()
end

-- ## Hide Line
-- Hide virtual text icon when cursor is on the line
M.hide_line = function(lnum)
    local bufnr = vim.api.nvim_get_current_buf()

    -- Validate line number before proceeding
    if not is_valid_line(bufnr, lnum) then
        return
    end

    -- Refresh all virtual text instead of just one line
    refresh_all_virtual_text()
end

-- Function to apply Night Vision to current buffer (without toggling global state)
local function apply_night_vision_to_buffer()
    local current_marks = marks.get_marks()
    local options = get_config_options()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Initialize Night Vision state for this buffer if needed
    if M.nv_state[bufnr] == nil then
        M.nv_state[bufnr] = config.options.night_vision.enabled
    end

    -- Early exit if Night Vision is not active for this buffer
    if not M.nv_state[bufnr] then
        return
    end

    -- Initialize buffer signs tracking if needed
    if not buffer_signs[bufnr] then
        buffer_signs[bufnr] = {}
    end

    -- Clear existing highlights and signs for this buffer
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id_vt, 0, -1)
    clear_buffer_signs(bufnr)

    -- Apply highlights and signs to this buffer
    M.setup_highlights()

    for _, mark in ipairs(current_marks) do
        if is_valid_line(bufnr, mark.lnum) then
            if options.night_vision.line_highlight then
                vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                    {
                        line_hl_group = "NightVision",
                        priority = 200
                    })
            end
            if options.night_vision.line_nr_highlight then
                local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                    {
                        number_hl_group = "NightVisionLineNr",
                        priority = 5000
                    })
                buffer_signs[bufnr][extmark_id] = true
            end
            if options.night_vision.sign_column and options.night_vision.sign_column ~= "none" then
                local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                    {
                        sign_text = mark.mark,
                        sign_hl_group = "NightVisionLineNr",
                        priority = 5000
                    })
                buffer_signs[bufnr][extmark_id] = true
            end
        end
    end

    -- Set up virtual text for all marked lines
    if options.night_vision.sign_column and options.night_vision.sign_column ~= "none" then
        refresh_all_virtual_text()
    end
end

-- Auto-apply Night Vision to new buffers when they're opened
vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
    callback = function()
        -- Small delay to ensure marks are loaded
        vim.defer_fn(function()
            apply_night_vision_to_buffer()
        end, 10)
    end
})

-- Clean up buffer signs when buffer is deleted
vim.api.nvim_create_autocmd('BufDelete', {
    callback = function(args)
        local bufnr = args.buf
        if buffer_signs[bufnr] then
            buffer_signs[bufnr] = nil
        end
    end
})

-- Expose the apply function for manual use if needed
M.apply_to_current_buffer = apply_night_vision_to_buffer

return M
