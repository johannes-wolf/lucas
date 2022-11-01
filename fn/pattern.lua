local g = require 'global'
local fn = require 'functions'
local lib = require 'lib'
local calc = require 'calc'
local pattern = require 'pattern'


fn.def_lua('match', {{name = 'expr'},
                     {name = 'pattern'}},
function (a, _)
  if a.expr and a.pattern then
    return {'bool', pattern.match(a.expr, a.pattern)}
  end
  return {'bool', false}
end)

fn.def_lua('match_vars', {{name = 'expr'},
                          {name = 'pattern'}},
function (a, _)
  local vars = {}
  if a.expr and a.pattern and pattern.match(a.expr, a.pattern, vars) then
    local v = {'vec'}
    for k, m in pairs(vars) do
      table.insert(v, {'vec', {'tmp', k}, m.expr})
    end
    return v
  end
  return {'vec'}
end)
