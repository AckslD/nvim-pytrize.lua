local M = {}

local settings = require('pytrize.settings').settings

local next_ext_id = 1
local ext_ids = {}

local function get_ns_id()
    return vim.api.nvim_create_namespace('pytrize')
end

M.clear = function(bufnr)
    for _, ext_id in ipairs(ext_ids) do
        vim.api.nvim_buf_del_extmark(bufnr, get_ns_id(), ext_id)
    end
    next_ext_id = 1
end

M.set = function(opts)
    vim.api.nvim_buf_set_extmark(
        opts.bufnr,
        get_ns_id(),
        opts.row,
        0,
        {id = next_ext_id, virt_text = {{opts.text, settings.highlight}}}
    )
    table.insert(ext_ids, next_ext_id)
    next_ext_id = next_ext_id + 1
end

return M
