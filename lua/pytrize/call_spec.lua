local M = {}

local ts = vim.treesitter
local ts_utils = require('nvim-treesitter.ts_utils')
local ts_query = ts.query
local reverse = require('pytrize.tables').reverse
local warn = require('pytrize.warn').warn

local function get_root()
    local parser = ts.get_parser()
    local tstree = parser:parse()[1]
    return tstree:root()
end

local function get_param_call_nodes()
    local tsroot = get_root()
    local query = ts_query.parse_query(
        'python',
        '(call function: (attribute) @param) (#eq? @param "pytest.mark.parametrize")'
    )
    local nodes = {}
    for _, node, _ in query:iter_captures(tsroot) do
        table.insert(nodes, node:parent())
    end
    return nodes
end

M.get = function()
    local calls = get_param_call_nodes()
    local call_specs = {}
    local param_order = {}
    for _, call in ipairs(calls) do
        -- Move to separate func, better way?
        local decorated_definition = call:parent():parent()
        if decorated_definition:type() ~= 'decorated_definition' then
            warn("couldn't parse params")
            return
        end
        local func = decorated_definition:field('definition')[1]
        local func_name = ts_utils.get_node_text(func:field('name')[1])[1]

        local arguments = call:field('arguments')[1]
        local params_node = arguments:child(1)
        if params_node:type() ~= 'string' then
            warn("couldn't parse params")
            return
        end
        local params_str = ts_utils.get_node_text(params_node)[1] -- TODO multiline strings?
        params_str = params_str:sub(2, -2)
        local params = vim.fn.split(params_str, [[,\s*]])  -- TODO avoid vim script?
        table.insert(call_specs, {
            call_node = call,
            params = params,
            func_name = func_name,
        })
        for _, param in ipairs(reverse(params)) do
            table.insert(param_order, param)
        end
    end
    return reverse(param_order), call_specs
end

M.has_param = function(call_spec, param)
    for _, p in ipairs(call_spec.params) do
        if p == param then
            return true
        end
    end
    return false
end

local non_entry_types = {
    ['comment'] = true,
    -- TODO why are these even entry types?
    ['['] = true,
    [','] = true,
    [']'] = true,
}

M.get_second_arg_node = function(call_node)
    local arguments = call_node:field('arguments')[1]
    return arguments:child(3)
end

M.list_entries = function(call_node)
    local entry_nodes = {}
    local list = M.get_second_arg_node(call_node)
    if list:type() ~= 'list' then
        return entry_nodes
    end
    for child in list:iter_children() do
        if non_entry_types[child:type()] == nil then
            table.insert(entry_nodes, child)
        end
    end
    return entry_nodes
end

return M
