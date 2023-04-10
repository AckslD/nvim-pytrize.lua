local M = {}

local ts = vim.treesitter
local ts_query = ts.query
local parse_query = ts_query.parse or ts_query.parse_query

local warn = require('pytrize.warn').warn
local tbls = require('pytrize.tables')

local get_root = function(bufnr)
    local parser = ts.get_parser(bufnr)
    local tstree = parser:parse()[1]
    return tstree:root()
end

local get_param_call_nodes = function(bufnr)
    local tsroot = get_root(bufnr)
    local query = parse_query(
        'python',
        -- TODO not sure why eg (#eq? @param "pytest.mark.parametrize") does not work
        [[
          (decorated_definition (
            decorator (
              call
                function: ((attribute) @param)
            )
          ))
        ]]
    )
    local nodes = {}
    for _, node, _ in query:iter_captures(tsroot) do
      if ts.get_node_text(node, bufnr) == 'pytest.mark.parametrize' then
        table.insert(nodes, node:parent())
      end
    end
    return nodes
end

local get_second_arg_node = function(call_node)
    local arguments = call_node:field('arguments')[1]
    return arguments:child(3)
end

local get_named_children = function(node)
  local children = {}
  for child in node:iter_children() do
    if child:named() and child:type() ~= 'comment' then
      table.insert(children, child)
    end
  end
  return children
end

local list_entries = function(call_node)
    local list = get_second_arg_node(call_node)
    if list:type() ~= 'list' then
        return {}
    end
    return get_named_children(list)
end

local LITERALS = {
  integer = true,
  float = true,
  none = true,
  ['true'] = true,
  ['false'] = true,
}

local is_simple_literal = function(node)
  return LITERALS[node:type()] ~= nil
end

local get_item_id = function(entry_idx, item_node, param, bufnr)
  if item_node:type() == 'string' then
    local str = ts.get_node_text(item_node, bufnr)
    local quote = str:sub(1, 1)
    str = vim.fn.trim(str, quote):gsub('\n', '\\n')
    return str
  elseif is_simple_literal(item_node) then
    return ts.get_node_text(item_node, bufnr)
  end
  return string.format('%s%d', param, entry_idx)
end

local get_entry = function(entry_idx, entry_node, params, bufnr)
  if entry_node:type() ~= 'tuple' then
    if #params == 1 then
      return {{
        id = get_item_id(entry_idx, entry_node, params[1], bufnr),
        node = entry_node,
        param = params[1],
        idx = entry_idx,
      }}
    else
      return {{
        id = string.format('unknown (%d)', entry_idx),
        node = entry_node,
      }}
    end
  end
  local items = {}
  local item_nodes = get_named_children(entry_node)
  if #params ~= #item_nodes then
    -- TODO warn here?
    -- warn(string.format(
    --   'number of items in entry tuple differ from number of params, %d items and %d params (line %d in %s)',
    --   #item_nodes,
    --   #params,
    --   entry_node:start() + 1,
    --   vim.fn.bufname(bufnr)
    -- ))
    return nil
  end
  for i, param in ipairs(params) do
    table.insert(items, {
      id = get_item_id(entry_idx, item_nodes[i], param, bufnr),
      node = item_nodes[i],
      param = param,
      idx = entry_idx,
    })
  end
  return items
end

local get_entries = function(call_node, params, bufnr)
  local entries = {}
  for entry_idx, entry_node in ipairs(list_entries(call_node)) do
    local items = get_entry(entry_idx - 1, entry_node, params, bufnr)
    if items ~= nil then
      table.insert(entries, {
        id = table.concat(tbls.list_map(function(item) return item.id end, items), '-'),
        items = items,
        node = entry_node,
      })
    end
  end
  return entries
end

M.get_calls = function(bufnr)
  local calls = get_param_call_nodes(bufnr or 0)
  local call_specs = {}
  for _, call in ipairs(calls) do
    -- Move to separate func, better way?
    local decorated_definition = call:parent():parent()
    if decorated_definition:type() ~= 'decorated_definition' then
      local row = call:start()
      warn(string.format(
        "couldn't parse params (line %d)\n  expected `decorated_definition`\n  got `%s`",
        row,
        decorated_definition:type()
      ))
      return
    end
    local func = decorated_definition:field('definition')[1]
    local func_name = ts.get_node_text(func:field('name')[1], bufnr)

    local arguments = call:field('arguments')[1]
    local params_node = arguments:child(1)
    if params_node:type() ~= 'string' then
      local row = call:start()
      warn(string.format(
        "couldn't parse params (line %d)\n  expected `string`\n  got `%s`",
        row,
        params_node:type()
      ))
      return
    end
    local params_str = ts.get_node_text(params_node, bufnr)
    params_str = params_str:sub(2, -2)
    local params = vim.fn.split(params_str, [[,\s*]])  -- TODO avoid vim script?
    local entries = get_entries(call, params, bufnr)
    if call_specs[func_name] == nil then call_specs[func_name] = {} end
    table.insert(call_specs[func_name], {
      node = call,
      entries = entries,
      params = params,
      func_name = func_name,
    })
  end
  return call_specs
end

return M
