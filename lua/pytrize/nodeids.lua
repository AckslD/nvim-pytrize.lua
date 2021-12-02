local M = {}

local get_nodeids_path = require('pytrize.paths').get_nodeids_path

local function get_raw_nodeids(rootdir)
    local nodeids_path = get_nodeids_path(rootdir)
    return vim.fn.json_decode(vim.fn.readfile(nodeids_path))
end

M.parse_raw = function(raw_nodeid)
        local file
        local func_name
        local rest
        file, rest = unpack(vim.fn.split(raw_nodeid, '::'))
        if rest == nil then
            return
        end
        func_name, rest = unpack(vim.fn.split(rest, '['))
        if rest == nil then
            return
        end
        rest = rest:sub(1, -2)
        local params = vim.fn.split(rest, '-')
        return {
            file = file,
            func_name = func_name,
            params = params,
        }
end

M.get = function(rootdir)
    local nodeids = {}
    for _, raw_nodeid in ipairs(get_raw_nodeids(rootdir)) do
        local nodeid = M.parse_raw(raw_nodeid)
        if nodeid ~= nil then
            if nodeids[nodeid.file] == nil then
                nodeids[nodeid.file] = {}
            end
            if nodeids[nodeid.file][nodeid.func_name] == nil then
                nodeids[nodeid.file][nodeid.func_name] = {}
            end
            table.insert(nodeids[nodeid.file][nodeid.func_name], nodeid.params)
        end
    end
    return nodeids
end

return M
