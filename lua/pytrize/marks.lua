local M = {}

local settings = require('pytrize.settings').settings

local ext_ids = {}

local function get_ns_id()
    return vim.api.nvim_create_namespace('pytrize')
end

M.clear = function(bufnr)
    if bufnr == nil then
        bufnr = 0
    end
    for _, ext_id in ipairs(ext_ids) do
        vim.api.nvim_buf_del_extmark(bufnr, get_ns_id(), ext_id)
    end
end

M.set = function(opts)
    vim.api.nvim_buf_set_extmark(
        opts.bufnr,
        get_ns_id(),
        opts.row,
        0,
        {id = opts.ext_id, virt_text = {{opts.text, settings.highlight}}}
    )
    table.insert(ext_ids, opts.ext_id)
end

return M
