local M = {}

local settings = require('pytrize.settings').settings
local warn = require('pytrize.warn').warn

local function get_nui_handler()
    return require('pytrize.input.nui').load()
end

local function get_telescope_handler()
    return require('pytrize.input.telescope').load()
end

local function get_builtin_handler()
    return require('pytrize.input.builtin').load()
end

local handler_getters = {
    nui = get_nui_handler,
    telescope = get_telescope_handler,
    builtin = get_builtin_handler,
}

local function get_input_handler()
    if handler_getters[settings.preferred_input] == nil then
        warn(string.format('unknown input choice "%s"', settings.preferred_input))
        return
    end
    local handler = handler_getters[settings.preferred_input]()
    if handler ~= nil then
        return handler
    end
    for _, handler_getter in pairs(handler_getters) do
        handler = handler_getter()
        if handler ~= nil then
            return handler
        end
    end
end

M.prompt_files = function(files)
    local handler = get_input_handler()
    local prompt = 'Multiple files found for the nodeid under cursor, pick the correct one:'
    return handler.prompt_files(prompt, files)
end

return M
