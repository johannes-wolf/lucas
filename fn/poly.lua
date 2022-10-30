local functions = require 'functions'
local poly = require 'poly'
local util = require 'util'
local dbg = require 'dbg'

functions.def_lua('poly.vars', {{name = 'u'}},
function (a, _)
  return util.list.prepend('vec', poly.variables(a.u))
end)

functions.def_lua('poly.deg', {{name = 'u'},
                               {name = 'x', match = 'is_sym'}},
function (a, _)
  return poly.gpe.degree(a.u, a.x)
end)

functions.def_lua('poly.coeff', {{name = 'u'},
                                 {name = 'x',   match = 'is_sym'},
                                 {name = 'exp', match = 'is_natnum1', transform = 'as_int'}},
function (a, _)
  return poly.gpe.coeff(a.u, a.x, a.exp)
end)

functions.def_lua('poly.lcoeff', {{name = 'u'},
                                  {name = 'x', match = 'is_sym'}},
function (a, _)
  return poly.gpe.leading_coeff(a.u, a.x)
end)

functions.def_lua('poly.div', {{name = 'u'},
                               {name = 'v'},
                               {name = 'x', match = 'is_sym'}},
function (a, env)
  return {'vec', poly.division(a.u, a.v, a.x, env)}
end)
