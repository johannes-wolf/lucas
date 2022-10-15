local input = require 'input'
local output = require 'output'
local util = require 'util'
local fraction = require 'fraction'
local float = require 'float'
local eval = require 'eval'
local units = require 'units'

local lib = require 'base'
local kind, map = lib.kind, lib.map

local function rule(r)
  --print('> '..r)
end

-- Returns if u is a constant value
local function is_const(u)
  return kind(u, 'int', 'frac', 'float')
end

-- Returns if u is equal to zero
local function is_zero(u)
  if kind(u, 'int') then
    return u[2] == 0
  elseif kind(u, 'frac') then
    return u.num == 0
  elseif kind(u, 'float') then
    return float.is_zero(u)
  else
    return false
  end
end

local function is_int_eq(u, n)
  if kind(u, 'int') then
    return u[2] == n
  elseif kind(u, 'frac') then
    return u.num == n * u.denom
  else
    return false
  end
end

-- Returns the function name of a function
local function fn(u)
  if kind(u, 'fn') then
    return u[2]
  end
end

local function unit(u)
  if kind(u, 'unit') then
    return u[2]
  end
end

-- Return base of an expression
-- Example:
--   x^2 => x
--   x   => x
local function base(u)
  if kind(u, 'sym', 'unit', '*', '+', '!', 'fn') then
    return u
  elseif kind(u, '^') then
    return u[2]
  elseif kind(u, 'int', 'frac', 'float') then
    return 'undef'
  else
    error('unreachable kind='..kind(u))
  end
end

-- Return exponent of an expression
-- Example:
--   x^2 => 2
--   x   => 1
local function exponent(u)
  if kind(u, 'sym', 'unit', '*', '+', '!', 'fn') then
    return {'int', 1}
  elseif kind(u, '^') then
    return u[3]
  elseif kind(u, 'int', 'frac', 'float') then
    return 'undef'
  else
    error('unreachable kind='..kind(u))
  end
end

-- Returns the non-const term of an expression as product (variable)
-- Example:
--   x   => *x
--   2*y => *y
--   x*y => x*y
local function term(u)
  if kind(u, 'sym', 'unit', '+', '^', '!', 'fn') then
    -- Return the uession as binary product (* u)
    return {'*', u}
  elseif kind(u, '*') and is_const(lib.arg(u, 1)) then
    -- Return all but the first argument (* u_2..u_n)
    return util.list.join('*', util.list.slice(u, 3))
  elseif kind(u, '*') and not is_const(lib.arg(u, 1)) then
    -- Return the full exrpression (u)
    return u
  elseif kind(u, 'int', 'frac', 'float') then
    return 'undef'
  else
    error('unreachable')
  end
end

-- Returns the constant factor of an expression as product (coefficient)
-- Example:
--   x   => 1
--   2*y => 2
--   x*y => 1
local function const(expr)
  if kind(expr, 'sym', 'unit', '+', '^', '!', 'fn') then
    -- Return constant factor (1)
    return {'int', 1}
  elseif kind(expr, '*') and is_const(lib.arg(expr, 1)) then
    -- Return first argument (u_1)
    return lib.arg(expr, 1)
  elseif kind(expr, '*') and not is_const(lib.arg(expr, 1)) then
    -- Return constant factor (1)
    return {'int', 1}
  elseif kind(expr, 'int', 'frac', 'float') then
    return 'undef'
  else
    error('unreachable')
  end
end

-- Returns if u is less than v
local function is_less(u, v)
  if kind(u, 'int') and kind(v, 'int') then
    return u[2] < v[2]
  elseif kind(u, 'frac') and kind(v, 'int') then
    return u.num < v[2] * u.denom
  elseif kind(v, 'frac') and kind(u, 'int') then
    return u[2] * v.denom < v.num
  elseif kind(u, 'frac') and kind(v, 'frac') then
    return u.num * v.denom < v.num * u.denom
  elseif kind(u, 'float') or kind(v, 'float') then
    return float.lt(u, v)
  else
    error('not implemented')
  end
end

-- Return if u comes before v (u < v)
---@param u table
---@param v table
---@return boolean
local function order_before(u, v)
  local function find_neq(x, y, offset)
    for i = offset or 2, math.min(#x, #y) do
      if not util.table.compare(x[i], y[i]) then
        return x[i], y[i], i
      end
    end
  end

  local function find_neq_rev(x, y)
    for i = 0, math.min(#x, #y) - 1 do
      if not util.table.compare(x[#x - i], y[#y - i]) then
        return x[#x - i], y[#y - i], i
      end
    end
  end

  if type(u) == 'string' and type(v) == 'string' then
    return u < v
  elseif type(u) == 'number' and type(v) == 'number' then
    return u < v
  end

  if is_const(u) and is_const(v) then
    return is_less(u, v)
  elseif kind(u, 'sym') and kind(v, 'sym') or
         kind(u, 'unit') and kind(v, 'unit') then
    return u[2] < v[2]
  elseif (kind(u, '+') and kind(v, '+')) or (kind(u, '*') and kind(v, '*')) then
    local um, vm = find_neq_rev(u, v)
    if um and vm then
      return order_before(um, vm)
    end
    return #u < #v
  elseif kind(u, '^') and kind(v, '^') then
    if not util.table.compare(base(u), base(v)) then
      return order_before(base(u), base(v))
    end
    return order_before(exponent(u), exponent(v))
  elseif kind(u, '!') and kind(v, '!') then
    return order_before(u[2], v[2])
  elseif kind(u, 'fn') and kind(v, 'fn') then
    if fn(u) ~= fn(v) then
      return fn(u) < fn(v)
    end

    local um, vm = find_neq(u, v, 3)
    if um and vm then
      return order_before(um, vm)
    end
    return #u < #v
  elseif is_const(u) and not is_const(v) then
    return true
  elseif kind(u, '*') and kind(v, '^', '+', '!', 'fn', 'sym', 'unit') then
    return order_before(u, {'*', v})
  elseif kind(u, '^') and kind(v, '+', '!', 'fn', 'sym', 'unit') then
    return order_before(u, {'^', v, {'int', 1}})
  elseif kind(u, '+') and kind(v, '!', 'fn', 'sym', 'unit') then
    return order_before(u, {'+', v})
  elseif kind(u, '!') and kind(v, 'fn', 'sym', 'unit') then
    if util.table.compare(u[2], v) then
      return false
    else
      return order_before(u, {'!', v})
    end
  elseif kind(u, 'fn') and kind(v, 'sym', 'unit') then
    if fn(u) == v[2] then
      return false
    else
      order_before(fn(u), v[2])
    end
  elseif kind(u, 'sym') and kind(v, 'unit') then
    -- Order units last!
    return true
  else
    return not order_before(v, u)
  end
end

-- Simplification rules functions
local simplify = {}

-- Note: Does not return a product operator, but its arguments!
function simplify.merge_products(p, q)
  assert(type(p) == 'table')
  if #p > 0 then assert(type(p[1]) == 'table') end
  assert(type(q) == 'table')
  if #q > 0 then assert(type(q[1]) == 'table') end

  if not q or #q == 0 then -- MPRD-1
    return p
  elseif not p or #p == 0 then -- MPRD-2
    return q
  else -- MPRD-3
    local p1, q1 = p[1], q[1]
    local h = simplify.product_rec({p1, q1})

    if #h == 0 then -- 1
      return simplify.merge_products(util.list.rest(p), util.list.rest(q))
    elseif #h == 1 then -- 2
      return util.list.join(h, simplify.merge_products(util.list.rest(p), util.list.rest(q)))
    elseif #h == 2 and util.table.compare(h[1], p1) and util.table.compare(h[2], q1) then -- 3
      return util.list.join({p1}, simplify.merge_products(util.list.rest(p), q))
    elseif #h == 2 and util.table.compare(h[1], q1) and util.table.compare(h[2], p1) then -- 4
      return util.list.join({q1}, simplify.merge_products(p, util.list.rest(q)))
    end
  end
end

-- Note: Does not return a sum operator, but its arguments!
function simplify.merge_sums(p, q)
  if not q or #q == 0 then
    return p
  elseif not p or #p == 0 then
    return q
  else
    local p1, q1 = p[1], q[1]
    local h = simplify.sum_rec({p1, q1})

    if #h == 0 then
      return simplify.merge_sums(util.list.rest(p), util.list.rest(q))
    elseif #h == 1 then
      return util.list.join(h, simplify.merge_sums(util.list.rest(p), util.list.rest(q)))
    elseif #h == 2 and util.table.compare(h[1], p1) and util.table.compare(h[2], q1) then
      return util.list.join({p1}, simplify.merge_sums(util.list.rest(p), q))
    elseif #h == 2 and util.table.compare(h[1], q1) and util.table.compare(h[2], p1) then
      return util.list.join({q1}, simplify.merge_sums(p, util.list.rest(q)))
    end
  end
end

local function is_unary(e)
  return lib.num_args(e) == 1
end

local function is_binary(e)
  return lib.num_args(e) == 2
end

function simplify.rational_number(u)
  if kind(u, 'int') then
    return u
  elseif kind(u, 'frac') then
    return u -- TODO: Either remove this function, or do not simplify fractions by default
  end
end

function simplify.rne_rec(u)
  assert(lib.num_args(u) <= 2)

  local k = kind(u)
  if k == 'int' or k == 'float' then
    return u
  elseif k == 'frac' then
    if u.denom == 0 then
      return 'undef'
    else
      return u
    end
  elseif k == 'unit' then
    return u
  elseif is_unary(u) then
    local v = simplify.rne_rec(u[2])
    if v == 'undef' then
      return 'undef'
    elseif kind(v, '+') then
      return v
    elseif kind(v, '-') then
      return eval.product(-1, v)
    end
  elseif is_binary(u) then
    if kind(u, '+', '*', '-', '/') then
      local v, w = simplify.rne_rec(u[2]), simplify.rne_rec(u[3])
      if v == 'undef' or w == 'undef' then
        return 'undef'
      else
        if kind(u, '+') then
          return eval.sum(v, w)
        elseif kind(u, '*') then
          return eval.product(v, w)
        elseif kind(u, '-') then
          return eval.difference(v, w)
        elseif kind(u, '/') then
          return eval.quotient(v, w)
        end
      end
    elseif kind(u, '^') then
      local v = simplify.rne_rec(u[2])
      if v == 'undef' then
        return 'undef'
      end
      return eval.power(v, u[3])
    end
  end
end

-- Simplify rational number expression (rne)
function simplify.rne(u)
  local v = simplify.rne_rec(u)
  if v == 'undef' then
    return 'undef'
  end
  return simplify.rational_number(v)
end

-- Simplify product arguments
---@param l table  List of arguments
---@return table   Simplified list of arguments
function simplify.product_rec(l)
  assert(type(l) == 'table')

  local a, b = l[1], l[2]
  if #l == 2 and kind(a) ~= '*' and kind(b) ~= '*' then
    rule('SPRDREC-1')
    if is_const(a) and is_const(b) then
      rule('SPRDREC-1.1')
      local r = simplify.rne({'*', a, b})
      if is_int_eq(r, 1) then
        return {}
      else
        return {r}
      end
    elseif is_int_eq(a, 1) then
      rule('SPRDREC-1.2.1')
      return {b}
    elseif is_int_eq(b, 1) then
      rule('SPRDREC-1.2.2')
      return {a}
    elseif util.table.compare(base(a), base(b)) then
      rule('SPRDREC-1.3')
      local s = simplify.sum({'+', exponent(a), exponent(b)})
      local p = simplify.power({'^', base(a), s})
      if is_int_eq(p, 1) then
        return {}
      else
        return {p}
      end
    elseif order_before(b, a) then
      rule('SPRDREC-1.4')
      return {b, a}
    else
      rule('SPRDREC-1.5')
      return l
    end
  elseif #l == 2 and (kind(a, '*') or kind(b, '*')) then
    rule('SPRDREC-2')
    if kind(a, '*') and kind(b, '*') then
      return simplify.merge_products(util.list.rest(a), util.list.rest(b))
    elseif kind(a, '*') then
      return simplify.merge_products(util.list.rest(a), {b})
    elseif kind(b, '*') then
      return simplify.merge_products({a}, util.list.rest(b))
    end
  elseif #l > 2 then
    rule('SPRDREC-3')
    local w = simplify.product_rec(util.list.rest(l))
    if kind(a, '*') then
      return simplify.merge_products(util.list.rest(a), w)
    else
      return simplify.merge_products({a}, w)
    end
  end

  error('unreachable (SPRDREC)')
end

function simplify.product(expr)
  assert(kind(expr, '*'))

  if util.set.contains(expr, 'undef') then
    rule('SPRD-1')
    return 'undef'
  elseif util.set.contains(expr, {'int', 0}) then
    rule('SPRD-2')
    return {'int', 0}
  elseif is_unary(expr) then
    rule('SPRD-3')
    return expr[2]
  else
    rule('SPRD-4')
    local v = simplify.product_rec(util.list.rest(expr)) or {}
    if #v == 1 then
      rule('SPRD-4.1')
      return v[1]
    elseif #v >= 2 then
      rule('SPRD-4.2')
      return util.list.join('*', v)
    elseif #v == 0 then
      rule('SPRD-4.3')
      return {'int', 1}
    end
  end
end

function simplify.sum_rec(l)
  assert(type(l) == 'table')

  local a, b = l[1], l[2]
  if #l == 2 and kind(a) ~= '+' and kind(b) ~= '+' then
    if is_const(a) and is_const(b) then
      local r = simplify.rne({'+', a, b})
      if is_zero(r) then
        return {}
      else
        return {r}
      end
    elseif is_zero(a) then
      return {b}
    elseif is_zero(b) then
      return {a}
    elseif util.table.compare(term(a), term(b)) then
      local s = simplify.sum({'+', const(a), const(b)})
      local p = simplify.product({'*', s, term(a)})
      if is_zero(p) then
        return {}
      else
        return {p}
      end
    elseif order_before(b, a) then
      return {b, a}
    else
      return l
    end
  elseif #l == 2 and (kind(a, '+') or kind(b, '+')) then
    if kind(a, '+') and kind(b, '+') then
      return simplify.merge_sums(util.list.rest(a), util.list.rest(b))
    elseif kind(a, '+') then
      return simplify.merge_sums(util.list.rest(a), {b})
    elseif kind(b, '+') then
      return simplify.merge_sums({a}, util.list.rest(b))
    end
  elseif #l > 2 then
    local w = simplify.sum_rec(util.list.rest(l))
    if kind(a, '+') then
      return simplify.merge_sums(util.list.rest(a), w)
    else
      return simplify.merge_sums({a}, w)
    end
  end

  error('unreachable (SPRDREC)')
end

function simplify.sum(u)
  assert(kind(u, '+'))

  if util.set.contains(u, 'undef') then
    return 'undef'
  elseif is_unary(u) then
    return u[2]
  else
    local v = simplify.sum_rec(util.list.rest(u)) or {}
    if #v == 1 then
      return v[1]
    elseif #v >= 2 then
      return util.list.join('+', v)
    elseif #v == 0 then
      return {'int', 0}
    end
  end
end

-- Simplify power a^b with b of type int
---@param expr table
---@return table
function simplify.int_power(expr)
  assert(kind(expr, '^'))
  assert(kind(expr[3], 'int'))

  local b, e = expr[2], expr[3]
  local n = e[2] -- e is of kind 'int'
  if kind(b, 'int', 'frac') then -- SINTPOW-1
    return simplify.rne({'^', b, e})
  elseif n == 0 then -- SINTPOW-2
    return {'int', 1}
  elseif n == 1 then -- SINTPOW-3
    return b
  elseif kind(b, '^') then -- SINTPOW-4
    local r, s = b[2], b[3]
    local p = simplify.product({'*', s, n})
    if kind(p, 'int') then
      return simplify.int_power({'^', r, p})
    else
      return {'^', r, p}
    end
  elseif kind(b, '*') then -- SINTPOW-5
    local r = lib.map(b, function(arg)
                        return simplify.int_power({'^', arg, {'int', n}})
    end)
    return simplify.product(r)
  else -- SINTPOW-6
    return {'^', b, e}
  end
end

-- Simplify power a^b
---@param expr table
---@return table
function simplify.power(expr)
  assert(kind(expr, '^'))

  local b, e = base(expr), exponent(expr)
  if b == 'undef' or e == 'undef' then -- SPOW-1
    return 'undef'
  else
    if is_zero(b) then -- SPOW-2
      if true then -- FIXME: is positive?
        return {'int', 0}
      else
        return 'undef'
      end
    elseif is_int_eq(b, 1) then -- SPOW-3
      return {'int', 1}
    elseif kind(e, 'int') then -- SPOW-4
      return simplify.int_power(expr)
    else -- SPOW-5
      return expr
    end
  end
end

function simplify.quotient(u)
  assert(kind(u, '/'))

  local p = simplify.power({'^', u[3], {'int', -1}})
  return simplify.product({'*', u[2], p})
end

function simplify.difference(u)
  assert(kind(u, '-'))

  if is_unary(u) then
    return simplify.product({'*', {'int', -1}, u[2]})
  else
    local d = simplify.product({'*', {'int', -1}, u[3]})
    return simplify.sum({'+', u[2], d})
  end
end

function simplify.factorial(u)
  error('not implemented')
end

-- Convert unit of expression u to unit t
---@param u table  Input expression
---@param t table  Target unit
local function convert_units(u, t)
  if not kind(t, 'unit') then
    return 'undef'
  end

  local f = unit(t)
  if not f then
    return 'undef'
  elseif not units.table[f].value then
    return u
  end

  return {'*', simplify.expr({'/', u, units.table[f].value}), t}
end

function simplify.fn(u)
  local f = fn(u)

  if f == 'conv' then
    return convert_units(simplify.expr(lib.arg(u, 1)), lib.arg(u, 2))
  elseif f == 'approx' then
    return float.make(simplify.expr(lib.arg(u, 1)))
  else
    return lib.map(u, simplify.expr)
  end
end

function simplify.expr(expr)
  if kind(expr, 'sym', 'int', 'float') then
    return expr
  elseif kind(expr, 'unit') then
    if units.table[unit(expr)].value then
      return simplify.expr(units.table[unit(expr)].value)
    end
    return expr
  elseif kind(expr, 'frac') then
    return simplify.rational_number(expr)
  elseif kind(expr, 'fn') then
    return simplify.fn(expr)
  else
    local v = lib.map(expr, simplify.expr)
    local k = lib.kind(v)
    if k == '^' then
      return simplify.power(v)
    elseif k == '*' then
      return simplify.product(v)
    elseif k == '+' then
      return simplify.sum(v)
    elseif k == '/' then
      return simplify.quotient(v)
    elseif k == '-' then
      return simplify.difference(v)
    elseif k == '!' then
      return simplify.factorial(v)
    end
  end
end


function dump(o)
  if type(o) == "table" then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end


while true do
  local expr = input.read_expression(io.read('l'))
  --print('input: ' .. output.print_sexp(expr))

  local simpl = simplify.expr(expr)
  --print('  = ' .. output.print_sexp(simpl))
  print('  = ' .. output.print_alg(simpl))
end
