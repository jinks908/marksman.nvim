--- lua/marksman/night_vision.lua
---
--- Night Vision visual feedback module for Marksman plugin
---
--- Handles real-time visual highlighting of marked lines:
---   - Line background highlighting
---   - Line number highlighting
---   - Mark letters/icons in the gutter
---   - Decorative virtual text icons (smart icon toggling based on cursor position)
---
--- Features:
---   - Per-buffer state management (independent Night Vision per window)
---   - Smart icon toggling: icons hide when cursor on line, show when away
---   - Smooth updates on cursor movement
---   - Automatic application to new buffers
---   - Clean removal of signs when toggling off
---
--- Public API:
---   - toggle(): Toggle Night Vision on/off for current buffer
---   - refresh(): Refresh Night Vision display in current buffer
---   - update_virtual_text_for_cursor(): Update virtual text based on cursor position
---   - setup_highlights(): Configure highlight groups for Night Vision

local M = {}
local config = require('marksman.config')
local marks = require('marksman.marks')

M.mark_lines = {}

-- State management
M.nv_state = {}

-- Create new namespace
local ns_id = vim.api.nvim_create_namespace('Marksman')
local ns_id_vt = vim.api.nvim_create_namespace('MarksmanVT')

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
    for _, mark in ipairs(current_marks) do
        if is_valid_line(bufnr, mark.lnum) then
            -- Hide icon when cursor is on a marked line
            local virt_text_content = ''
            local cursor_is_on = (current_cursor == mark.lnum)
            -- Show icon when cursor is NOT on a marked line
            if not cursor_is_on then
                virt_text_content = config.options.night_vision.virtual_text
            end

            if config.options.night_vision.virtual_text == "letter" then
                virt_text_content = mark.mark .. ' '
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

--- Setup highlight groups for Night Vision
--- @return nil
function M.setup_highlights()
    local options = get_config_options()
    vim.api.nvim_set_hl(0, 'MarksmanMark', options.highlights.mark)
    vim.api.nvim_set_hl(0, 'MarksmanMarkSelected', options.highlights.mark_selected)
    vim.api.nvim_set_hl(0, 'MarksmanLine', options.highlights.line_nr)
    vim.api.nvim_set_hl(0, 'NightVision', options.night_vision.highlights.line)
    vim.api.nvim_set_hl(0, 'NightVisionLineNr', options.night_vision.highlights.line_nr)
    vim.api.nvim_set_hl(0, 'NightVisionVirtualText', options.night_vision.highlights.virtual_text)
end

--- Update virtual text decorations based on cursor position
--- Hides icons when cursor is on a marked line, shows them when cursor is away
--- @return nil
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
            local virt_text_content = cursor_is_on and '' or config.options.night_vision.virtual_text

            -- Delete old extmark if it exists
            local old_id = vt_extmark_ids[bufnr][mark.lnum]
            if old_id then
                pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id_vt, old_id)
            end

            if config.options.night_vision.virtual_text == "letter" and not cursor_is_on then
                virt_text_content = mark.mark .. ' '
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


--- Toggle Night Vision on/off for current buffer
--- @return nil
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
                    title = " Marksman " .. config.options.night_vision.virtual_text,
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
                if options.night_vision.sign_column ~= "none" then
                    if options.night_vision.sign_column == "letter" then
                        local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                            {
                                sign_text = mark.mark,
                                sign_hl_group = "NightVisionLineNr",
                                priority = 5000
                            })
                        buffer_signs[bufnr][extmark_id] = true
                    else
                        local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                            {
                                sign_text = options.night_vision.sign_column,
                                sign_hl_group = "NightVisionLineNr",
                                priority = 5000
                            })
                        buffer_signs[bufnr][extmark_id] = true
                    end
                end
                -- Set up virtual text for all marked lines
                if options.night_vision.virtual_text ~= "" then
                    refresh_all_virtual_text()
                end
            end
        end

        if not options.night_vision.silent then
            -- Notify user
            vim.notify(' Night Vision on', vim.log.levels.INFO,
                {
                    title = " Marksman " .. config.options.night_vision.virtual_text,
                    timeout = 500
                })
        end
    end
    M.nv_state[bufnr] = not M.nv_state[bufnr]
end

--- Refresh Night Vision display in current buffer
--- Reapplies all marks, highlights, and decorations
--- @return nil
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
            if options.night_vision.sign_column ~= "none" then
                if options.night_vision.sign_column == "letter" then
                    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                        {
                            sign_text = mark.mark,
                            sign_hl_group = "NightVisionLineNr",
                            priority = 5000
                        })
                    buffer_signs[bufnr][extmark_id] = true
                else
                    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                        {
                            sign_text = options.night_vision.sign_column,
                            sign_hl_group = "NightVisionLineNr",
                            priority = 5000
                        })
                    buffer_signs[bufnr][extmark_id] = true
                end
            end
            -- Set up virtual text for all marked lines
            if options.night_vision.virtual_text ~= "" then
                refresh_all_virtual_text()
            end
        end
    end

    M.nv_state[bufnr] = true
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
            if options.night_vision.sign_column ~= "none" then
                if options.night_vision.sign_column == "letter" then
                    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                        {
                            sign_text = mark.mark,
                            sign_hl_group = "NightVisionLineNr",
                            priority = 5000
                        })
                    buffer_signs[bufnr][extmark_id] = true
                else
                    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.lnum - 1, 0,
                        {
                            sign_text = options.night_vision.sign_column,
                            sign_hl_group = "NightVisionLineNr",
                            priority = 5000
                        })
                    buffer_signs[bufnr][extmark_id] = true
                end
            end
            -- Set up virtual text for all marked lines
            if options.night_vision.virtual_text ~= "" then
                refresh_all_virtual_text()
            end
        end
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
