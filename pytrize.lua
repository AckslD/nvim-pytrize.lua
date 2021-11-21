local ts = vim.treesitter
local ts_utils = require('nvim-treesitter.ts_utils')
local ts_query = ts.query

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

-- TODO better way?
local function reverse(lst)
    local reversed = {}
    for _, entry in ipairs(lst) do
        table.insert(reversed, entry, 1)
    end
    return reversed
end

local function get_call_specs()
    local calls = get_param_call_nodes()
    local call_specs = {}
    local param_order = {}
    for _, call in ipairs(calls) do
        -- Move to separate func, better way?
        local decorated_definition = call:parent():parent()
        if decorated_definition:type() ~= 'decorated_definition' then
            vim.cmd(string.format('echoerr "%s"', "couldn't parse params"))
            return
        end
        local func = decorated_definition:field('definition')[1]
        local func_name = ts_utils.get_node_text(func:field('name')[1])[1]

        local arguments = call:field('arguments')[1]
        local params_node = arguments:child(1)
        if params_node:type() ~= 'string' then
            vim.cmd(string.format('echoerr "%s"', "couldn't parse params"))
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
        for _, param in ipairs(params) do
            table.insert(param_order, param)
        end
    end
    return reverse(param_order), call_specs
end

local function get_list_length(list)
    -- TODO how to round dowm?
    local child_count = list:child_count()
    if (child_count - 1) % 2 == 0 then
        return (child_count - 1) / 2
    else
        return (child_count - 2) / 2
    end
end

local function is_root_dir(dir)
    return vim.fn.finddir('.pytest_cache', dir) ~= ''
end

local function path_parent(path)
    local fragments = vim.fn.split(path, '/', 1)
    table.remove(fragments, #fragments)
    return table.concat(fragments, '/')
end

local function get_root_dir(basedir)
    local dir = basedir
    while not is_root_dir(dir) do
        dir = path_parent(dir)
        if not dir then
            vim.cmd(string.format('echoerr "%s"', "couldn't find the pytest root dir"))
            return
        end
    end
    return dir
end

-- TODO better way?
local function get_nodeids_path(basedir)
    return get_root_dir(basedir) .. '/.pytest_cache/v/cache/nodeids'
end

local function get_raw_nodeids(basedir)
    local nodeids_path = get_nodeids_path(basedir)
    print(nodeids_path)
    P(vim.fn.json_decode(vim.fn.readfile(nodeids_path)))
    return vim.fn.json_decode(vim.fn.readfile(nodeids_path))
end

local function get_nodeids(basedir)
    local nodeids = {}
    for _, raw_nodeid in ipairs(get_raw_nodeids(basedir)) do
        P('raw', raw_nodeid)
        local file
        local func_name
        local rest
        file, rest = vim.fn.split(raw_nodeid, '::')
        if nodeids[file] == nil then
            nodeids[file] = {}
        end
        func_name, rest = vim.fn.split(rest, '[')
        if nodeids[file][func_name] == nil then
            nodeids[file][func_name] = {}
        end
        rest = rest:sub(1, -2)
        local params = vim.fn.split(rest, '-')
        table.insert(nodeids[file][func_name], params)
    end
    return nodeids
end

local function get_param_values(param_order, bufnr)
    local file = vim.api.nvim_buf_get_name(bufnr)
    local nodeids = get_nodeids(path_parent(file))
    if nodeids[file] == nil then
        return {}
    end
    local values_per_func = {}
    for func_name, nids in pairs(nodeids[file]) do
        local unique_values_per_param = {}
        local ordered_values_per_param = {}
        for _, values in ipairs(nids) do
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
            end
        end
        values_per_func[func_name] = ordered_values_per_param
    end
    return values_per_func
end

-- local function get_param_values(param_order, bufnr)
--     -- TODO reverse order
--     local file = vim.api.nvim_buf_get_name(bufnr)
--     -- TODO call python
--     return {
--         ['test'] = {
--             x = {'None0', 'None1', 'None2'},
--             a = {'a0', 'a1'},
--             b = {'b'},
--             c = {'None', 'c1'},
--             i = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'},
--         },
--     }
-- end

-- TODO why are these even entry types?
local non_entry_types = {
    ['['] = true,
    [','] = true,
    [']'] = true,
}

local function list_entries(call_node)
    local entry_nodes = {}
    local arguments = call_node:field('arguments')[1]
    local list = arguments:child(3)
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

local function get_param_id(param_values, params, i)
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

local ext_ids = {}

local function get_ns_id()
    return vim.api.nvim_create_namespace('pytrize')
end

local function clear_marks(bufnr)
    for _, ext_id in ipairs(ext_ids) do
        vim.api.nvim_buf_del_extmark(bufnr, get_ns_id(), ext_id)
    end
end

_G.pytrize_clear = function(bufnr)
    if bufnr == nil then
        bufnr = 0
    end
    clear_marks(bufnr)
end

_G.pytrize = function(bufnr)
    if bufnr == nil then
        bufnr = 0
    end
    clear_marks(bufnr)
    -- local param_order, call_specs = get_call_specs()
    local param_order = {'x', 'a', 'b', 'c', 'i'}
    local param_values = get_param_values(param_order, bufnr)
    P(param_values)
    -- local ext_id = 1 -- TODO why doesn't automatic assignment work
    -- for _, call_spec in ipairs(call_specs) do
    --     for i, list_entry_node in ipairs(list_entries(call_spec.call_node)) do
    --         local param_id = get_param_id(param_values[call_spec.func_name], call_spec.params, i)
    --         -- local ext_id = vim.api.nvim_buf_set_extmark(
    --         vim.api.nvim_buf_set_extmark(
    --             bufnr,
    --             vim.api.nvim_create_namespace('pytrize'),
    --             list_entry_node:start(),
    --             0,
    --             {id = ext_id, virt_text = {{param_id, 'LineNr'}}}
    --         )
    --         table.insert(ext_ids, ext_id)
    --         ext_id = ext_id + 1 -- TODO
    --     end
    -- end
end
