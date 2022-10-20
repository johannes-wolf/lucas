local util = require 'util'

local base = {}

-- Get (or compare) expression kind
function base.kind(expr, ...)
  if not expr then return nil end
  if select('#', ...) > 0 then
    return util.set.contains({...}, expr[1])
  end
  return expr[1]
end

-- Get (or compare) expression function name (if kind = 'fn')
function base.fn(u, ...)
  if not u or not base.kind(u, 'fn') then return nil end
  if select('#', ...) > 0 then
    return util.set.contains({...}, u[1])
  end
  return u[1]
end

-- Get argument offset
function base.arg_offset(u)
  return (base.kind(u, 'fn', 'sym', 'unit') and 2) or 1
end

-- Get number of arguments
function base.num_args(u)
  if base.kind(u, 'int', 'frac', 'float', 'unit', 'sym') then return 0 end
  return u and #u - base.arg_offset(u) or 0
end

-- Get nth arg
function base.arg(u, n)
  return u and u[n + base.arg_offset(u)] or nil
end

-- Get arguments as list
function base.get_args(u)
  return util.list.slice(u, 1 + base.arg_offset(u))
end

-- Apply function on each operand/argument
---@param fn function  Function to apply
---@param u table      Operands
---@return table       Copy of op with fn applied
function base.map(u, fn, ...)
  if base.num_args(u) > 0 then
    return util.list.join(util.list.slice(u, 1, base.arg_offset(u)),
                          util.list.map(base.get_args(u), fn, ...))
  else
    return u
  end
end

-- Apply summation function on operands and return the result
function base.sum(u, fn, ...)
  local s = 0
  if base.num_args(u) > 0 then
    for i = base.arg_offset(u) + 1, #u do
      s = s + fn(u[i], ...)
    end
  end
  return s
end

-- Is natural number
function base.is_natnum(expr)
  if base.kind(expr, 'int') then
    return expr[2] >= 0
  end
end

-- Return if expr is a primitive
function base.is_prim(expr) -- TODO: Remove me
  return base.kind(expr, 'int', 'frac', 'float') -- Primary
end

return base
