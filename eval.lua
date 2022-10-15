local fraction = require 'fraction'
local float = require 'float'
local lib = require 'base'

local m = {}

function m.is_zero(a)
  if a[1] == 'int'   then return a[2] == 0 end
  if a[1] == 'float' then return a[2] == 0 end
  if a[1] == 'frac'  then return a.num == 0 end
  return false
end

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
  if n[1] == 'int' then return n[2] end
  if n[1] == 'frac' then return n.num end
  --error('eval.numerator: not implemented for type '..n[1])
  return 1
end

-- Return denominator of value n
---@param n any
---@return number
function eval.denominator(n)
  if n[1] == 'frac' then return n.denom end
  return 1
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
