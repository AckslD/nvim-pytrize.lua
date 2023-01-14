local M = {}

local settings = require('pytrize.settings').settings

local next_ext_ids = {}
local ext_ids = {}

local function get_ns_id()
  return vim.api.nvim_create_namespace('pytrize')
end

M.clear = function(bufnr)
  if bufnr == 0 then
    bufnr = vim.fn.bufnr()
  end
  for _, ext_id in ipairs(ext_ids[bufnr] or {}) do
    vim.api.nvim_buf_del_extmark(bufnr, get_ns_id(), ext_id)
  end
  ext_ids[bufnr] = nil
  next_ext_ids[bufnr] = nil
end


local get_ext_id = function(bufnr)
  if ext_ids[bufnr] == nil then ext_ids[bufnr] = {} end
  if next_ext_ids[bufnr] == nil then next_ext_ids[bufnr] = 1 end
  local next_ext_id = next_ext_ids[bufnr]
  table.insert(ext_ids[bufnr], next_ext_id)
  next_ext_ids[bufnr] = next_ext_id + 1
  return next_ext_id
end

M.set = function(opts)
  local bufnr = opts.bufnr
  if bufnr == 0 then
    bufnr = vim.fn.bufnr()
  end
  vim.api.nvim_buf_set_extmark(
    bufnr,
    get_ns_id(),
    opts.row,
    0,
    {id = get_ext_id(bufnr), virt_text = {{opts.text, settings.highlight}}}
  )
end

return M
