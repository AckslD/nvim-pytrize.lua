local M = {}

M.clear = function(bufnr)
    local marks = require('pytrize.marks')
    marks.clear(bufnr)
end

M.set = function(bufnr)
    local cs = require('pytrize.call_spec')
    local params = require('pytrize.params')
    local marks = require('pytrize.marks')

    if bufnr == nil then
        bufnr = 0
    end
    marks.clear(bufnr)
    local param_order, call_specs = cs.get()
    if param_order == nil then
        return
    end
    local param_values = params.get_values(param_order, bufnr)
    if param_values == nil then
        return
    end
    local ext_id = 1 -- TODO why doesn't automatic assignment work
    for _, call_spec in ipairs(call_specs) do
        for i, list_entry_node in ipairs(cs.list_entries(call_spec.call_node)) do
            local param_id = params.get_id(param_values[call_spec.func_name], call_spec.params, i)
            -- local ext_id = marks.set{ TODO
            marks.set{
                bufnr = bufnr,
                text = param_id,
                row = list_entry_node:start(),
                ext_id = ext_id,
            }
            ext_id = ext_id + 1 -- TODO
        end
    end
end

M.jump = function()
    local jump = require('pytrize.jump')
    jump.to_declaration()
end

return M
