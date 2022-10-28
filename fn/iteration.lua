local fn = require 'functions'
local lib = require 'lib'

-- Returns a call expression to f with args ...
local function make_call(f, ...)
  return {'fn', f, ...}
end

-- nest(f, expr, n)
--   Returns f applied n times to expr
fn.def_lua_symb('nest', 'unpack', function(f, expr, n)
  f = lib.safe_sym(f) or lib.safe_fn(f)
  n = lib.safe_int(n)

  if not f or not n or not expr then
    return 'undef'
  end

  for _ = 1, n do
    expr = make_call(f, expr)
  end
  return expr
end)

-- iter(expr, var, start, n)
--   Calculates expr n times with symbol var set to the last result or start.
fn.def_lua_symb('iter', 'unpack', function(expr, var, start, n, en) -- TODO TABLE ARGS
  local eval = require 'eval'
  local pattern = require 'pattern'

  var = lib.safe_sym(var)
  n = lib.safe_int(n)

  if not expr or not var or not start or not n or n < 1 then
    return 'undef'
  end

  local res = start
  for _ = 1, n do
    res = eval.eval(pattern.substitute_var(expr, var, res), env)
  end
  return res
end)
