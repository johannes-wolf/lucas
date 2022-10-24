local lib = require 'lib'

local fraction = {}

-- Naive GCD algorithm
local function sgcd(a, b)
  return (b == 0 and a) or sgcd(b, a % b)
end

-- Create normalized fraction
---@param numerator number  Fraction numerator
---@param denominator number  Fraction denominator
---@return table  Fraction object
function fraction.make(numerator, denominator)
  assert(type(numerator) == 'number' and type(denominator) == 'number')

  if denominator < 0 then
    numerator = -1 * numerator
    denominator = -1 * denominator
  end

  local gcd = sgcd(numerator, denominator)
  if gcd == 1 then
    if denominator == 1 then
      return {'int', numerator}
    end
    return {'frac', num = numerator, denom = denominator}
  end

  if gcd == denominator then
    return {'int', numerator / denominator}
  end
  return {'frac', num = numerator / gcd, denom = denominator / gcd}
end

-- Test fraction f for equality with num/denom
---@param f table       Fraction or Integer to test
---@param num number    Numerator
---@param denom number  Denominator
function fraction.eq3(f, num, denom)
  if lib.kind(f, 'int') then
    return num == f[2] and denom == 1
  elseif lib.kind(f, 'frac') then
    return f.num == num and f.denom == denom
  end
  error('invalid type for f')
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
