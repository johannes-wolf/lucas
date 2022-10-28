local fn = require 'functions'
local lib = require 'lib'

-- Returns a call expression to f with args ...
local function make_call(f, ...)
  return {'fn', f, ...}
end

-- nest(f, expr, n)
--   Returns f applied n times to expr
fn.def_lua_symb('nest', {{name = 'fn'}, {name = 'x'}, {name = 'n'}},
function(a, env)
  local f = lib.safe_sym(a.fn) or lib.safe_fn(a.fn)
  local n = lib.safe_int(a.n)

  if not f or not n or not a.x then
    return 'undef'
  end

  local r = a.x
  for _ = 1, n do
    r = make_call(f, r)
  end
  return r
end)

-- iter(expr, var, start, n)
--   Calculates expr n times with symbol var set to the last result or start.
fn.def_lua_symb('iter', {{name = 'fn'}, {name = 'var'}, {name = 'start'}, {name = 'n'}},
function(a, env)
  local eval = require 'eval'
  local pattern = require 'pattern'

  local var = lib.safe_sym(a.var)
  local n = lib.safe_int(a.n)

  if not a.fn or not var or not a.start or not n or n < 1 then
    return 'undef'
  end

  local res = a.start
  for _ = 1, n do
    res = eval.eval(pattern.substitute_var(a.fn, var, res), env)
  end
  return res
end)
