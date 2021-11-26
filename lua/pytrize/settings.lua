local M = {}

local warn = require('pytrize.warn').warn

-- defaults
M.settings = {
    no_commands = false,
    highlight = 'LineNr',
}

M.update = function(opts)
    for k, v in pairs(opts) do
        if M.settings[k] == nil then
            warn("unexpected setting " .. k)
        else
            M.settings[k] = v
        end
    end
end

return M
