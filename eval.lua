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

function eval.sum(a, b)
  local denom = eval.denominator(a) * eval.denominator(b)
  return fraction.make(eval.numerator(a) * eval.denominator(b) + eval.numerator(b) * eval.denominator(a),
                       denom)
end

function eval.difference(a, b)
  return eval.sum(a, eval.product({'int', -1}, b))
end

function eval.product(v, w)
  return fraction.make(eval.numerator(v) * eval.numerator(w),
                       eval.denominator(v) * eval.denominator(w))
end

function eval.quotient(v, w)
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
