local calc = require 'calc'
local algo = require 'algorithm'
local util = require 'util'
local functions = require 'functions'
local g = require 'global'
local dbg = require 'dbg'

functions.def_lua('abs', 1,
function (a, _)
  return calc.abs(a[1])
end)

functions.def_lua('eq', 'var',
function (a, _)
  return util.list.join({'='}, a)
end)

functions.def_lua('neq', 'var',
function (a, _)
  return util.list.join({'!='}, a)
end)

functions.def_lua('min', 'var',
function (a, _)
  return calc.min(a)
end)

functions.def_lua('max', 'var',
function (a, _)
  return calc.max(a)
end)

functions.def_lua('floor', 1,
function (a, _)
  return calc.floor(a[1])
end)

functions.def_lua('ceil', 1,
function (a, _)
  return calc.ceil(a[1])
end)

functions.def_lua('integer', 1,
function (a, _)
  return calc.integer(a[1])
end)

functions.def_lua('real', 1,
function (a, _)
  return calc.real(a[1])
end)

functions.def_lua('sqrt', {{name = 'v'},
                           {name = 'n', match = 'is_natnum1', opt = true}},
function (a, env)
  return calc.sqrt(a.v, a.n, env.approx)
end)

functions.def_lua('ln', 1,
function (a, _)
  return calc.ln(a[1])
end)

functions.def_lua('log', {{name = 'x'},
                          {name = 'base'}},
function (a, _)
  return calc.log(a.x, a.base)
end)

functions.def_lua('exp', 1,
function (a, _)
  return calc.exp(a[1], env.approx)
end)

functions.def_lua('gcd', 2,
function (a, _)
  return calc.gcd(a[1], a[2])
end)

functions.def_lua('sum_seq', {{name = 'fn'},
                              {name = 'index'},
                              {name = 'start'},
                              {name = 'stop', opt = true}},
function (a, env)
  return algo.sum_seq(a.fn, a.index, a.start, a.stop)
end)

functions.def_lua('prod_seq', {{name = 'fn'},
                               {name = 'index'},
                               {name = 'start'},
                               {name = 'stop', opt = true}},
function (a, _)
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
                          {name = 'stop', opt = true}},
function (a, _)
  return algo.seq(a.fn, a.index, a.start, a.stop)
end)

functions.def_lua('numerator', 1,
function(u)
  return algo.numerator(u[1])
end)

functions.def_lua('denominator', 1,
function(u)
  return algo.denominator(u[1])
end)

functions.def_lua('linear_form', 2,
function(u)
  local f = algo.linear_form(u[1], u[2])
  print(dbg.dump(f))
  if f then
    return {'vec', f[1], f[2]}
  end
end)

functions.def_lua('quadratic_form', 2,
function(u)
  local f = algo.quadratic_form(u[1], u[2])
  if f then
    return {'vec', f[1], f[2], f[3]}
  end
end)

-- cases
--   cases([cond1, then1] ..., else)
--
--   Both conditions and actions are lazy evaluated.
functions.def_lua('cases', 'var',
function (a, env)
  local eval = require 'eval'

  if #a == 0 then
    g.error('cases: No cases')
    return
  elseif #a % 2 == 0 then
    g.error('cases: Missing default case')
    return
  end

  for i = 1, #a - 1, 2 do
    local cond = a[i]
    local repl = a[i+1]

    cond = eval.eval(cond, env)
    if calc.is_true_p(cond) then
      return eval.eval(repl, env)
    end
  end

  -- Evaluate default case
  return eval.eval(a[#a], env)
end, functions.attribs.plain)
