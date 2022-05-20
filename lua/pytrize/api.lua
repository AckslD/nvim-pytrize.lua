local M = {}

M.clear = function(bufnr)
  local marks = require('pytrize.marks')

  if bufnr == nil then bufnr = 0 end
  marks.clear(bufnr)
end

M.set = function(bufnr)
  local cs = require('pytrize.call_spec')
  local marks = require('pytrize.marks')

  if bufnr == nil then bufnr = 0 end
  marks.clear(bufnr)
  local call_specs_per_func = cs.get_calls(bufnr)
  for _, call_specs in pairs(call_specs_per_func) do
    for _, call_spec in ipairs(call_specs) do
      for _, entry_spec in ipairs(call_spec.entries) do
        local entry_row = entry_spec.node:start()
        marks.set{
            bufnr = bufnr,
            text = entry_spec.id,
            row = entry_row,
        }
        for _, item_spec in ipairs(entry_spec.items) do
          local item_row = item_spec.node:start()
          if item_row ~= entry_row then
            marks.set{
                bufnr = bufnr,
                text = item_spec.id,
                row = item_spec.node:start(),
            }
          end
        end
      end
    end
  end
end

M.jump = function()
  local jump = require('pytrize.jump')

  jump.to_param_declaration()
end

M.jump_fixture = function()
  local jump = require('pytrize.jump')

  jump.to_fixture_declaration()
end

return M
