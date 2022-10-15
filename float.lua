local lib = require 'base'

local float = {}

function float.make(v)
  if type(v) == 'number' then
    if math.floor(v) ~= v then
      return {'float', v}
    else
      return {'int', math.floor(v)}
    end
  end

  if lib.kind(v, 'frac') then
    return float.make(v.num / v.denom)
  elseif lib.kind(v, 'int') then
    return float.make(v[2])
  end

  return v
end

function float.force(v)
  if lib.kind(v, 'frac') then
    v = v.num / v.denom
  elseif lib.kind(v, 'int') then
    v = v[2]
  end
  return {'float', v}
end

function float.is_zero(v)
  return v[2] == 0
end

function float.lt(u, v)
  u = float.force(u)
  v = float.force(v)
  return u[2] < v[2]
end

return float
