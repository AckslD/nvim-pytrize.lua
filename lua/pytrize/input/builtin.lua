local M = {}
local handler = {}

handler.prompt_files = function(prompt, files)
    local textlist = {prompt}
    for i, file in ipairs(files) do
        table.insert(textlist, string.format('%d. %s', i, file))
    end
    local choice = vim.fn.inputlist(textlist)
    return files[choice]
end

M.load = function()
    return handler
end

return M
