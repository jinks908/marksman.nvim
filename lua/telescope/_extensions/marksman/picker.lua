-- lua/telescope/_extensions/marksman/picker.lua

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local config = require('marksman.config')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local marks = require('marksman.marks')
local night_vision = require('marksman.night_vision')

local M = {}

-- Create Telescope picker
function M.marks(opts, mode)
    local current_file = vim.api.nvim_buf_get_name(0)
    local bufnr = vim.api.nvim_get_current_buf()

    local current_marks_list = marks.get_marks()

    -- Handle empty marks list
    if #marks.get_marks() < 1 then
        vim.notify(' No marks in current buffer', vim.log.levels.WARN)
        return true
    end
    -- Set initial mode for picker (insert/normal)
    mode = mode or { "normal" }
    local start_mode = tostring(table.concat(mode))

    -- Load custom highlight groups
    night_vision.setup_highlights()

    -- Save default TelescopeSelection highlight
    local original_selection = vim.api.nvim_get_hl(0, { name = 'TelescopeSelection' })
    -- Override TelescopeSelection for Marksman picker
    vim.api.nvim_set_hl(0, 'TelescopeSelection', config.options.highlights.mark_selected)

    -- Get default/user config options
    opts = vim.tbl_deep_extend("force", config.options, opts or {})

    -- Get picker keymaps
    local picker_km = config.options.keymaps.picker

    pickers.new(opts, {
        initial_mode = start_mode,
        prompt_title = "Goto Mark",
        preview_title = "Current File",
        results_title = "Marksman  ",
        layout_config = opts.layout_config,
        finder = finders.new_table({
            results = marks.get_marks(),
            entry_maker = function(entry)
                -- Calculate maximum line number width (for highlighting)
                local max_lnum = 0
                for _, mark in ipairs(current_marks_list) do
                    max_lnum = math.max(max_lnum, mark.lnum)
                end
                local lnum_width = #tostring(max_lnum)

                -- Set display widths
                local displayer = require("telescope.pickers.entry_display").create({
                    separator = " ",
                    items = {
                        { width = 1 },           -- Mark
                        { width = lnum_width },  -- Line number
                        { remaining = true },    -- Line content
                    },
                })

                -- Format display entries
                local make_display = function(entry_tb)
                    local mark_hl, lnum_hl, mark

                    -- Determine highlight groups based on mark type
                    if entry_tb.value.builtin then
                        -- Display custom sign for builtin marks
                        mark = entry_tb.value.sign
                        mark_hl = "BuiltinMark_" .. entry_tb.value.type
                        lnum_hl = "BuiltinMark_" .. entry_tb.value.type
                    else
                        mark = entry_tb.value.mark
                        mark_hl = "MarksmanMark"
                        lnum_hl = "MarksmanLine"
                    end

                    return displayer({
                        { mark, mark_hl },
                        { tostring(entry_tb.value.lnum), lnum_hl },
                        entry_tb.value.display,
                    })
                end

                -- Return table to entry_maker
                return {
                    value = entry,
                    display = make_display,
                    -- Set ordinal to display (line content) for filtering in insert mode
                    ordinal = entry.display,
                    filename = current_file,
                    bufnr = bufnr,
                    lnum = entry.lnum,
                }
            end
        }),
        -- Use default sorter, previewer
        sorter = conf.generic_sorter(opts),
        previewer = conf.grep_previewer({}),

        attach_mappings = function(prompt_bufnr, map)

            -- Helper function to determine if mark exists
            local function isMark(value)
                local marked = "false"
                for _, letter in ipairs(current_marks_list) do
                    if (letter.mark == value) then
                        marked = "true"
                    end
                end
                return marked
            end

            -- Function to jump to mark
            local function goto_mark(mark_letter)
                if isMark(mark_letter) == "true" then
                    actions.close(prompt_bufnr)
                    vim.cmd("normal! `" .. mark_letter)
                    vim.cmd("normal! zz")
                else
                    actions.close(prompt_bufnr)
                    vim.notify(" Mark '" .. mark_letter .. "' not set.", vim.log.levels.WARN, { title = " Marksman  " })
                end
            end

            -- Default action for selecting entry with <Enter>
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                goto_mark(selection.value.mark)
            end)

            -- Override default normal mode mappings
            -- Note: Because we're hijacking k/l for mark jumps, we need to use <C-k>/<C-l>
            -- for normal mode navigation as well as <C-d> for deleting marks
            map("n", "k", function() return false end)
            map("n", "l", function() return false end)
            map("n", "j", function() return false end)
            map("n", picker_km.delete_mark, function() return false end)
            map("n", picker_km.prev_item, function() return false end)
            map("n", picker_km.next_item, function() return false end)

            -- Create normal mode hotkey mappings (i.e., pressing mark letter jumps to mark)
            for i = 97, 122 do
                local key = string.char(i)
                vim.keymap.set('n', key, function() goto_mark(key) end, { buffer = prompt_bufnr, noremap = true, silent = true })
            end

            -- Standard Mappings
            local maps = {
                n = {
                    [picker_km.next_item] = function() actions.move_selection_next(prompt_bufnr) end,
                    [picker_km.prev_item] = function() actions.move_selection_previous(prompt_bufnr) end,
                    ["<CR>"] = function()
                        local selection = action_state.get_selected_entry()
                        goto_mark(selection.value.mark)
                    end,
                    -- Delete selected mark
                    [picker_km.delete_mark] = function()
                        local selection = action_state.get_selected_entry()
                        actions.close(prompt_bufnr)
                        vim.cmd("delmark " .. selection.value.mark)
                        vim.notify(" Mark '" .. selection.value.mark .. "' deleted", vim.log.levels.INFO, { title = " Marksman  " })
                        if M.nv_state then
                            -- Refresh Night Vision if enabled
                            night_vision.refresh()
                        end
                        -- Reopen marks picker
                        vim.schedule(M.marks)
                    end,
                    -- Switch to "insert" mode
                    [picker_km.insert_mode] = function()
                        actions.move_to_top(prompt_bufnr)
                        vim.cmd("startinsert!")
                    end,
                },
            }
            -- Apply standard mappings
            ---@diagnostic disable-next-line: redefined-local
            for mode, mode_mappings in pairs(maps) do
                for key, action in pairs(mode_mappings) do
                    vim.keymap.set(mode, key, action, { buffer = prompt_bufnr, noremap = true })
                end
            end

            -- Restore original TelescopeSelection when picker closes
            vim.api.nvim_create_autocmd('BufLeave', {
                buffer = prompt_bufnr,
                once = true,
                callback = function()
                    ---@diagnostic disable-next-line: param-type-mismatch
                    vim.api.nvim_set_hl(0, 'TelescopeSelection', original_selection)
                end
            })

            return true
        end
    }):find()
end

return M
