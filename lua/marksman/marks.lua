--- lua/marksman/marks.lua
---
--- Mark management module for Marksman
---
--- Handles all mark-related operations including:
---   - Setting and deleting marks (a-z)
---   - Retrieving marks with metadata (line number, content, timestamp)
---   - Sorting marks by different criteria (line, alphabetical, recency)
---   - Integrating with Night Vision visual feedback
---   - Notifying user on mark operations (optional)
---
--- Public API:
---   - set_mark(letter): Set mark at current cursor position
---   - auto_mark(): Auto-assign next available mark letter (a-z)
---   - toggle_mark(): Toggle mark on current line (auto-set/delete)
---   - next_mark(forward): Jump to next or previous mark
---   - delete_mark(): Delete mark on current line
---   - delete_by_letter(letter): Delete specific mark by letter
---   - delete_all_marks(): Clear all marks in current buffer
---   - get_marks(): Get all marks with metadata, sorted by config preference

local M = {}
local config = require('marksman.config')
local data = require('marksman.data')

-- Reference to night_vision module
local night_vision

-- init() gets called after modules are loaded
function M.init()
    night_vision = require('marksman.night_vision')
end

-- Helper function to safely get config options
local function get_config_options()
    return config.options or config.defaults
end

-- Helper function to map builtin mark types to native symbols
local function get_builtin_mark_type(mark)
    local types = {
        ["last_change"] = ".",
        ["last_insert"] = "^",
        ["visual_start"] = "<",
        ["visual_end"] = ">",
        ["last_jump_line"] = "'",
        ["last_jump"] = "`",
        ["last_exit"] = '"',
    }
    return types[mark] or "unknown"
end

-- Helper function to get builtin marks
--- @return table List of marks with structure: {mark=symbol, sign=icon, lnum=number, display=string, builtin=boolean, type=string}
M.get_builtin_marks = function()
    if not config.options.night_vision.enabled then
        return {}
    end

    local builtin_marks = {}
    -- Get enabled marks
    local show_signs = config.options.builtin_marks.show_signs

    for type, sign in pairs(show_signs) do
        local symbol = get_builtin_mark_type(type)
        local pos = vim.fn.getpos("'" .. symbol)
        -- Check if mark is in current buffer and valid
        if pos[1] == 0 and pos[2] > 0 then
            local line_content = vim.api.nvim_buf_get_lines(0, pos[2]-1, pos[2], false)[1] or tostring(type)

            table.insert(builtin_marks, {
                -- NOTE: Use 'symbol' as mark identifier and 'sign' for custom display
                mark = symbol,
                sign = sign,
                lnum = pos[2],
                display = line_content:gsub('^%s*', ''),
                builtin = true,
                type = type
            })
        end
    end

    -- Sort (builtin marks would appear in position order)
    table.sort(builtin_marks, function(a, b)
        return a.lnum < b.lnum
    end)

    return builtin_marks
end


--- Get all marks in current buffer with metadata
--- Returns marks sorted by configured method (line, alphabetical, or recency)
--- @return table List of marks with structure: {mark=letter, lnum=number, display=string, timestamp=number}
function M.get_marks()
    -- Re-initialize marks_list on refresh
    local marks_list = {}
    local bufnr = vim.api.nvim_get_current_buf()
    -- Get marks for the current buffer
    local current_marks_list = vim.fn.getmarklist(bufnr)

    -- Handle empty list
    if #current_marks_list < 1 then
        vim.notify(' No marks for current buffer', vim.log.levels.WARN)
    end

    -- Iterate through marks list (dictionary)
    for _, mark in ipairs(current_marks_list) do
        -- Filter for lowercase non-alphabetical marks
        if mark.mark:match("'[a-z]+") then
            local line_content
            -- Skip over invalid marks (otherwise will throw out-of-range error)
            if vim.api.nvim_buf_get_lines(bufnr, mark.pos[2]-1, mark.pos[2], false)[1] == nil then
            else
                -- Get the content of the line
                line_content = vim.api.nvim_buf_get_lines(bufnr, mark.pos[2]-1, mark.pos[2], false)[1]
                table.insert(marks_list, {
                    -- Extract letter only
                    mark = mark.mark:sub(2),
                    lnum = mark.pos[2],
                    -- Strip leading whitespace for marked line
                    display = line_content:gsub('^%s*', ''),
                    timestamp = data.get_timestamp(mark.mark:sub(2)) or 0,
                })
            end
        end
    end

    -- Add builtin marks if enabled
    if config.options.builtin_marks.enabled then
        local builtin = M.get_builtin_marks()
        for _, mark in ipairs(builtin) do
            table.insert(marks_list, mark)
        end
    end

    -- Get config options safely
    local options = get_config_options()

    -- Sort marks based on user config
    if options.night_vision.sort_by == "alphabetical" then
        -- Sort marks by alphabetical order
        table.sort(marks_list, function(a, b)
            return a.mark < b.mark
        end)
    elseif options.night_vision.sort_by == "recency" then
        -- Sort marks by recency
        table.sort(marks_list, function(a, b)
            return a.timestamp > b.timestamp
        end)
    else
        -- Sort marks by line number (default)
        table.sort(marks_list, function(a, b)
            return a.lnum < b.lnum
        end)
    end

    return marks_list
end

-- Function to get the first available mark
local function get_first_available_mark()
    local used_marks = {}
    local current_marks_list = vim.fn.getmarklist(vim.api.nvim_get_current_buf())

    -- Collect all used marks
    for _, mark in ipairs(current_marks_list) do
        if mark.mark:match("'[a-z]+") then
            used_marks[mark.mark:sub(2)] = true
        end
    end

    -- Find first unused mark
    for i = 97, 122 do
        local ch = string.char(i)
        if not used_marks[ch] then
            return ch
        end
    end
    return nil
end

--- Set a mark at the current cursor position
--- @param letter string Single lowercase letter (a-z) to use as mark
--- @return nil
--- @see auto_mark to auto-assign mark to current line
--- @see delete_mark to remove mark from current line
--- @see toggle_mark to toggle mark on current line
M.set_mark = function(letter)
    local line_num = vim.api.nvim_win_get_cursor(0)[1]

    if not letter or #letter ~= 1 or not letter:match('[a-z]') then
        vim.notify("Invalid mark letter: must be single lowercase a-z", vim.log.levels.ERROR)
        return
    end

    vim.cmd("normal! m" .. letter)
    data.add_timestamp(letter)
    if night_vision and night_vision.nv_state then
        night_vision.refresh()
    end
    local options = get_config_options()
    if not options.night_vision.silent then
        vim.notify(" Line " .. line_num .. " marked as '" .. letter .. "'", vim.log.levels.INFO, { title = " Marksman  " })
    end
end

--- Auto-assign the next available mark letter at current cursor position
--- Searches for first unused letter from a-z
--- @return nil
--- @see set_mark to set mark from current line
--- @see auto_mark to auto-assign mark to current line
--- @see toggle_mark to toggle mark on current line
M.auto_mark = function()
    local free_mark = get_first_available_mark()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    -- If no available marks, return
    if not free_mark then
        vim.notify(' There are no available marks', vim.log.levels.ERROR, { title = " Marksman  " })
        return
    end
    -- Otherwise mark current line
    vim.cmd("normal! m" .. free_mark)
    data.add_timestamp(free_mark)
    if night_vision and night_vision.nv_state then
        -- Refresh Night Vision if enabled
        night_vision.refresh()
    end
    local options = get_config_options()
    if not options.night_vision.silent then
        vim.notify(" Line " .. line_num .. " marked as '" .. free_mark .. "'", vim.log.levels.INFO, { title = " Marksman  " })
    end
end

-- Toggle mark on current line
--- @return nil
--- @see set_mark to set mark from current line
--- @see delete_mark to delete mark on current line
--- @see auto_mark to auto-assign mark to current line
M.toggle_mark = function()
    local line = vim.fn.line('.')
    local marks = M.get_marks()

    for _, mark in ipairs(marks) do
        if mark.lnum == line then
            M.delete_mark()
            return
        end
    end
    M.auto_mark()
end

--- Jump to next or previous mark in current buffer
--- Wraps around at edges (loops from last to first or vice versa)
--- @param forward boolean true to jump forward, false to jump backward
--- @return nil
M.next_mark = function(forward)
    local current_line = vim.fn.line('.')
    local current_marks = M.get_marks()

    -- If no marks, exit
    if #current_marks < 1 then
        vim.notify(' No marks in current buffer', vim.log.levels.WARN)
        return true
    -- If cursor is on the only mark, notify
    elseif #current_marks == 1 and current_marks[1].lnum == current_line then
        vim.notify(' No other marks in current buffer', vim.log.levels.INFO)
    else
        if forward then
            -- Search forward for next mark
            for i = 1, #current_marks do
                if current_marks[i].lnum <= current_line then
                    i = i + 1
                else
                    -- Auto-center cursor on mark
                    vim.cmd("normal! `" .. current_marks[i].mark .. "zz")
                    return true
                end
            end
            -- If no next mark is found, loop back to first mark
            vim.cmd("normal! `" .. current_marks[1].mark .. "zz")
            return true
        else
            -- Search backward for previous mark
            for i = #current_marks, 1, -1 do
                if current_marks[i].lnum >= current_line then
                else
                    -- Auto-center cursor on mark
                    vim.cmd("normal! `" .. current_marks[i].mark .. "zz")
                    return true
                end
            end
            -- If no previous mark is found, loop back to last mark
            vim.cmd("normal! `" .. current_marks[#current_marks].mark .. "zz")
            return true
        end
    end
end

--- Delete the mark on the current line
--- @return nil
--- @see set_mark to set mark from current line
--- @see auto_mark to auto-assign mark to current line
--- @see toggle_mark to toggle mark on current line
M.delete_mark = function()
    local current_line = vim.fn.line('.')
    local current_marks = M.get_marks()

    -- If no marks, exit
    if #current_marks < 1 then
        return true
    end

    -- Search for mark on current line
    for i = 1, #current_marks do
        if current_marks[i].lnum == current_line then
            -- Delete mark
            vim.cmd("delmark " .. current_marks[i].mark)
            data.remove_timestamp(current_marks[i].mark)
            local options = get_config_options()
            if not options.night_vision.silent then
                vim.notify(" Mark '" .. current_marks[i].mark .. "' deleted", vim.log.levels.INFO, { title = " Marksman  " })
            end
            -- Refresh Night Vision if enabled
            if night_vision and night_vision.nv_state then
                night_vision.refresh()
            end
            return true
        end
    end
    -- If no mark is found on current line, notify
    vim.notify(' No mark on current line', vim.log.levels.WARN, { title = " Marksman  " })
end

--- Delete a specific mark by letter
--- @param letter string Mark letter (a-z) to delete
--- @return nil
M.delete_by_letter = function(letter)
    local current_marks = M.get_marks()
    for i = 1, #current_marks do
        if current_marks[i].mark == letter then
            vim.cmd("delmark " .. letter)
            data.remove_timestamp(letter)
            local options = get_config_options()
            if not options.night_vision.silent then
                vim.notify(" Mark '" .. letter .. "' deleted", vim.log.levels.INFO, { title = " Marksman  " })
            end
            -- Refresh Night Vision if enabled
            if night_vision and night_vision.nv_state then
                night_vision.refresh()
            end
            return true
        end
    end
    vim.notify(" Mark '" .. letter .. "' not set.", vim.log.levels.WARN, { title = " Marksman  " })
end

--- Delete all marks in the current buffer
--- Also clears all stored timestamps for marks in this buffer
--- @return nil
M.delete_all_marks = function()
    -- Delete all lowercase (local) marks
    vim.cmd('delmarks a-z')
    data.clear_timestamps()
    if night_vision and night_vision.nv_state then
        night_vision.refresh()
    end
end

return M
