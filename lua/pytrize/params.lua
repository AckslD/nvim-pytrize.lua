local M = {}

local paths = require('pytrize.paths')
local nids = require('pytrize.nodeids')
local warn = require('pytrize.warn').warn

M.get_values = function(param_order, bufnr)
    local rootdir, file = paths.split_at_root(vim.api.nvim_buf_get_name(bufnr))
    if rootdir == nil then
        return
    end
    local nodeids = nids.get(rootdir)
    if nodeids[file] == nil then
        warn("no pytest cache for file " .. file .. " at root dir " .. rootdir)
        return
    end
    local values_per_func = {}
    for func_name, local_nids in pairs(nodeids[file]) do
        local unique_values_per_param = {}
        local ordered_values_per_param = {}
        for _, values in ipairs(local_nids) do
            local i = 1  -- TODO how do you loop over range?
            while i <= #param_order do
                local param = param_order[i]
                local value = values[i]
                if unique_values_per_param[param] == nil then
                    unique_values_per_param[param] = {}
                end
                if ordered_values_per_param[param] == nil then
                    ordered_values_per_param[param] = {}
                end
                if not unique_values_per_param[param][value] then
                    unique_values_per_param[param][value] = true
                    table.insert(ordered_values_per_param[param], value)
                end
                i = i + 1
            end
        end
        values_per_func[func_name] = ordered_values_per_param
    end
    return values_per_func
end

M.get_id = function(param_values, params, i)
    local ids = {}
    for _, param in ipairs(params) do
        local values = param_values[param]
        local param_value
        if i > #values then
            param_value = values[#values]
        else
            param_value = values[i]
        end
        table.insert(ids, param_value)
    end
    return '[' .. table.concat(ids, '-') .. ']'
end

return M
