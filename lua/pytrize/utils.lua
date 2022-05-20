local M = {}

M.min = function(a, b)
  if a <= b then
    return a
  else
    return b
  end
end

M.max = function(a, b)
  if a >= b then
    return a
  else
    return b
  end
end

return M
