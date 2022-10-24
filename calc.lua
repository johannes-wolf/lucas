local fraction = require 'fraction'
local float = require 'float'
local lib = require 'lib'

local m = {}

function m.is_int(a)
  return a and a[1] == 'int'
end

function m.is_int_pos(a)
  return m.is_int(a) and a[2] > 0
end

function m.is_int_neg(a)
  return m.is_int(a) and a[2] < 0
end

local calc = {}

-- Return numerator of value n
---@param n any
---@return number
function calc.numerator(n)
  if lib.kind(n, 'int', 'real') then
    return n[2]
  elseif lib.kind(n, 'frac') then
    return n.num
  elseif lib.kind(n, 'bool') then
    return n[2] and 1 or 0
  end
  error('not implemented')
end

-- Return denominator of value n
---@param n any
---@return number
function calc.denominator(n)
  if lib.kind(n, 'frac') then
    return n.denom
  end
  return 1
end

-- Return the sign of number n
---@param n any
---@return number 1 if positive, -1 if negative or 0 if zero
function calc.sign(n)
  if lib.is_const(n) then
    n = calc.numerator(n)
    return (n > 0 and 1) or (n == 0 and 0) or -1
  else
    return 1
  end
end

function calc.is_zero(n)
  return calc.sign(n) == 0
end

-- Returns two pairs of values (num, denom) for a and b
---@param a table  Integer or fraction
---@param b table  Integer or fraction
---@return table
local function make_compat_fractions(a, b)
  assert(lib.kind(a, 'int', 'frac') and lib.kind(b, 'int', 'frac'))

  local denom = calc.denominator(a) * calc.denominator(b)
  return {num = calc.numerator(a) * calc.denominator(b), denom = denom},
         {num = calc.numerator(b) * calc.denominator(a), denom = denom}
end

local function try_make_non_float(a)
  if lib.kind(a, 'real') then
    a = a[2]

    local whole = math.floor(a)
    local frac = a - whole
    if frac == 0 then return {'int', whole} end
  end
  return a
end

local function get_as_float(a)
  if lib.kind(a, 'real') then
    return a[2]
  else
    return calc.numberator(a) / calc.denominator(a)
  end
end

local function maybe_get_as_float(a, b)
  a, b = try_make_non_float(a), try_make_non_float(b)
  if lib.kind(a, 'real') or lib.kind(b, 'real') then
    return get_as_float(a), get_as_float(b)
  end
end

function calc.eq(a, b)
  local v, w = maybe_get_as_float(a, b)
  if v and w then return {'bool', v == w} end

  a, b = make_compat_fractions(a, b)
  return {'bool', a.num == b.num}
end

function calc.neq(a, b)
  return {'bool', not calc.eq(a, b)}
end

function calc.lt(a, b)
  local v, w = maybe_get_as_float(a, b)
  if v and w then return {'bool', v < w} end

  a, b = make_compat_fractions(a, b)
  return {'bool', a.num < b.num}
end

function calc.lteq(a, b)
  local lt = calc.lt(a, b)
  if not calc.is_true(lt) then
    return calc.eq(a, b)
  end
  return lt
end

function calc.gt(a, b)
  local v, w = maybe_get_as_float(a, b)
  if v and w then return {'bool', v > w} end

  a, b = make_compat_fractions(a, b)
  return {'bool', a.num > b.num}
end

function calc.gteq(a, b)
  local lt = calc.gt(a, b)
  if not calc.is_true(lt) then
    return calc.eq(a, b)
  end
  return lt
end

function calc.is_true(u)
  if type(u) == 'boolean' then
    return u
  end
  if lib.is_const(u) then
    if lib.kind(u, 'bool') then return u[2] end

    return calc.is_true(calc.neq(u, {'int', 0}))
  else
    return false
  end
end

function calc.sum(a, b)
  -- TODO: Implement float support
  local denom = calc.denominator(a) * calc.denominator(b)
  return fraction.make(calc.numerator(a) * calc.denominator(b) + calc.numerator(b) * calc.denominator(a),
                       denom)
end

function calc.difference(a, b)
  -- TODO: Implement float support
  return calc.sum(a, calc.product({'int', -1}, b))
end

function calc.product(v, w)
  -- TODO: Implement float support
  return fraction.make(calc.numerator(v) * calc.numerator(w),
                       calc.denominator(v) * calc.denominator(w))
end

function calc.quotient(v, w)
  -- TODO: Implement float support
  if calc.numerator(w) == 0 then
    return 'undef' -- Division by zero
  end
  return fraction.make(calc.numerator(v) * calc.denominator(w),
                       calc.numerator(w) * calc.denominator(v))
end

-- Calcuate power (integer exponent)
---@param v any
---@param n number
function calc.power(v, n)
  -- TODO: Implement float support
  -- FIXME: Hack
  if type(n) == 'table' and n[1] == 'int' then
    n = n[2]
  end

  assert(type(n) == 'number')

  if calc.numerator(v) ~= 0 then
    if n > 0 then
      local s = calc.power(v, n - 1)
      return calc.product(s, v)
    elseif n == 0 then
      return {'int', 1}
    elseif n == -1 then
      return calc.quotient({'int', 1}, v)
    elseif n < -1 then
      return calc.quotient({'int', 1}, calc.power(v, -1 * n))
    end
  else
    if n >= 1 then
      return {'int', 0}
    else
      return 'undef'
    end
  end
end

return calc
