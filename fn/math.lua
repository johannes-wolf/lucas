local calc = require 'calc'
local algo = require 'algorithm'
local functions = require 'functions'

functions.def_lua('floor', '1',
function (a, env)
  return calc.floor(a[1])
end)

functions.def_lua('ceil', '1',
function (a, env)
  return calc.ceil(a[1])
end)

functions.def_lua('integer', '1',
function (a, env)
  return calc.integer(a[1])
end)

functions.def_lua('real', '1',
function (a, env)
  return calc.real(a[1])
end)

functions.def_lua('sqrt', {{name = 'v'}, {name = 'n'}},
function (a, env)
  return calc.sqrt(a.v, a.n, env.approx)
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
