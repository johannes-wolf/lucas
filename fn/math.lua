local calc = require 'calc'
local algo = require 'algorithm'
local util = require 'util'
local functions = require 'functions'

functions.def_lua('abs', 1,
function (a, env)
  return calc.abs(a[1])
end)

functions.def_lua('eq', 'var',
function (a, env)
  return util.list.join({'='}, a)
end)

functions.def_lua('neq', 'var',
function (a, env)
  return util.list.join({'!='}, a)
end)

functions.def_lua('min', 'var',
function (a, env)
  return calc.min(a)
end)

functions.def_lua('max', 'var',
function (a, env)
  return calc.max(a)
end)

functions.def_lua('floor', 1,
function (a, env)
  return calc.floor(a[1])
end)

functions.def_lua('ceil', 1,
function (a, env)
  return calc.ceil(a[1])
end)

functions.def_lua('integer', 1,
function (a, env)
  return calc.integer(a[1])
end)

functions.def_lua('real', 1,
function (a, env)
  return calc.real(a[1])
end)

functions.def_lua('sqrt', {{name = 'v'}, {name = 'n'}},
function (a, env)
  return calc.sqrt(a.v, a.n, env.approx)
end)

functions.def_lua('ln', 1,
function (a, env)
  return calc.ln(a[1])
end)

functions.def_lua('log', {{name = 'x'}, {name = 'base'}},
function (a, env)
  return calc.log(a.x, a.base)
end)

functions.def_lua('exp', 1,
function (a, env)
  return calc.exp(a[1], env.approx)
end)

functions.def_lua('gcd', 2,
function (a, env)
  return calc.gcd(a[1], a[2])
end)

functions.def_lua('sum_seq', {{name = 'fn'},
                              {name = 'index'},
                              {name = 'start'},
                              {name = 'stop'}},
function (a, env)
  return algo.sum_seq(a.fn, a.index, a.start, a.stop)
end)

functions.def_lua('prod_seq', {{name = 'fn'},
                               {name = 'index'},
                               {name = 'start'},
                               {name = 'stop'}},
function (a, env)
  return algo.prod_seq(a.fn, a.index, a.start, a.stop)
end)

functions.def_lua('map', {{name = 'fn'},
                          {name = 'vec'}},
function (a, env)
  return algo.map(a.fn, a.vec, env)
end, 'plain')

functions.def_lua('sum', {{name = 'fn'},
                          {name = 'vec'}},
function (a, env)
  if a.num_args == 1 then
    return algo.sum(nil, a.fn, env)
  else
    return algo.sum(a.fn, a.vec, env)
  end
end, 'plain')

functions.def_lua('seq', {{name = 'fn'},
                          {name = 'index'},
                          {name = 'start'},
                          {name = 'stop'}},
function (a, env)
  return algo.seq(a.fn, a.index, a.start, a.stop)
end)

functions.def_lua('cfactor', 2,
function (a, env)
  return algo.common_factor(a[1], a[2])
end)

functions.def_lua('factor_out', {{name = 'expr'}, {name = 'factor'}},
function (a, env)
  if a.factor then
    return algo.factor_out_term(a.expr, a.factor)
  end
  return algo.factor_out(a.expr)
end)

functions.def_lua('derivative', {{name = 'fn'},
                                 {name = 'respect'}},
function (a, env)
  return algo.derivative(a.fn, a.respect)
end)
