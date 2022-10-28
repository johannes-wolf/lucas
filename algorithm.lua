local lib = require 'lib'
local util = require 'util'
local pattern = require 'pattern'
local dbg = require 'dbg'

local algo = {}

-- Parse 3 arguments of type index, start, stop
-- Supporting the following combinations
--   index, start, stop
--   index=start, stop
--   intv
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

function algo.map(fn, vec)
  local name = lib.safe_sym(fn) or lib.safe_fn(fn)
  if not name then return nil end

  local rest = lib.kind(fn, 'fn') and lib.get_args(fn, 2)

  if lib.kind(vec, 'vec') then
    return lib.map(vec, function(v)
      if rest then
        return util.list.join({'fn', name, v}, rest)
      else
        return {'fn', name, v}
      end
    end)
  else
    return {'fn', name, vec}
  end
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


-- Returns a sub-expression list of expression u
---@param u table
---@return table
function algo.complete_sub_expr(u)
  if lib.is_const(u) or lib.kind(u, 'sym', 'unit') then
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

-- Replace symbol s with expression v
function algo.substitute_all(expr, s, v)
  assert(lib.kind(s, 'sym'))
  if lib.kind(expr, 'sym')  and lib.sym(expr) == lib.sym(s) then
    return v
  --elseif lib.kind(expr, 'fn') then
    -- Do not alter function args!
    --return expr
  else
    return lib.map(expr, algo.substitute_all, s, v)
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

  local simplify = require 'simplify'
  u = simplify.expr(u)

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

function algo.iterate(fx, x, start, n)
  local eval = require 'eval'

  -- FIXME
  if n then n = n[2] else n = 10 end

  local xv = start
  for _ = 1, n do
    xv = eval.eval(pattern.substitute_var(fx, lib.sym(x), xv))
  end
  return xv
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
