local M = {}
local handler = {}
local actions
local action_state
local pickers
local finders
local conf

M.load = function()
    local has_telescope
    has_telescope, _ = pcall(require, "telescope")
    if has_telescope then
        actions = require("telescope.actions")
        action_state = require("telescope.actions.state")
        pickers = require "telescope.pickers"
        finders = require "telescope.finders"
        conf = require("telescope.config").values
        return handler
    else
        return nil
    end
end

handler.prompt_files = function(prompt, files, callback)
    local find_command = {'ls'}
    for _, file in ipairs(files) do
        table.insert(find_command, file)
    end
    local opts = {}
    pickers.new(opts, {
        prompt_title = prompt,
        finder = finders.new_oneshot_job(find_command, opts),
        previewer = conf.file_previewer(opts),
        sorter = conf.file_sorter(opts),
        attach_mappings = function(_, map)
            local key_func = function(prompt_bufnr)
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                callback(entry.value)
            end
            map('i', '<CR>', key_func)
            map('n', '<CR>', key_func)
            return true
        end,
    }):find()
end

return M
