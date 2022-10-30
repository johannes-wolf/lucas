local functions = require 'functions'
local algo = require 'algorithm'

functions.def_lua('cfactor', 2,
function (a, _)
  return algo.common_factor(a[1], a[2])
end)

functions.def_lua('factor_out', {{name = 'expr'},
                                 {name = 'factor', opt = true}},
function (a, env)
  if a.factor then
    return algo.factor_out_term(a.expr, a.factor, env)
  end
  return algo.factor_out(a.expr, env)
end)

functions.def_lua('expand', 1,
function (a, _)
  return algo.expand(a[1])
end)

functions.def_lua('derivative', {{name = 'fn'},
                                 {name = 'respect', match = 'is_sym'}},
function (a, env)
  return algo.derivative(a.fn, a.respect, env)
end)
