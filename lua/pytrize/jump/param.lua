local M = {}

local cs = require('pytrize.call_spec')
local nids = require('pytrize.nodeids')
local params = require('pytrize.params')
local tbls = require('pytrize.tables')
local paths = require('pytrize.paths')
local prompt_files = require('pytrize.input').prompt_files
local warn = require('pytrize.warn').warn
local open_file = require('pytrize.jump.util').open_file

local function query_file(func_name, callback)
    local rootdir, _ = paths.split_at_root(vim.api.nvim_buf_get_name(0))
    if rootdir == nil then
        return
    end
    local unique_files = {}
    for file, file_nodeids in pairs(nids.get(rootdir)) do
        if file_nodeids[func_name] ~= nil then
            unique_files[file] = true
        end
    end
    local files = {}
    for file, _ in pairs(unique_files) do
        table.insert(files, file)
    end
    if #files == 1 then
        callback(files[1])
    else
        return prompt_files(files, callback)
    end
end

local function jump_to_nodeid_at_cursor(callback)
    local line_num, col_num = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, 0)[1]
    local i, j = string.find(line, '%S*:?:?%w*%[%S*%]')  -- TODO how to check for zero or two :?
    if i == nil then
        warn("no nodeid under cursor")
        return
    end
    local param_idx = vim.fn.count(line:sub(i, col_num), '-') + 1
    local nodeid = nids.parse_raw(line:sub(i, j))
    if nodeid == nil then
        warn("couldn't parse nodeid under cursor")
        return
    end
    if nodeid.file == nil then
        query_file(nodeid.func_name, function(file)
            nodeid.file = file
            callback(param_idx, nodeid)
        end)
    else
        callback(param_idx, nodeid)
    end
    return param_idx, nodeid
end

local function get_call_spec(call_specs, func_name, param)
    local found_call_spec
    for _, call_spec in ipairs(call_specs) do
        if call_spec.func_name == func_name and cs.has_param(call_spec, param) then
            found_call_spec = call_spec
            break
        end
    end
    if found_call_spec == nil then
        warn("couldn't find the declaration with param " .. param)
        return
    end
    return found_call_spec
end

local function get_local_param_id(param_order, call_spec, nodeid)
    local param_ids = {}
    for idx, p in ipairs(param_order) do
        if tbls.contains(call_spec.params, p) then
            table.insert(param_ids, nodeid.params[idx])
        end
    end
    return table.concat(param_ids, '-')
end

local function get_list_index(param_values, call_spec, param_id)
    local list_idx = 1
    local max = tbls.max_length(param_values[call_spec.func_name])
    while true do
        if list_idx > max then
            warn("couldn't find the declaration matching id " .. param_id)
            return
        end
        local pid = params.get_id(param_values[call_spec.func_name], call_spec.params, list_idx)
        if pid:sub(2, -2) == param_id then
            break
        end
        list_idx = list_idx + 1
    end
    return list_idx
end

local function get_position(call_spec, list_idx)
    local list_entry = cs.list_entries(call_spec.call_node)[list_idx]
    local row, col
    if list_entry == nil then
        row, col, _ = cs.get_second_arg_node(call_spec.call_node):start()
    else
        row, col, _ = list_entry:start()
    end
    return row, col
end

M.to_declaration = function()
    jump_to_nodeid_at_cursor(function(param_idx, nodeid)
        local original_buffer = vim.api.nvim_buf_get_name(0)
        open_file(nodeid.file)
        local param_order, call_specs = cs.get()
        if param_order == nil then
            open_file(original_buffer)
            return
        end
        local param_values = params.get_values(param_order)
        if param_values == nil then
            open_file(original_buffer)
            return
        end
        -- the param under the cursor
        local param = param_order[param_idx]
        -- find the call spec
        local call_spec = get_call_spec(call_specs, nodeid.func_name, param)
        if call_spec == nil then
            open_file(original_buffer)
            return
        end
        -- find the param id of the nodeid under the cursor of the call spec
        local param_id = get_local_param_id(param_order, call_spec, nodeid)
        -- find the list index
        local list_idx = get_list_index(param_values, call_spec, param_id)
        if list_idx == nil then
            open_file(original_buffer)
            return
        end
        -- find the list entry position
        local row, col = get_position(call_spec, list_idx)
        -- jump to position
        vim.api.nvim_win_set_cursor(0, {row + 1, col})
    end)
end

return M
