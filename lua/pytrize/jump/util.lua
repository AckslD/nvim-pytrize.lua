local M = {}

M.open_file = function(file)
    vim.cmd('edit ' .. file)
end

return M
