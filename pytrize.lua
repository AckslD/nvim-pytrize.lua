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
        table.insert(reversed, 1, entry)
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
        for _, param in ipairs(reverse(params)) do
            table.insert(param_order, param)
        end
    end
    return reverse(param_order), call_specs
end

local function call_spec_has_param(call_spec, param)
    for _, p in ipairs(call_spec.params) do
        if p == param then
            return true
        end
    end
    return false
end

local function is_root_dir(dir)
    return vim.fn.finddir('.pytest_cache', dir) ~= ''
end

local function join_path(fragments)
    if #fragments == 1 and fragments[1] == '' then
        return '/'
    else
        return table.concat(fragments, '/')
    end
end

-- TODO better way to do this? (windows support?)
local function split_path_at_root(file)
    local dir_fragments = vim.fn.split(file, '/', 1)
    local rel_file_fragments = {}
    while #dir_fragments do
        table.insert(rel_file_fragments, table.remove(dir_fragments, #dir_fragments))
        local dir = join_path(dir_fragments)
        if is_root_dir(dir) then
            return dir, join_path(rel_file_fragments)
        end
    end
    vim.cmd(string.format('echoerr "%s"', "couldn't find the pytest root dir"))
end

-- TODO better way?
local function get_nodeids_path(rootdir)
    return join_path{rootdir, '.pytest_cache/v/cache/nodeids'}
end

local function get_raw_nodeids(rootdir)
    local nodeids_path = get_nodeids_path(rootdir)
    return vim.fn.json_decode(vim.fn.readfile(nodeids_path))
end

local function parse_raw_nodeid(raw_nodeid)
        local file
        local func_name
        local rest
        file, rest = unpack(vim.fn.split(raw_nodeid, '::'))
        func_name, rest = unpack(vim.fn.split(rest, '['))
        rest = rest:sub(1, -2)
        local params = vim.fn.split(rest, '-')
        return {
            file = file,
            func_name = func_name,
            params = params,
        }
end

local function get_nodeids(rootdir)
    local nodeids = {}
    for _, raw_nodeid in ipairs(get_raw_nodeids(rootdir)) do
        local nodeid = parse_raw_nodeid(raw_nodeid)
        if nodeids[nodeid.file] == nil then
            nodeids[nodeid.file] = {}
        end
        if nodeids[nodeid.file][nodeid.func_name] == nil then
            nodeids[nodeid.file][nodeid.func_name] = {}
        end
        table.insert(nodeids[nodeid.file][nodeid.func_name], nodeid.params)
    end
    return nodeids
end

local function get_param_values(param_order, bufnr)
    local rootdir, file = split_path_at_root(vim.api.nvim_buf_get_name(bufnr))
    local nodeids = get_nodeids(rootdir)
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
                i = i + 1
            end
        end
        values_per_func[func_name] = ordered_values_per_param
    end
    return values_per_func
end

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
    local param_order, call_specs = get_call_specs()
    local param_values = get_param_values(param_order, bufnr)
    local ext_id = 1 -- TODO why doesn't automatic assignment work
    for _, call_spec in ipairs(call_specs) do
        for i, list_entry_node in ipairs(list_entries(call_spec.call_node)) do
            local param_id = get_param_id(param_values[call_spec.func_name], call_spec.params, i)
            -- local ext_id = vim.api.nvim_buf_set_extmark( TODO
            vim.api.nvim_buf_set_extmark(
                bufnr,
                vim.api.nvim_create_namespace('pytrize'),
                list_entry_node:start(),
                0,
                {id = ext_id, virt_text = {{param_id, 'LineNr'}}}
            )
            table.insert(ext_ids, ext_id)
            ext_id = ext_id + 1 -- TODO
        end
    end
end

local function max_length(tables)
    local max = -1
    for _, tbl in pairs(tables) do
        if #tbl > max then
            max = #tbl
        end
    end
    return max
end

local function contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

_G.pytrize_goto = function()
    local line_num, col_num = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, 0)[1]
    local i, j = string.find(line, '%S*::%w*%[[%w-]*%]')
    if i == nil then
        vim.cmd(string.format('echoerr "%s"', "no nodeid under cursor"))
        return
    end
    local param_idx = vim.fn.count(line:sub(i, col_num), '-') + 1
    local nodeid = parse_raw_nodeid(line:sub(i, j))
    vim.cmd('edit ' .. nodeid.file)
    local param_order, call_specs = get_call_specs()
    local param_values = get_param_values(param_order)

    -- the param under the cursor
    local param = param_order[param_idx]

    -- find the call spec
    local call_spec
    for _, cs in ipairs(call_specs) do
        if call_spec_has_param(cs, param) then
            call_spec = cs
            break
        end
    end
    if call_spec == nil then
        vim.cmd(string.format('echoerr "%s"', "couldn't find the declaration"))
        return
    end

    -- find the param id of the nodeid under the cursor of the call spec
    local param_ids = {}
    for idx, p in ipairs(param_order) do
        if contains(call_spec.params, p) then
            table.insert(param_ids, nodeid.params[idx])
        end
    end
    local param_id = table.concat(param_ids, '-')

    -- find the list index
    local list_idx = 1
    local max = max_length(param_values[call_spec.func_name])
    while true do
        if list_idx > max then
            vim.cmd(string.format('echoerr "%s"', "couldn't find the declaration"))
            return
        end
        local pid = get_param_id(param_values[call_spec.func_name], call_spec.params, list_idx)
        if pid:sub(2, -2) == param_id then
            break
        end
        list_idx = list_idx + 1
    end

    -- find the list entry
    local list_entry = list_entries(call_spec.call_node)[list_idx]
    local row, _, _ = list_entry:start()
    row = row + 1

    -- goto entry
    vim.api.nvim_win_set_cursor(0, {row, 0})
    vim.cmd('normal $')
end
