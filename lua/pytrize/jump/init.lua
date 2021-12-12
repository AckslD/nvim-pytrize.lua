local M = {}

local param = require('pytrize.jump.param')
local fixture = require('pytrize.jump.fixture')

M.to_param_declaration = param.to_declaration
M.to_fixture_declaration = fixture.to_declaration

return M
