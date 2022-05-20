local M = {}

local cs = require('pytrize.call_spec')
local nids = require('pytrize.nodeids')
local tbls = require('pytrize.tables')
local paths = require('pytrize.paths')
-- local prompt_files = require('pytrize.input').prompt_files
local warn = require('pytrize.warn').warn
local open_file = require('pytrize.jump.util').open_file
local get_nodeids_path = require('pytrize.paths').get_nodeids_path
local min = require('pytrize.utils').min
local max = require('pytrize.utils').max

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
    if vim.fn.filereadable(file) == 1 then
      table.insert(files, file)
    end
  end
  if #files == 0 then
    warn(string.format(
      'could not find the file for function `%s` when looking in %s, did you run the test?',
      func_name,
      get_nodeids_path(rootdir)
    ))
  elseif #files == 1 then
    callback(files[1])
  else
    vim.ui.select(files, {
      prompt = 'Multiple files found for the nodeid under cursor, pick the correct one:',
    }, callback)
    -- prompt_files(files, callback)
  end
end

local function jump_to_nodeid_at_cursor(callback)
  -- TODO how to handle col_num?
  local line_num, col_num = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, 0)[1]
  local i, _ = string.find(line, '%S*:?:?test_%w+%[.*')  -- TODO how to check for zero or two :?
  if i == nil then
    warn("no nodeid under cursor")
    return
  end
  local nodeid = nids.parse_raw(line:sub(i))
  local pattern_position = col_num + 1 - (i - 1)  -- cursor relative to match
  local param_position = pattern_position - nodeid.param_start_idx + 1  -- cursor relative to params
  param_position = min(max(1, param_position), nodeid.params:len())  -- restrict it to be inside
  if nodeid == nil then
    warn("couldn't parse nodeid under cursor")
    return
  end
  if nodeid.file == nil then
    query_file(nodeid.func_name, function(file)
      if file == nil then
        return
      end
      nodeid.file = file
      callback(nodeid, param_position)
    end)
  else
    callback(nodeid, param_position)
  end
end

-- local function get_call_spec(call_specs, func_name, param)
--   local found_call_spec
--   for _, call_spec in ipairs(call_specs) do
--     if call_spec.func_name == func_name and cs.has_param(call_spec, param) then
--       found_call_spec = call_spec
--       break
--     end
--   end
--   if found_call_spec == nil then
--     warn("couldn't find the declaration with param " .. param)
--     return
--   end
--   return found_call_spec
-- end

-- local function get_local_param_id(param_order, call_spec, nodeid)
--   local param_ids = {}
--   for idx, p in ipairs(param_order) do
--     if tbls.contains(call_spec.params, p) then
--       table.insert(param_ids, nodeid.params[idx])
--     end
--   end
--   return table.concat(param_ids, '-')
-- end

-- local function get_list_index(param_values, call_spec, param_id)
--   local list_idx = 1
--   local max = tbls.max_length(param_values[call_spec.func_name])
--   while true do
--     if list_idx > max then
--       warn("couldn't find the declaration matching id " .. param_id)
--       return
--     end
--     local pid = params.get_id(param_values[call_spec.func_name], call_spec.params, list_idx)
--     if pid:sub(2, -2) == param_id then
--       break
--     end
--     list_idx = list_idx + 1
--   end
--   return list_idx
-- end

-- local get_position = function(call_spec, list_idx)
--   local list_entry = cs.list_entries(call_spec.call_node)[list_idx]
--   local row, col
--   if list_entry == nil then
--     row, col, _ = cs.get_second_arg_node(call_spec.call_node):start()
--   else
--     row, col, _ = list_entry:start()
--   end
--   return row, col
-- end


local startswith = function(str, sub)
  return str:sub(1, sub:len()) == sub
end

M.to_declaration = function()
  jump_to_nodeid_at_cursor(function(nodeid, param_position)
    local bufnr = 0
    local original_buffer = vim.api.nvim_buf_get_name(bufnr)
    if vim.fn.filereadable(nodeid.file) == 0 then
      warn(string.format('file `%s` is not readable', nodeid.file))
      return
    end
    open_file(nodeid.file)
    local call_specs = cs.get_calls(bufnr)[nodeid.func_name]
    if call_specs == nil then
      open_file(original_buffer)
      return
    end
    local params = nodeid.params
    for _, call_spec in ipairs(tbls.reverse(call_specs)) do
      for _, entry_spec in ipairs(call_spec.entries) do
        if startswith(params, entry_spec.id:sub(1, params:len())) then
          for _, item_spec in ipairs(entry_spec.items) do
            if startswith(params, item_spec.id) then
              if param_position <= item_spec.id:len() then
                local row, col = item_spec.node:start()
                vim.api.nvim_win_set_cursor(0, {row + 1, col})
                return
              else
                local shift = item_spec.id:len() + 2
                params = params:sub(shift)
                param_position = param_position - (shift - 1)
              end
            end
          end
        end
      end
    end
    warn(string.format(
      'could not find the id `%s` of `%s` in file `%s`',
      nodeid.params,
      nodeid.func_name,
      nodeid.file
    ))
    P('call_specs', call_specs)
    if #call_specs > 0 then
      -- at least jump to the last call spec
      local row, col = call_specs[#call_specs].node:start()
      vim.api.nvim_win_set_cursor(0, {row + 1, col})
    else
      open_file(original_buffer)
    end
    -- local param_values = params.get_values(param_order)
    -- if param_values == nil then
    --   open_file(original_buffer)
    --   return
    -- end
    -- -- the param under the cursor
    -- local param = param_order[param_idx]
    -- -- find the call spec
    -- local call_spec = get_call_spec(call_specs, nodeid.func_name, param)
    -- if call_spec == nil then
    --   open_file(original_buffer)
    --   return
    -- end
    -- -- find the param id of the nodeid under the cursor of the call spec
    -- local param_id = get_local_param_id(param_order, call_spec, nodeid)
    -- -- find the list index
    -- local list_idx = get_list_index(param_values, call_spec, param_id)
    -- if list_idx == nil then
    --   open_file(original_buffer)
    --   return
    -- end
    -- -- find the list entry position
    -- local row, col = get_position(call_spec, list_idx)
    -- -- jump to position
    -- vim.api.nvim_win_set_cursor(0, {row + 1, col})
  end)
end

return M
