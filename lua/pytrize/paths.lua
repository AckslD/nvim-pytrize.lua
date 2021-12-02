local M = {}

local warn = require('pytrize.warn').warn

local function is_root_dir(dir)
    return vim.fn.finddir('.pytest_cache', dir) ~= ''
end

local function join_path(fragments)
    if #fragments == 1 and fragments[1] == '' then
        return '/'
    else
        return table.concat(fragments, '/')
    end
end

-- TODO better way to do this? (windows support?)
M.split_at_root = function(file)
    local dir_fragments = vim.fn.split(file, '/', 1)
    local rel_file_fragments = {}
    while #dir_fragments do
        table.insert(rel_file_fragments, 1, table.remove(dir_fragments, #dir_fragments))
        local dir = join_path(dir_fragments)
        if is_root_dir(dir) then
            return dir, join_path(rel_file_fragments)
        end
    end
    warn("couldn't find the pytest root dir")
end

M.get_nodeids_path = function(rootdir)
    return join_path{rootdir, '.pytest_cache', 'v', 'cache', 'nodeids'}
end

return M
