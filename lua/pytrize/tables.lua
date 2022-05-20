local M = {}

M.reverse = function(lst)
    local reversed = {}
    for _, entry in ipairs(lst) do
        table.insert(reversed, 1, entry)
    end
    return reversed
end

M.list_map = function(func, iterable)
  local new = {}
  for _, v in ipairs(iterable) do
    table.insert(new, func(v))
  end
  return new
end

M.max_length = function(tables)
    local max = -1
    for _, tbl in pairs(tables) do
        if #tbl > max then
            max = #tbl
        end
    end
    return max
end

M.contains = function(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

return M
