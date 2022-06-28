local M = {}

M.warn = function(msg)
    msg = vim.fn.escape(msg, '"'):gsub('\\n', '\n')
    -- vim.cmd(string.format('echohl WarningMsg | echo "Pytrize Warning: %s" | echohl None', msg))
    vim.notify(vim.split(string.format("Pytrize Warning: %s", msg), '\n'), vim.log.levels.WARN)
end

return M
