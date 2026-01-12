--- lua/marksman/night_vision.lua
---
--- Night Vision visual feedback module for Marksman
---
--- Handles real-time visual highlighting of marked lines:
---   - Line background highlighting
---   - Line number highlighting
---   - Mark letters/icons in the gutter
---   - Virtual text icons
---
--- Features:
---   - Per-buffer state management (independent Night Vision per document)
---   - Smart icon toggling: icons hide when cursor on line, show when away
---   - Smooth updates on cursor movement
---   - Automatic application to new buffers
---
--- Public API:
---   - setup_highlights(): Configure highlight groups for Night Vision
---   - update_virtual_text_for_cursor(): Update virtual text based on cursor position
---   - toggle(): Toggle Night Vision on/off for current buffer
---   - refresh(): Refresh Night Vision display in current buffer

local M = {}
local config = require('marksman.config')
local marks = require('marksman.marks')

M.mark_lines = {}

-- State management
M.nv_state = {}

-- Create new namespace
local ns_id = vim.api.nvim_create_namespace('Marksman')
local ns_id_vt = vim.api.nvim_create_namespace('MarksmanVT')
local ns_id_builtin = vim.api.nvim_create_namespace('BuiltinMarks')

-- Buffer-specific sign tracking
local buffer_signs = {}

-- Per-line cursor state tracking: buffer -> {line -> is_cursor_on_line}
local cursor_on_marked_lines = {}

-- Virtual text extmark IDs tracking: buffer -> {line -> extmark_id}
local vt_extmark_ids = {}

-- Helper function to validate line number
local function is_valid_line(bufnr, lnum)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    return lnum > 0 and lnum <= line_count
end

-- Helper function to check user exclusions
local function exclude_buffer(bufnr)
    -- Validate buffer
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return true
    end

    local buftype = vim.bo[bufnr].buftype
    local filetype = vim.bo[bufnr].filetype

    for _, type in ipairs(config.options.night_vision.exclude.buffer_types) do
        if buftype == type then
            return true
        end
    end

    for _, type in ipairs(config.options.night_vision.exclude.filetypes) do
        if filetype == type then
            return true
        end
    end

    return false
end

-- Helper function to clear buffer-specific signs
local function clear_buffer_signs(bufnr)
    if buffer_signs[bufnr] then
        for extmark_id, _ in pairs(buffer_signs[bufnr]) do
            pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
            pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id_builtin, extmark_id)
        end
        buffer_signs[bufnr] = {}
    end
    -- Clear cursor state tracking for this buffer
    cursor_on_marked_lines[bufnr] = nil
    -- Clear virtual text extmark IDs for this buffer
    vt_extmark_ids[bufnr] = nil
end

-- Helper function to get virtual text content for a mark
local function get_virtual_text_content(mark, cursor_is_on)
    if cursor_is_on then
        return ''
    end
    if mark.builtin then
        return config.options.builtin_marks[mark.type].virtual_text or ''
    elseif config.options.night_vision.virtual_text == "letter" then
        return mark.mark .. ' '
    else
        return config.options.night_vision.virtual_text
    end
end

-- Helper function to get highlight group for a mark's virtual text
local function get_virtual_text_hl_group(mark)
    if mark.builtin then
        return 'BuiltinMark_' .. mark.type
    else
        return 'NightVisionVirtualText'
    end
end

-- Helper function to apply virtual text extmark for a mark
local function apply_virtual_text_extmark(bufnr, mark, virt_text_content)
    local hl_group = get_virtual_text_hl_group(mark)
    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id_vt, mark.lnum - 1, 0, {
        virt_text = {{virt_text_content, hl_group}},
        virt_text_pos = 'right_align',
    })
    return extmark_id
end

-- Helper function to apply sign column extmark
local function apply_sign_column_extmark(bufnr, mark)
    if config.options.night_vision.sign_column == "none" or mark.builtin then
        return
    end

    local sign_text = config.options.night_vision.sign_column == "letter" and mark.mark or config.options.night_vision.sign_column
    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0, {
        sign_text = sign_text,
        sign_hl_group = "NightVisionLineNr",
        priority = 5000
    })
    buffer_signs[bufnr][extmark_id] = true
end

-- Helper function to apply builtin mark extmark
local function apply_builtin_mark_extmark(bufnr, mark)
    local hl_type = mark.type
    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id_builtin, mark.lnum - 1, 0, {
        sign_text = mark.sign or '',
        sign_hl_group = mark.sign and "BuiltinMark_" .. hl_type or nil,
        number_hl_group = mark.line_hl and "BuiltinMark_" .. hl_type or nil,
        priority = 2000
    })
    buffer_signs[bufnr][extmark_id] = true
end

-- Helper function to apply all extmarks for a single marked line
local function apply_marks_for_line(bufnr, mark)
    -- Apply line background highlight
    if config.options.night_vision.line_highlight then
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0, {
            line_hl_group = "NightVision",
            priority = 5000
        })
    end

    -- Apply line number highlight (non-builtin marks only)
    if config.options.night_vision.line_nr_highlight and not mark.builtin then
        local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0, {
            number_hl_group = "NightVisionLineNr",
            priority = 5000
        })
        buffer_signs[bufnr][extmark_id] = true
    end

    -- Apply sign column
    apply_sign_column_extmark(bufnr, mark)

    -- Apply builtin mark styling
    if mark.builtin and mark.enabled then
        apply_builtin_mark_extmark(bufnr, mark)
    end
end

-- Helper function to refresh all virtual text icons
local function refresh_all_virtual_text()
    local bufnr = vim.api.nvim_get_current_buf()
    local current_marks = marks.get_marks()
    local current_cursor = vim.api.nvim_win_get_cursor(0)[1]

    -- Initialize cursor state for this buffer if needed
    if not cursor_on_marked_lines[bufnr] then
        cursor_on_marked_lines[bufnr] = {}
    end

    -- Initialize VT extmark IDs for this buffer if needed
    if not vt_extmark_ids[bufnr] then
        vt_extmark_ids[bufnr] = {}
    end

    -- Clear all virtual text for this buffer
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id_vt, 0, -1)
    vt_extmark_ids[bufnr] = {}

    -- Re-add virtual text for all marked lines
    local line_num = -1
    for _, mark in ipairs(current_marks) do
        if mark.builtin and not mark.enabled then
            goto continue
        end
        -- Avoid duplicate VT icons on same line
        if is_valid_line(bufnr, mark.lnum) then
            local cursor_is_on = (current_cursor == mark.lnum)
            local virt_text_content = get_virtual_text_content(mark, cursor_is_on)
            local extmark_id = apply_virtual_text_extmark(bufnr, mark, virt_text_content)
            vt_extmark_ids[bufnr][mark.lnum] = extmark_id
            cursor_on_marked_lines[bufnr][mark.lnum] = cursor_is_on
        end
    end
        ::continue::
end

-- Core function to apply all marks to a buffer
--- @param bufnr - Buffer number
--- @param should_clear - Whether to clear existing marks first
local function apply_marks_to_buffer(bufnr, should_clear)
    local current_marks = marks.get_marks()

    -- Early exit if buffer should be excluded
    if exclude_buffer(bufnr) then
        return
    end

    if should_clear then
        -- Clear existing marks
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id_vt, 0, -1)
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id_builtin, 0, -1)
        clear_buffer_signs(bufnr)
        M.mark_lines = {}
    end

    -- Setup highlights
    M.setup_highlights()

    -- Apply marks to buffer, avoiding duplicates on same line
    local line_num = -1
    for _, mark in ipairs(current_marks) do
        if is_valid_line(bufnr, mark.lnum) and mark.lnum ~= line_num then
            line_num = mark.lnum
            table.insert(M.mark_lines, mark.lnum)
            apply_marks_for_line(bufnr, mark)
        elseif is_valid_line(bufnr, mark.lnum) and not mark.builtin then
            vim.api.nvim_buf_clear_namespace(bufnr, ns_id, mark.lnum, mark.lnum + 1)
            vim.api.nvim_buf_clear_namespace(bufnr, ns_id_vt, mark.lnum, mark.lnum + 1)
            vim.api.nvim_buf_clear_namespace(bufnr, ns_id_builtin, mark.lnum, mark.lnum + 1)
            table.insert(M.mark_lines, mark.lnum)
            apply_marks_for_line(bufnr, mark)
        else
            table.insert(M.mark_lines, mark.lnum)
            apply_marks_for_line(bufnr, mark)
        end
    end

    -- Apply virtual text if enabled
    if config.options.night_vision.virtual_text ~= "" then
        refresh_all_virtual_text()
    end
end

--- Setup highlight groups for Night Vision
--- @return nil
function M.setup_highlights()
    -- Normal mark highlights
    vim.api.nvim_set_hl(0, 'MarksmanMark', config.options.highlights.mark)
    vim.api.nvim_set_hl(0, 'MarksmanMarkSelected', config.options.highlights.mark_selected)
    vim.api.nvim_set_hl(0, 'MarksmanLine', config.options.highlights.line_nr)
    vim.api.nvim_set_hl(0, 'NightVision', config.options.night_vision.highlights.line)
    vim.api.nvim_set_hl(0, 'NightVisionLineNr', config.options.night_vision.highlights.line_nr)
    vim.api.nvim_set_hl(0, 'NightVisionVirtualText', config.options.night_vision.highlights.virtual_text)

    -- Builtin mark highlights
    vim.api.nvim_set_hl(0, 'BuiltinMark_last_change', config.options.night_vision.highlights.last_change)
    vim.api.nvim_set_hl(0, 'BuiltinMark_last_insert', config.options.night_vision.highlights.last_insert)
    vim.api.nvim_set_hl(0, 'BuiltinMark_visual_start', config.options.night_vision.highlights.visual_start)
    vim.api.nvim_set_hl(0, 'BuiltinMark_visual_end', config.options.night_vision.highlights.visual_end)
    vim.api.nvim_set_hl(0, 'BuiltinMark_last_jump_line', config.options.night_vision.highlights.last_jump_line)
    vim.api.nvim_set_hl(0, 'BuiltinMark_last_jump', config.options.night_vision.highlights.last_jump)
    vim.api.nvim_set_hl(0, 'BuiltinMark_last_exit', config.options.night_vision.highlights.last_exit)
end

--- Update virtual text decorations based on cursor position
--- Hides icons when cursor is on a marked line, shows them when cursor is away
--- @return nil
function M.update_virtual_text_for_cursor()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Early exit if buffer should be excluded
    if exclude_buffer(bufnr) then
        return
    end

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
    local line_num = -1
    for _, mark in ipairs(current_marks) do
        if not is_valid_line(bufnr, mark.lnum) then
            goto continue
        end

        if mark.builtin and not mark.enabled then
            goto continue
        end

        local cursor_was_on = cursor_on_marked_lines[bufnr][mark.lnum] or false
        local cursor_is_on = (current_cursor == mark.lnum)

        -- Only update if state changed
        if cursor_was_on ~= cursor_is_on then
            M.refresh()
            -- Track the current cursor state for this line
            cursor_on_marked_lines[bufnr][mark.lnum] = cursor_is_on
        end

        ::continue::
    end
end

--- Toggle Night Vision on/off for current buffer
--- @return nil
function M.toggle()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Early exit if buffer should be excluded
    if exclude_buffer(bufnr) then
        vim.notify(' Night Vision is currently disabled for this buffer. Please check your config to change.', vim.log.levels.WARN, {
            title = " Marksman " .. config.options.night_vision.virtual_text,
            timeout = 2000
        })
        return
    end

    -- Initialize buffer signs tracking if needed
    if not buffer_signs[bufnr] then
        buffer_signs[bufnr] = {}
    end

    -- Toggle off
    if M.nv_state[bufnr] then
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id_vt, 0, -1)
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id_builtin, 0, -1)
        clear_buffer_signs(bufnr)
        M.mark_lines = {}
        if not config.options.night_vision.silent then
            vim.notify(' Night Vision off', vim.log.levels.INFO, {
                title = " Marksman " .. config.options.night_vision.virtual_text,
                timeout = 500
            })
        end
    -- Toggle on
    else
        apply_marks_to_buffer(bufnr, true)
        if not config.options.night_vision.silent then
            vim.notify(' Night Vision on', vim.log.levels.INFO, {
                title = " Marksman " .. config.options.night_vision.virtual_text,
                timeout = 500
            })
        end
    end
    M.nv_state[bufnr] = not M.nv_state[bufnr]
end

--- Refresh Night Vision display in current buffer
--- Reapplies all marks, highlights, signs, and virtual text
--- @return nil
function M.refresh()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Initialize buffer signs tracking if needed
    if not buffer_signs[bufnr] then
        buffer_signs[bufnr] = {}
    end

    apply_marks_to_buffer(bufnr, true)
    M.nv_state[bufnr] = true
end

-- Function to apply Night Vision to current buffer (without toggling global state)
--- @return nil
local function apply_night_vision_to_buffer()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Early exit if buffer should be excluded
    if exclude_buffer(bufnr) then
        return
    end

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

    apply_marks_to_buffer(bufnr, true)
end

-- Auto-apply Night Vision to new buffers when they're opened
vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
    callback = function()
        local bufnr = vim.api.nvim_get_current_buf()
        -- Small delay to ensure marks are loaded
        vim.defer_fn(function()
            -- Check if current buffer should be excluded
            if not exclude_buffer(bufnr) then
                apply_night_vision_to_buffer()
            end
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
M.apply_marks_to_buffer = apply_marks_to_buffer

return M
