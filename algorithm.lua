local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'
local pattern = require 'pattern'
local dbg = require 'dbg'

local algo = {}

local function auto_simp(x, env)
  local s = require 'simplify'
  return s.expr(x, env)
end

local function eval(x, env)
  local s = require 'eval'
  return s.eval(x, env)
end

-- Parse 3 arguments of type index, start, stop
-- Supporting the following combinations
--   index, start, stop
--   index=start, stop
local function parse_index3(index, arg2, arg3)
  if lib.kind(index, 'sym') then
    return index, arg2, arg3
  elseif lib.kind(index, '=') then
    local eq_sym = lib.safe_sym(lib.arg(index, 1))
    local eq_start = lib.safe_int(lib.arg(index, 2))
    if eq_sym and eq_start then
      return lib.arg(index, 1), lib.arg(index, 2), arg2
    end
  end
end

-- Returns a function for calling fn (expression or function) like a function
-- If fn is an expression the arguments are passed via $1..$n variables.
local function make_lambda(fn)
  if lib.kind(fn, 'fn') then
    local n = lib.safe_fn(fn)
    return function(...)
      return {'fn', n, ...}
    end
  elseif lib.is_const(fn) then
    return function()
      return fn
    end
  else
    return function(...)
      local a = {...}
      local e = fn
      for i = 1, #a do
        e = pattern.substitute_var(e, '$'..i, a[i])
      end
      return e
    end
  end
end

function algo.map(fn, vec, env)
  -- map is a plain function!
  vec = eval(vec, env)

  local l = make_lambda(fn)
  if lib.num_args(vec) > 0 then
    return lib.map(vec, l)
  end
  return {'vec'}
end

function algo.sum(fn, vec, env)
  -- sum is a plain function!
  fn = fn or {'sym', '$1'}
  vec = eval(vec, env)

  local l = make_lambda(fn)
  local e = {'int', 0}
  for i = 1, lib.num_args(vec) do
    e = {'+', e, l(lib.arg(vec, i))}
  end
  print(dbg.dump(e))
  return e
end

function algo.seq(fn, index, start, stop)
  index, start, stop = parse_index3(index, start, stop)
  index = lib.safe_sym(index)
  start = lib.safe_int(start)
  stop  = lib.safe_int(stop)

  if start > stop then
    return {'vec'}
  end

  local v = {'vec'}
  for n = start, stop do
    table.insert(v, pattern.substitute_var(fn, index, {'int', n}))
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

  local res = pattern.substitute_var(fn, index, {'int', start})
  for n = start + 1, stop do
    res = {'+', res, pattern.substitute_var(fn, index, {'int', n})}
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

  local res = pattern.substitute_var(fn, index, {'int', start})
  for n = start + 1, stop do
    res = {'*', res, pattern.substitute_var(fn, index, {'int', n})}
  end

  return res
end

-- Find a common factor for u and v
function algo.common_factor(u, v)
  u = auto_simp(u)
  v = auto_simp(v)

  if lib.kind(u, 'int') and lib.kind(v, 'int') then
    return calc.gcd(u, v)
  elseif lib.kind(u, '*') then
    local f = lib.arg(u, 1)
    local r = algo.common_factor(f, v)

    return {'*', r, algo.common_factor({'/', u, f}, {'/', v, r})}
  elseif lib.kind(v, '*') then
    return algo.common_factor(v, u)
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

function algo.factor_out(u)
  u = auto_simp(u)
  if lib.kind(u, '*') then
    return lib.map(u, algo.factor_out)
  elseif lib.kind(u, '^') then
    return {'^', algo.factor_out(lib.arg(u, 1)), lib.arg(u, 2)}
  elseif lib.kind(u, '+') then
    local s = lib.map(u, algo.factor_out)
    if lib.num_args(s) == 1 then
      return lib.arg(s, 1)
    end

    local c = lib.arg(s, 1)
    for i = 2, lib.num_args(s) do
      c = algo.common_factor(c, lib.arg(s, i))
    end
    return {'*', c, lib.map(s, function(a) return auto_simp({'/', a, c}) end)}
  end
  return u
end

function algo.factor_out_term(u, t)
  if lib.kind(u, '+') then
    return {'*', t, lib.map(u, function(a) return auto_simp({'/', a, t}) end)}
  elseif lib.kind(u, '^') then
    return {'^', algo.factor_out_term(lib.arg(u, 1), t), lib.arg(u, 2)}
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
--@param u table  Expression to search in
--@param v table  Expression to check against
--@return boolean
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

-- Expands products of sums
--   (x + 2) (x + 3) => x^2 + 5 x + 6
--         x (x + 1) => x^2 + x
function algo.expand(u)
  local k = lib.kind(u)
  if k == '*' then
    local function expand_rec(a, i)
      local b = lib.arg(u, i)
      if not b then return a end

      if lib.kind(a, '+') or lib.kind(b, '+') then
        local aa = lib.kind(a, '+') and lib.get_args(a) or { a }
        local ba = lib.kind(b, '+') and lib.get_args(b) or { b }

        local n = { '+' }
        for x = 1, #aa do
          for y = 1, #ba do
            table.insert(n, { '*', aa[x], ba[y] })
          end
        end
        return expand_rec(n, i + 1)
      end
      return expand_rec({'*', a, b}, i + 1)
    end
    return expand_rec(lib.arg(u, 1), 2)
  else
    return lib.map(u, algo.expand)
  end
end

-- Return expression u with all trigonometric functions
-- replaced by a combination of sin and cos.
function algo.trig_subs(u)
  if lib.is_const(u) or lib.kind(u, 'sym', 'unit') then
    return u
  else
    u = lib.map(u, algo.trig_subs)
    if lib.kind(u, 'fn') then
      local f = lib.fn(u)
      local x = lib.arg(u, 1)

      if f == 'tan' then
        return {'/', {'fn', 'sin', x}, {'fn', 'cos', x}}
      elseif f == 'cot' then
        return {'/', {'fn', 'cos', x}, {'fn', 'sin', x}}
      elseif f == 'sec' then
        return {'/', {'int', 1}, {'fn', 'cos', x}}
      elseif f == 'csc' then
        return {'/', {'int', 1}, {'fn', 'sin', x}}
      end
    end

    return u
  end
end

-- Compute derivative of u with respect to x
function algo.derivative(u, x)
  assert(lib.kind(x, 'sym'))

  u = auto_simp(u)

  if lib.kind(u, 'sym') and lib.sym(u) == lib.sym(x) then
    return {'int', 1}
  elseif lib.kind(u, '^') then
    local v, w = lib.arg(u, 1), lib.arg(u, 2)
    return {'+', {'*', w, {'^', v, {'-', w, {'int', 1}}}, algo.derivative(v, x)},
                 {'*', algo.derivative(w, x), {'^', v, w}, {'fn', 'ln', v}}}
  elseif lib.kind(u, '+') then
    local v = lib.arg(u, 1)
    local w = {'-', u, lib.arg(u, 1)}
    return {'+', algo.derivative(v, x), algo.derivative(w, x)}
  elseif lib.kind(u, '*') then
    local v = lib.arg(u, 1)
    local w = {'/', u, v}
    return {'+', {'*', algo.derivative(v, x), w}, {'*', v, algo.derivative(w, x)}}
  elseif lib.kind(u, 'fn') and lib.fn(u, 'sin') then
    local v =lib.arg(u, 1)
    return {'*', {'fn', 'cos', v}, algo.derivative(v, x)}
  elseif algo.free_of(u, x) then
    return {'int', 0}
  else
    return {'fn', 'derivative', u, x}
  end
end

-- Compute zeros of u with respect to x and step-count s
function algo.newtons_method(fx, x, xn, s)
  assert(lib.kind(x, 'sym'))

  s = s or {'int', 1000}
  assert(lib.kind(s, 'int'))

  s = s[2]

  local eval = require 'eval'
  local output = require 'output'

  local fd = eval.eval(algo.derivative(fx, x))
  print('  '..' fd='..output.print_alg(fd))

  xn = xn or {'int', 1}
  for i = 1, s do
    local vx = eval.eval(algo.substitute_all(fx, x, xn))
    local vd = eval.eval(algo.substitute_all(fd, x, xn))
    print('  '..i..' xn='..output.print_alg(xn))
    print('  '..i..' fx='..output.print_alg(vx))
    print('  '..i..' dx='..output.print_alg(vd))

    local new_xn = eval.eval({'-', xn, {'/', vx, vd}})
    if lib.compare(xn, new_xn) then
      break
    end
    xn = new_xn
  end
  return eval.eval({'fn', 'real', xn})
end

return algo
