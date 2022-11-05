local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'
local pattern = require 'pattern'
local g = require 'global'
local dbg = require 'dbg'

local algo = {}

-- Simplify expression
local function S(x, env)
  local Env = require 'env'
  local s = require 'simplify'
  return s.expr(x, env or Env())
end

-- Eval expression
local function E(x, env)
  assert(x and env)
  local s = require 'eval'
  return s.eval(x, env)
end

-- Parse 3 arguments of type index, start, stop
-- Supporting the following combinations
--   index_, start, stop
--   index_= start, stop
local function parse_index3(index, arg2, arg3)
  if lib.kind(index, 'tmp') then
    return index, arg2, arg3
  elseif lib.kind(index, '=') then
    local eq_sym, eq_start = lib.split_args_if(index, '=', 2)
    eq_sym = lib.kind(eq_sym, 'tmp') and lib.safe_sym(eq_sym)
    eq_start = lib.safe_int(eq_start)
    if eq_sym and eq_start then
      return lib.arg(index, 1), lib.arg(index, 2), arg2
    end
  end
end

-- Returns a function for calling fn (expression or function) like a function
-- If fn is an expression the arguments are passed via $1..$n variables.
local function make_lambda(fn)
  if lib.is_const(fn) then
    return function()
      return fn
    end
  else
    return function(...)
      local a = {...}
      local e = fn
      for i = 1, #a do
        e = pattern.substitute_tmp(e, tostring(i), a[i])
      end
      return e
    end
  end
end

function algo.numerator(u, l)
  if lib.kind(u, 'frac') then
    return calc.make_int(u[2])
  elseif lib.kind(u, '^') then
    local e = lib.arg(u, 2)
    if lib.safe_bool(calc.lt(e, calc.ZERO)) then
      return calc.ONE
    else
      return u
    end
  elseif lib.kind(u, '*') then
    local v = lib.arg(u, 1)
    return {'*', algo.numerator(v, l), algo.numerator(S({'/', u, v}), l)}
  else
    return u
  end
end

function algo.denominator(u, l)
  if lib.kind(u, 'frac') then
    return calc.make_int(u[3])
  elseif lib.kind(u, '^') then
    local e = lib.arg(u, 2)
    if lib.safe_bool(calc.lt(e, calc.ZERO)) then
      return {'^', u, calc.NEG_ONE}
    else
      return calc.ONE
    end
  elseif lib.kind(u, '*') then
    local v = lib.arg(u, 1)
    return {'*', algo.denominator(v,l), algo.denominator(S({'/', u, v}), l)}
  else
    return calc.ONE
  end
end

-- Substitute all symbols in expr with x=y list rest entry
function algo.subs_sym(expr, rest)
  local tab = {}
  for _, v in ipairs(rest) do
    local sym, repl = lib.split_args_if(v, '=', 2)
    local ident = lib.safe_sym(sym)
    if ident and repl then
      tab[ident] = repl
    end
  end

  return lib.map_recurse(expr, function(u)
    if lib.kind(u, 'sym') then
      if tab[lib.sym(u)] then
        return tab[lib.sym(u)]
      end
    end
    return u
  end)
end

function algo.map(fn, vec, env)
  -- map is a plain function!
  vec = E(vec, env)

  local l = make_lambda(fn)
  if lib.num_args(vec) > 0 then
    return lib.map(vec, l)
  end
  return {'vec'}
end

function algo.sum(fn, vec, env)
  -- sum is a plain function!
  fn = fn or {'sym', '$1'}
  vec = E(vec, env)

  local l = make_lambda(fn)
  local e = {'int', 0}
  for i = 1, lib.num_args(vec) do
    e = {'+', e, l(lib.arg(vec, i))}
  end
  return e
end

function algo.seq(fn, index, start, stop)
  index, start, stop = parse_index3(index, start, stop)
  index = lib.safe_sym(index)
  start = lib.safe_int(start)
  stop  = lib.safe_int(stop)

  if not fn or not start or not stop or not index then
    return nil
  end
  if not start or start > stop then
    return {'vec'}
  end

  local v = {'vec'}
  for n = start, stop do
    table.insert(v, pattern.substitute_tmp(fn, index, {'int', n}))
  end

  return v
end

function algo.sum_seq(fn, index, start, stop)
  index, start, stop = parse_index3(index, start, stop)
  index = lib.safe_sym(index)
  start = lib.safe_int(start)
  stop  = lib.safe_int(stop)

  if start > stop then
    return {'int', 0}
  end

  local res = pattern.substitute_tmp(fn, index, {'int', start})
  for n = start + 1, stop do
    res = {'+', res, pattern.substitute_tmp(fn, index, {'int', n})}
  end

  return res
end

function algo.prod_seq(fn, index, start, stop)
  index, start, stop = parse_index3(index, start, stop)
  index = lib.safe_sym(index)
  start = lib.safe_int(start)
  stop  = lib.safe_int(stop)

  if start > stop then
    return {'int', 1}
  end

  local res = pattern.substitute_tmp(fn, index, {'int', start})
  for n = start + 1, stop do
    res = {'*', res, pattern.substitute_tmp(fn, index, {'int', n})}
  end

  return res
end

-- Find a common factor for u and v
function algo.common_factor(u, v, env)
  u = S(u, env)
  v = S(v, env)

  if lib.kind(u, 'int') and lib.kind(v, 'int') then
    return calc.gcd(u, v)
  elseif lib.kind(u, '*') then
    local f = lib.arg(u, 1)
    local r = algo.common_factor(f, v, env)

    return {'*', r, algo.common_factor({'/', u, f}, {'/', v, r}, env)}
  elseif lib.kind(v, '*') then
    return algo.common_factor(v, u, env)
  else
    local function base(x) return (lib.kind(x, '^') and lib.arg(x, 1)) or x end
    local function expo(x) return (lib.kind(x, '^') and lib.arg(x, 2)) or calc.ONE end

    if lib.compare(base(u), base(v)) then
      local ue, ve = expo(u), expo(v)
      if calc.is_ratnum_p(ue) and calc.is_ratnum_p(ve) and
         calc.sign(ue) == calc.sign(ve) then
        return {'^', base(u), calc.min({ue, ve})}
      end
    end
  end

  return {'int', 1}
end

function algo.factor_out(u, env)
  u = S(u, env)
  if lib.kind(u, '*') then
    return lib.map(u, algo.factor_out, env)
  elseif lib.kind(u, '^') then
    return {'^', algo.factor_out(lib.arg(u, 1), env), lib.arg(u, 2)}
  elseif lib.kind(u, '+') then
    local s = lib.map(u, algo.factor_out, env)
    if lib.num_args(s) == 1 then
      return lib.arg(s, 1)
    end

    local c = lib.arg(s, 1)
    for i = 2, lib.num_args(s) do
      c = algo.common_factor(c, lib.arg(s, i), env)
    end
    return {'*', c, lib.map(s, function(a) return S({'/', a, c}, env) end)}
  end
  return u
end

function algo.factor_out_term(u, t, env)
  if lib.kind(u, '+') then
    return {'*', t, lib.map(u, function(a) return S({'/', a, t}, env) end)}
  elseif lib.kind(u, '^') then
    return {'^', algo.factor_out_term(lib.arg(u, 1), t, env), lib.arg(u, 2)}
  end
  return u
end

-- Returns a sub-expression list of expression u
---@param u table
---@return table
function algo.complete_sub_expr(u)
  if lib.is_atomic(u) then
    return {u}
  else
    local s = {u}
    for i = 1, lib.num_args(u) do
      util.list.join(s, algo.complete_sub_expr(lib.arg(u, i)))
    end
    return s
  end
end

-- Returns if expression u is free of v
---@param u table  Expression to search in
---@param v table  Expression to check against
---@return boolean
function algo.free_of(u, v)
  if u == v or lib.compare(u, v) then
    return false
  elseif lib.is_const(u) or lib.kind(u, 'sym', 'unit') then
    return true
  else
    for i = 1, lib.num_args(u) do
      if not algo.free_of(lib.arg(u, i), v) then
        return false
      end
    end
    return true
  end
end

function algo.free_of_kind(u, kind)
  if lib.kind(u, kind) then
    return false
  else
    for i = 1, lib.num_args(u) do
      if not algo.free_of_kind(lib.arg(u, i), kind) then
        return false
      end
    end
    return true
  end
end

-- Returns a linears expression m*x+n parts as list or nil
---@param u Expression
---@param x Symbol
---@return  Expression[]|nil
function algo.linear_form(u, x)
  if lib.compare(u, x) then
    return {calc.ONE, calc.ZERO}
  elseif lib.is_const(u) then
    return {calc.ZERO, u}
  elseif lib.kind(u, '*') then
    if algo.free_of(u, x) then
      return {calc.ZERO, u}
    elseif algo.free_of(S({'/', u, x}), x) then
      return {S({'/', u, x}), calc.ZERO}
    else
      return nil
    end
  elseif lib.kind(u, '+') then
    local f = algo.linear_form(lib.arg(u, 1), x)
    if not f then return nil end
    local r = algo.linear_form(S({'-', u, lib.arg(u, 1)}), x)
    if not r then return nil end

    return {S({'+', f[1], r[1]}),
            S({'+', f[2], r[2]})}
  elseif algo.free_of(u, x) then
    return {calc.ZERO, u}
  else
    return nil
  end
end

-- Match from a x ^ 2 + b x + c
---@param u Expression
---@param x Symbol
---@return  Expression[]|nil
function algo.quadratic_form(u, x)
  local poly = require 'poly'
  local ces = poly.gpe.coeff_list(u, x)
  if #ces == 3 then
    return {ces[3], ces[2], ces[1]}
  end
  return nil
end

function algo.expand_product(u, v)
  if lib.kind(u, '+') then
    local a = lib.arg(u, 1)
    return {'+', algo.expand_product(a, v), algo.expand_product({'-', u, a}, v)}
  elseif lib.kind(v, '+') then
    return algo.expand_product(v, u)
  else
    return {'*', u, v}
  end
end

function algo.expand_power(base, expo)
  if lib.kind(expo, 'frac', 'real') then
    local i = calc.floor(expo) -- floored integer
    local f = calc.sum(calc.product(calc.NEG_ONE, i), expo) -- fraction/real part
    local b = algo.expand(base)

    -- Prevent multiplication with 1
    if calc.is_zero_p(i) then
      return {'^', b, f}
    end
    return algo.expand_product({'^', b, f}, algo.expand_power(b, i))
  elseif lib.kind(base, '+') then
    local f = lib.arg(base, 1)
    local r = {'-', base, f}
    local s = {'int', 0}

    for k = 0, lib.safe_int(expo) or 1 do
      local c = {'/', calc.factorial(expo), {'*', calc.factorial({'int', k}), {'!', {'-', expo, {'int', k}}}}}
      s = {'+', s, algo.expand_product({'*', c, {'^', f, {'-', expo, {'int', k}}}}, algo.expand_power(r, {'int', k}))}
    end

    return s
  else
    return {'^', base, expo}
  end
end

-- Expands products of sums
--   (x + 2) (x + 3) => x ^ 2 + 5 x + 6
--         x (x + 1) => x ^ 2 + x
--   (x + y) ^ 2     => x ^ 2 + 2 x y + y ^ 2
function algo.expand(u)
  for _ = 1, g.kill_iteration_limit do
    local old_u = u

    -- Expand outputs non-simplified expressions but expects simplified ones
    u = S(algo.expand_single(u))
    if lib.compare(u, old_u) then
      return u
    end
  end
  return g.SYM_KILL
end

function algo.expand_single(u)
  local denom = S(algo.denominator(u))
  if not lib.safe_bool(calc.eq(denom, calc.ONE)) then
    return S({'/', algo.expand_single(S(algo.numerator(u))),
                   algo.expand_single(denom)})
  elseif lib.kind(u, '+') then
    local v = lib.arg(u, 1)
    return {'+', algo.expand(v), algo.expand(S({'-', u, v}))}
  elseif lib.kind(u, '*') then
    local v = lib.arg(u, 1)
    return algo.expand_product(algo.expand(v), algo.expand(S({'/', u, v})))
  elseif lib.kind(u, '^') then
    local base = lib.arg(u, 1)
    local expo = lib.arg(u, 2)

    if (lib.kind(expo, 'int') and lib.safe_bool(calc.gteq(expo, {'int', 2}))) or
       (lib.kind(expo, 'frac', 'real') and  calc.sign(expo) > 0) then
      return algo.expand_power(algo.expand(base), expo)
    end
  elseif lib.kind(u, 'call', 'vec') then
    return lib.map(u, algo.expand_single)
  end
  return u
end

-- Return expression u with all trigonometric functions
-- replaced by a combination of sin and cos.
function algo.trig_subs(u)
  if lib.is_const(u) or lib.kind(u, 'sym', 'unit') then
    return u
  else
    u = lib.map(u, algo.trig_subs)
    if lib.kind(u, 'call') then
      local f = lib.safe_call_sym(u)
      local x = lib.arg(lib.arg(u, 2), 1)

      if f == 'tan' then
        return {'/', calc.make_fn_call('sin', x), calc.make_fn_call('cos', x)}
      elseif f == 'cot' then
        return {'/', calc.make_fn_call('cos', x), calc.make_fn_call('sin', x)}
      elseif f == 'sec' then
        return {'/', {'int', 1}, calc.make_fn_call('cos', x)}
      elseif f == 'csc' then
        return {'/', {'int', 1}, calc.make_fn_call('sin', x)}
      end
    end

    return u
  end
end

-- Compute derivative of u with respect to x
function algo.derivative(u, x, env)
  assert(lib.kind(x, 'sym'))

  u = S(u, env)

  if lib.kind(u, 'sym') and lib.sym(u) == lib.sym(x) then
    return {'int', 1}
  elseif lib.kind(u, '^') then
    local v, w = lib.arg(u, 1), lib.arg(u, 2)
    return {'+', {'*', w, {'^', v, {'-', w, {'int', 1}}}, algo.derivative(v, x, env)},
                 {'*', algo.derivative(w, x, env), {'^', v, w}, calc.make_fn_call('ln', v)}}
  elseif lib.kind(u, '+') then
    local v = lib.arg(u, 1)
    local w = {'-', u, lib.arg(u, 1)}
    return {'+', algo.derivative(v, x, env), algo.derivative(w, x, env)}
  elseif lib.kind(u, '*') then
    local v = lib.arg(u, 1)
    local w = {'/', u, v}
    return {'+', {'*', algo.derivative(v, x, env), w}, {'*', v, algo.derivative(w, x, env)}}
  elseif lib.safe_call_sym(u) == 'exp' then
    local v = lib.call_arg(u, 1)
    return {'*', algo.derivative(v, x, env), u}
  elseif lib.safe_call_sym(u) == 'sin' then
    local v = lib.call_arg(u, 1)
    return {'*', calc.make_fn_call('cos', v), algo.derivative(v, x, env)}
  elseif algo.free_of(u or {}, x) then
    return {'int', 0}
  else
    return calc.make_fn_call('derivative', u, x)
  end
end

return algo
