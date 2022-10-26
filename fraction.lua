local lib = require 'lib'

local fraction = {}

local function sgcd(a, b)
  return (b == 0 and a) or sgcd(b, a % b)
end

function fraction.normalize(f)
  local num, denom = f[2], f[3]
  if denom < 0 then
    num = -1 * num
    denom = -1 * denom
  end

  local gcd = sgcd(num, denom)
  if gcd == 1 then
    if denom == 1 then
      return {'int', num}
    end
    return {'frac', num, denom}
  end

  if gcd == denom then
    return {'int', num / denom}
  end
  return {'frac', num / gcd, denom / gcd}
end

-- Create normalized fraction
---@param numerator number  Fraction numerator
---@param denominator number  Fraction denominator
---@return table  Fraction object
function fraction.make(numerator, denominator)
  assert(type(numerator) == 'number' and type(denominator) == 'number')

  return fraction.normalize({'frac', numerator, denominator})
end

return fraction
