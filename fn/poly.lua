local functions = require 'functions'
local poly = require 'poly'
local util = require 'util'
local dbg = require 'dbg'

functions.def_lua('poly.vars', 1,
function (a, env)
  return util.list.prepend('vec', poly.variables(a[1]))
end)

functions.def_lua('poly.deg', 2,
function (a, env)
  return poly.gpe.degree(a[1], a[2])
end)

functions.def_lua('poly.coeff', 3,
function (a, env)
  return poly.gpe.coeff(a[1], a[2], a[3])
end)

functions.def_lua('poly.lcoeff', 2,
function (a, env)
  return poly.gpe.leading_coeff(a[1], a[2])
end)

functions.def_lua('poly.div', {{name = 'u'},
                               {name = 'v'},
                               {name = 'x'}},
function (a, env)
  return {'vec', poly.division(a.u, a.v, a.x, env)}
end)
