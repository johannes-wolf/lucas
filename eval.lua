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

local eval = {}

-- Return numerator of value n
---@param n any
---@return number
function eval.numerator(n)
  if lib.kind(n, 'int', 'float') then
    return n[2]
  elseif lib.kind(n, 'frac') then
    return n.num
  end
  error('not implemented')
end

-- Return denominator of value n
---@param n any
---@return number
function eval.denominator(n)
  if lib.kind(n, 'frac') then
    return n.denom
  end
  return 1
end

-- Return the sign of number n
---@param n any
---@return number 1 if positive, -1 if negative or 0 if zero
function eval.sign(n)
  if lib.kind(n, 'int', 'float') then
    return (n[2] > 0 and 1) or (n[2] == 0 and 0) or -1
  elseif lib.kind(n, 'frac') then
    return (n.num > 0 and 1) or (n.num == 0 and 0) or -1
  end
end

function eval.is_zero(n)
  return eval.sign(n) == 0
end

-- Returns two pairs of values (num, denom) for a and b
---@param a table  Integer or fraction
---@param b table  Integer or fraction
---@return table
local function make_compat_fractions(a, b)
  assert(lib.kind(a, 'int', 'frac') and lib.kind(b, 'int', 'frac'))

  local denom = eval.denominator(a) * eval.denominator(b)
  return {num = eval.numerator(a) * eval.denominator(b), denom = denom},
         {num = eval.numerator(b) * eval.denominator(a), denom = denom}
end

local function try_make_non_float(a)
  if lib.kind(a, 'float') then
    a = a[2]

    local whole = math.floor(a)
    local frac = a - whole
    if frac == 0 then return {'int', whole} end
  end
  return a
end

local function get_as_float(a)
  if lib.kind(a, 'float') then
    return a[2]
  else
    return eval.numberator(a) / eval.denominator(a)
  end
end

local function maybe_get_as_float(a, b)
  a, b = try_make_non_float(a), try_make_non_float(b)
  if lib.kind(a, 'float') or lib.kind(b, 'float') then
    return get_as_float(a), get_as_float(b)
  end
end

function eval.eq(a, b)
  local v, w = maybe_get_as_float(a, b)
  if v and w then return v == w end

  a, b = make_compat_fractions(a, b)
  return a.num == b.num
end

function eval.lt(a, b)
  local v, w = maybe_get_as_float(a, b)
  if v and w then return v < w end

  a, b = make_compat_fractions(a, b)
  return a.num < b.num
end

function eval.lt_eq(a, b)
  return eval.lt(a, b) or eval.eq(a, b)
end

function eval.sum(a, b)
  -- TODO: Implement float support
  local denom = eval.denominator(a) * eval.denominator(b)
  return fraction.make(eval.numerator(a) * eval.denominator(b) + eval.numerator(b) * eval.denominator(a),
                       denom)
end

function eval.difference(a, b)
  -- TODO: Implement float support
  return eval.sum(a, eval.product({'int', -1}, b))
end

function eval.product(v, w)
  -- TODO: Implement float support
  return fraction.make(eval.numerator(v) * eval.numerator(w),
                       eval.denominator(v) * eval.denominator(w))
end

function eval.quotient(v, w)
  -- TODO: Implement float support
  if eval.numerator(w) == 0 then
    return 'undef' -- Division by zero
  end
  return fraction.make(eval.numerator(v) * eval.denominator(w),
                       eval.numerator(w) * eval.denominator(v))
end

-- Evaluate power (integer exponent)
---@param v any
---@param n number
function eval.power(v, n)
  -- TODO: Implement float support
  -- FIXME: Hack
  if type(n) == 'table' and n[1] == 'int' then
    n = n[2]
  end

  assert(type(n) == 'number')

  if eval.numerator(v) ~= 0 then
    if n > 0 then
      local s = eval.power(v, n - 1)
      return eval.product(s, v)
    elseif n == 0 then
      return {'int', 1}
    elseif n == -1 then
      return eval.quotient({'int', 1}, v)
    elseif n < -1 then
      return eval.quotient({'int', 1}, eval.power(v, -1 * n))
    end
  else
    if n >= 1 then
      return {'int', 0}
    else
      return 'undef'
    end
  end
end

return eval
