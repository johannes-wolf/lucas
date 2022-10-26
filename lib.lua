local util = require 'util'

local base = {}

---@alias Expression table
---@alias Associativity
---| 'left'
---| 'right'
---@alias Kind
---| 'bool'
---| 'int'
---| 'frac'
---| 'real'
---| 'sym'
---| 'unit'
---| 'fn'

function base.safe_bool(val, def)
  if base.kind(val, 'bool') then return val[2] end
  return def
end

function base.safe_int(val)
  if base.kind(val, 'int') then return val[2] end
end

function base.safe_sym(val)
  if base.kind(val, 'sym') then return base.sym(val) end
end

function base.safe_unit(val)
  if base.kind(val, 'unit') then return base.unit(val) end
end

function base.safe_fn(val)
  if base.kind(val, 'fn') then return base.fn(val) end
end

-- Get (or compare) expression kind
---@param expr Expression
---@return boolean|Kind
function base.kind(expr, ...)
  if not expr then return false end
  --assert(type(expr) == 'table') -- THERE IS A BUG IN COMPARE WHICH PASSES STRINGS TO KIND
  if select('#', ...) > 0 then
    return util.set.contains({...}, expr[1])
  end
  return expr[1]
end

-- Returns whether u is const
---@param u Expression
function base.is_const(u)
  return base.kind(u, 'int', 'real', 'frac', 'bool')
end

-- Returns whether u is a relational operator
function base.is_relop(u)
  return base.kind(u, '=', '!=', '>', '>=', '<', '<=')
end

-- Get (or compare) expression function name (if kind = 'fn')
function base.fn(u, ...)
  if not u or not base.kind(u, 'fn') then return nil end
  if select('#', ...) > 0 then
    return util.set.contains({...}, u[2])
  end
  return u[2]
end

-- Get (or compare) expression function name (if kind = 'sym')
function base.sym(u, ...)
  if not u or not base.kind(u, 'sym') then return nil end
  if select('#', ...) > 0 then
    return util.set.contains({...}, u[2])
  end
  return u[2]
end

-- Get (or compare) expression function name (if kind = 'sym')
function base.unit(u, ...)
  if not u or not base.kind(u, 'unit') then return nil end
  if select('#', ...) > 0 then
    return util.set.contains({...}, u[2])
  end
  return u[2]
end

-- Get if operator is varargs
---@param k Kind    Kind
---@return boolean  True if kind k is an operator with varargs
function base.is_vararg_operator(k)
  return base.kind(k, '+', '*')
end

-- Return binary operator if input operatr is a vararg operator with more than
-- two operands.
---@param u     Expression     Input expression
---@param assoc Associativity  Opertator associativity
---@return      Expression
function base.make_binary_operator(u, assoc)
  assoc = assoc or 'right'

  if base.is_vararg_operator(u) then
    if base.num_args(u) > 2 then
      local k = base.kind(u)
      if assoc == 'right' then
        return {k, base.arg(u, 1), util.list.join({k}, base.get_args(u, 2))}
      else
        return {k, util.list.join({k}, base.get_args(u, 2)), base.arg(u, 1)}
      end
    end
  end

  return u
end

-- Get argument offset
---@param u Expression  Kind
---@return number       Internal argument offest
function base.arg_offset(u)
  return (base.kind(u, 'fn', 'sym', 'unit') and 2) or 1
end

-- Get number of arguments
---@param u Expression  Kind
---@return number       Number of arguments
function base.num_args(u)
  if base.kind(u, 'int', 'frac', 'real', 'bool', 'unit') then return 0 end
  return u and #u - base.arg_offset(u) or 0
end

-- Get nth arg
---@param u Expression  Source expression
---@param n number      Argument indexn (1 based)
---@return Expression|nil
function base.arg(u, n)
  return u and u[n + base.arg_offset(u)] or nil
end

-- Get arguments as list
---@param u Expression   Source expression
---@param start number?  Offset (defaults to 1)
---@return Expression[]
function base.get_args(u, start)
  return util.list.slice(u, (start or 1) + base.arg_offset(u))
end

-- Apply function on each operand/argument
---@param fn function  Function to apply (vaule) => replacement
---@param any...       Optional values passed to fn
---@return Expression  Copy of op with fn applied
function base.map(u, fn, ...)
  if base.num_args(u) > 0 then
    return util.list.join(util.list.slice(u, 1, base.arg_offset(u)),
                          util.list.map(base.get_args(u), fn, ...))
  else
    return u
  end
end
function base.mapi(u, fn, ...) -- Same as base.map, but passes index as first argument to fn
  if base.num_args(u) > 0 then
    return util.list.join(util.list.slice(u, 1, base.arg_offset(u)),
                          util.list.mapi(base.get_args(u), fn, ...))
  else
    return u
  end
end

-- Compare tables
function base.compare(u, v)
  local function cmp(a, b)
    if base.is_const(a) and base.is_const(b) then
      local calc = require 'calc'
      return base.safe_bool(calc.eq(a, b))
    elseif base.kind(a, 'sym') and base.kind(b, 'sym') then
      return base.sym(a) == base.sym(b)
    elseif base.kind(a, 'unit') and base.kind(b, 'unit') then
      return base.unit(a) == base.unit(b)
    elseif base.kind(a, 'fn') and base.kind(b, 'fn') then
      if base.fn(a) == base.fn(b) and base.num_args(a) == base.num_args(b) then
        for i = 1, base.num_args(a) do
          if not base.compare(base.arg(a, i), base.arg(b, i)) then
            return false
          end
        end
        return true
      end
      return false
    elseif base.kind(a) == base.kind(b) and base.num_args(a) == base.num_args(b) then
      for i = 1, base.num_args(a) do
        if not base.compare(base.arg(a, i), base.arg(b, i)) then
          return false
        end
      end
      return true
    else
      return false
    end
  end

  return cmp(u, v)
end

-- Apply summation function on operands and return the result
function base.sum_args(u, fn, ...)
  local s = 0
  if base.num_args(u) > 0 then
    for i = base.arg_offset(u) + 1, #u do
      s = s + fn(u[i], ...)
    end
  end
  return s
end

-- Call function fn for each argument of u
---@param u Expression Expression
---@param fn function  Predicate
---@return boolean
function base.all_args(u, fn, ...)
  if base.num_args(u) > 0 then
    for i = base.arg_offset(u) + 1, #u do
      if not fn(u[i], ...) then
        return false
      end
    end
  end
  return true
end

-- Call function fn for each argument of u
---@param u Expression  Expression
---@param fn function   Predicate
---@return boolean
function base.any_arg(u, fn, ...)
  if base.num_args(u) > 0 then
    for i = base.arg_offset(u) + 1, #u do
      if fn(u[i], ...) then
        return true
      end
    end
  end
  return false
end

return base
