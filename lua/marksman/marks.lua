-- lua/marksman/marks.lua

local M = {}
local config = require('marksman.config')
local data = require('marksman.data')

-- Instead of requiring night_vision, we'll use a reference to it
local night_vision

-- Add an init function that gets called after all modules are loaded
function M.init()
    night_vision = require('marksman.night_vision')
end

-- Helper function to safely get config options
local function get_config_options()
    return config.options or config.defaults
end

-- Get all marks in current buffer, sorted by configured method
-- @return {table} List of marks with structure: {mark, lnum, display, timestamp}
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

-- Set mark manually (using native 'm' command)
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

-- Function to auto-mark current line
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

-- Function to jump to next/previous mark
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

-- Function to auto-delete mark on current line
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

-- Delete Mark by Letter 
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

-- Function to delete all local marks in current buffer
M.delete_all_marks = function()
    -- Delete all lowercase (local) marks
    vim.cmd('delmarks a-z')
    data.clear_timestamps()
    if night_vision and night_vision.nv_state then
        night_vision.refresh()
    end
end

return M
