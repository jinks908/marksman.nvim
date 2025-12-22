-- lua/marksman/data.lua

local M = {}
local fn = vim.fn
local json = vim.json

-- Store timestamps internally
M.timestamps = {}

-- Track if we've already notified about save errors this session
local save_error_notified = false

-- Get data directory for storing the JSON file
-- Defaults to ~/.local/share/nvim/marksman
local function get_data_dir()
    local data_dir = fn.stdpath('data') .. '/marksman'
    -- Create directory if it doesn't exist
    if fn.isdirectory(data_dir) == 0 then
        local success = fn.mkdir(data_dir, 'p')
        if success == 0 then
            vim.notify("Marksman: Failed to create data directory " .. data_dir, vim.log.levels.WARN)
        end
    end
    return data_dir
end

-- Get JSON file path for current buffer
local function get_timestamp_file()
    local bufname = fn.expand('%:p')
    if bufname == '' then return nil end

    -- Create a unique filename based on the buffer path
    local hash = fn.sha256(bufname)
    return string.format('%s/%s.json', get_data_dir(), hash)
end

-- Modified save function
function M.save_timestamps()
    local file_path = get_timestamp_file()
    if not file_path then
        return
    end

    -- Create data structure with metadata
    local data = {
        buffer_path = fn.expand('%:p'),
        last_updated = os.time(),
        timestamps = M.timestamps  -- Use internal timestamps table
    }

    -- Write to file with error handling
    local file, err = io.open(file_path, 'w')
    if not file then
        -- Notify user only once per session to avoid spam
        if not save_error_notified then
            vim.notify("Marksman: Failed to save timestamps - " .. (err or "unknown error"), vim.log.levels.ERROR)
            save_error_notified = true
        end
        return
    end

    local success, write_err = pcall(function()
        file:write(json.encode(data))
        file:close()
    end)

    if not success then
        if not save_error_notified then
            vim.notify("Marksman: Failed to write timestamp data - " .. (write_err or "unknown error"), vim.log.levels.ERROR)
            save_error_notified = true
        end
    end
end

-- Modified load function
function M.load_timestamps()
    local file_path = get_timestamp_file()
    if not file_path or fn.filereadable(file_path) == 0 then
        M.timestamps = {}  -- Reset internal timestamps
        return
    end

    -- Read file with error handling
    local file, err = io.open(file_path, 'r')
    if not file then
        vim.notify("Marksman: Failed to read timestamp file - " .. (err or "unknown error"), vim.log.levels.WARN)
        M.timestamps = {}
        return
    end

    local content, read_err = file:read('*all')
    file:close()

    if not content then
        vim.notify("Marksman: Failed to read timestamp file contents - " .. (read_err or "unknown error"), vim.log.levels.WARN)
        M.timestamps = {}
        return
    end

    local success, data = pcall(json.decode, content)
    if not success then
        vim.notify("Marksman: Timestamp file corrupted, resetting timestamps", vim.log.levels.WARN)
        M.timestamps = {}
        return
    end

    -- Verify the data is for the current buffer
    if data.buffer_path == fn.expand('%:p') then
        M.timestamps = data.timestamps
    else
        M.timestamps = {}
    end
end

-- Add timestamp for a mark
function M.add_timestamp(mark)
    M.timestamps[mark] = os.time()
    M.save_timestamps()
end

-- Remove timestamp for a mark
function M.remove_timestamp(mark)
    M.timestamps[mark] = nil
    M.save_timestamps()
end

-- Get timestamp for a mark
function M.get_timestamp(mark)
    return M.timestamps[mark] or 0
end

-- Clear all timestamps
function M.clear_timestamps()
    M.timestamps = {}
    M.save_timestamps()
end

-- Remove files older than 30 days
function M.cleanup_timestamp_files()
    local data_dir = get_data_dir()
    local files = vim.fn.glob(data_dir .. '/*.json', false, 1)
    local current_time = os.time()

    -- Handle glob returning empty result
    if not files or #files == 0 then
        return
    end

    for _, file in ipairs(files) do
        local file_time = vim.fn.getftime(file)
        if file_time == -1 then
            vim.notify("Marksman: Failed to get timestamp for file " .. file, vim.log.levels.WARN)
        elseif current_time - file_time > 30 * 24 * 60 * 60 then
            local success, err = pcall(vim.fn.delete, file)
            if not success then
                vim.notify("Marksman: Failed to delete old timestamp file " .. file .. " - " .. (err or "unknown error"), vim.log.levels.WARN)
            end
        end
    end
end

return M
