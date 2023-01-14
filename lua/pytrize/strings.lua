local M = {}

M.split_once = function(str, sep, kwargs)
  if kwargs.right then
    kwargs.right = false
    local second, first = M.split_once(str:reverse(), sep:reverse(), kwargs)
    return first:reverse(), second:reverse()
  end
  local fragments = vim.split(str, sep, kwargs)
  local first = table.remove(fragments, 1)
  local second
  if #fragments > 0 then
    second = table.concat(fragments, sep)
  else
    second = nil
  end
  return first, second
end

return M

-- local split_inside = function(str, open, close)
--   local depth = 0
--   local parts = {
--     left = {},
--     middle = {},
--     right = {},
--   }
--   local part = 'left'
--   for i = 1, str:len() do
--     local c = str:sub(i, i)
--     if c == open then
--       if depth == 0 and part == 'left' then
--         part = 'middle'
--       else
--         table.insert(parts[part], c)
--       end
--       depth = depth + 1
--     elseif c == close then
--       depth = depth - 1
--       if depth == 0 and part == 'middle' then
--         part = 'right'
--       else
--         table.insert(parts[part], c)
--       end
--     end
--   end
--   return parts
-- end
--
--
-- P(split_inside('stnreao[tnsreio[]stnreio]

