local M = {}

local settings = require('pytrize.settings')

local function setup_commands()
    vim.cmd('command Pytrize lua require("pytrize.api").set()')
    vim.cmd('command PytrizeClear lua require("pytrize.api").clear()')
    vim.cmd('command PytrizeJump lua require("pytrize.api").jump()')
end

M.setup = function(opts)
    if opts == nil then
        opts = {}
    end
    settings.update(opts)
    if not settings.settings.no_commands then
        setup_commands()
    end
end

return M
