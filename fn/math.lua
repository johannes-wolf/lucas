local calc = require 'calc'
local algo = require 'algorithm'
local util = require 'util'
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

functions.def_lua('vec', 'var',
function (a, env)
  return util.list.join({'vec'}, a)
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

functions.def_lua('map', {{name = 'fn'},
                          {name = 'vec'}},
function (a, env)
  return algo.map(a.fn, a.vec)
end)

functions.def_lua('seq', {{name = 'fn'},
                          {name = 'index'},
                          {name = 'start'},
                          {name = 'stop'}},
function (a, env)
  return algo.seq(a.fn, a.index, a.start, a.stop)
end)
