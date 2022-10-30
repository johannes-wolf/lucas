local functions = require 'functions'
local pattern = require 'pattern'

functions.def_lua('match', {{name = 'expr'},
                            {name = 'pattern'}},
function (a, _)
  if a.expr and a.pattern then
    return {'bool', pattern.match(a.expr, a.pattern)}
  end
  return {'bool', false}
end, functions.attribs.plain)

functions.def_lua('match_vars', {{name = 'expr'},
                                 {name = 'pattern'}},
function (a, _)
  local vars = {}
  if a.expr and a.pattern and pattern.match(a.expr, a.pattern, vars) then
    local v = {'vec'}
    for k, m in pairs(vars) do
      table.insert(v, {'vec', {'sym', k}, m.expr})
    end
    return v
  end
  return {'vec'}
end, functions.attribs.plain)
