local cmath = require 'cmath'
local fraction = {}

-- Create normalized fraction
---@param numerator number  Fraction numerator
---@param denominator number  Fraction denominator
---@return table  Fraction object
function fraction.make(numerator, denominator)
  assert(type(numerator) == 'number' and type(denominator) == 'number')
  assert(math.floor(numerator) == numerator and math.floor(denominator) == denominator)

  if cmath.is_neg(denominator) then
    numerator = cmath.neg(numerator)
    denominator = cmath.neg(denominator)
  end

  local gcd = cmath.gcd(numerator, denominator)
  if gcd == 1 then
    if denominator == 1 then
      return {'int', numerator}
    end
    return {'frac', num = numerator, denom = denominator}
  end

  if gcd == denominator then
    return {'int', cmath.div(numerator, denominator)}
  end
  return {'frac', num = cmath.div(numerator, gcd), denom = cmath.div(denominator, gcd)}
end

-- Check value for fraction
---@param a table  Value
---@return boolean  Returns true if a is of type fraction
function fraction.isa(a)
  return type(a) == 'table' and a[1] == 'frac'
end

-- Returns input object a if it is a fraction
---@param a any  Possible fraction
---@return table|nil
function fraction.safe_get(a)
  if fraction.isa(a) then return a end
end

-- Apply function fn on numerator and denominator
---@param a table  Fraction
---@param fn function  Function
---@return table  Fraction
function fraction.apply(a, fn)
  return fraction.make(fn(a.num), fn(a.denom))
end

-- Return numerator and denumerator
---@param a table  Fraction
---@return number  Numerator
---@return number  Denominator
function fraction.split(a)
  if fraction.isa(a) then
    return a.num, a.denom
  end
end

function fraction.add(a, b)
  if fraction.isa(a) then
    if fraction.isa(b) then
      return fraction.make(cmath.add(cmath.mul(a.num, b.denom), cmath.mul(b.num, a.denom)),
                           cmath.mul(a.denom, b.denom))
    else
      return fraction.make(cmath.add(a.num, cmath.mul(a.denom, b)),
                           a.denom)
    end
  else
      return fraction.make(cmath.add(b.num, cmath.mul(b.denom, a)),
                           b.denom)
  end
end

function fraction.mul(a, b)
  if fraction.isa(a) then
    if fraction.isa(b) then
      return fraction.make(cmath.mul(a.num, b.num),
                           cmath.mul(a.denom, b.denom))
    else
      return fraction.make(cmath.mul(a.num, b),
                           a.denom)
    end
  else
    return fraction.make(cmath.mul(b.num, a),
                         b.denom)
  end
end

function fraction.div(a, b)
  if fraction.isa(a) then
    if fraction.isa(b) then
      return fraction.make(cmath.mul(a.num, b.denom),
                           cmath.mul(a.denom, b.num))
    else
      return fraction.make(a.num,
                           cmath.mul(a.denom, b))
    end
  else
    return fraction.make(b.num,
                         cmath.mul(b.denom, a))
  end
end

-- Convert fraction to float
---@param a table  Fraction
---@return number  Floating point representation
function fraction.to_float(a)
  if fraction.isa(a) then
    return cmath.div(a.num, a.denom)
  end
  return a
end

-- Return string representation
---@param a table  Fraction
---@return string
function fraction.to_string(a)
  return string.format('%d:%d', a.num, a.denom)
end

return fraction
