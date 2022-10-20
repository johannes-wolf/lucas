local lib = require 'lib'
local kind, num_args, arg = lib.kind, lib.num_args, lib.arg

local poly = {}

-- Get degree of expression as integer
---@param expr table
---@return number
function poly.degree(expr)
  if lib.is_prim(expr) then
    return kind(expr, 'sym') and 1 or 0
  elseif kind(expr, '-') and num_args(expr) == 1 then
    return poly.degree(arg(expr, 1))
  elseif kind(expr, '*') then
    return lib.sum_args(expr, function(v)
                          return poly.degree(v)
    end)
  elseif kind(expr, '/') then
    return poly.degree(arg(expr, 1)) - poly.degree(arg(expr, 2))
  elseif kind(expr, '^') and lib.is_natnum(arg(expr, 2)) then
    return poly.degree(arg(expr, 1)) * arg(expr, 2)[2]
  elseif kind(expr, '+', '-') then
    return math.max(poly.degree(arg(expr, 1)),
                    poly.degree(arg(expr, 2)))
  else
    return 1
  end
end

-- Find polynom variable
function poly.lead(expr)
end

return poly
