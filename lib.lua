local util = require 'util'
local dbg = require 'dbg'

local base = {}

---@alias Expression table
---@alias Symbol Expression
---@alias List Expression
---@alias Associativity
---| 'left'
---| 'right'
---@alias Kind
---| 'int'
---| 'frac'
---| 'real'
---| 'tmp'
---| 'sym'
---| 'unit'
---| 'call'

---@reutrn boolean|nil
function base.safe_bool(val, def)
  if base.kind(val, 'int') then
    if type(val[2]) == 'boolean' then
      return val[2]
    else
      return val[2] ~= 0
    end
  end
  return def
end

---@param  val any
---@return number|nil
function base.safe_int(val)
  if base.kind(val, 'int') then return val[2] end
end

---@return number
function base.expect_int(val)
  return base.safe_int(val) or error('Expected integer, got '..base.kind(val))
end

---@return string|nil
function base.safe_sym(val)
  if base.kind(val, 'sym', 'tmp') then return base.sym(val) end
end

---@return string|nil
function base.safe_tmp(val)
  if base.kind(val, 'tmp') then return base.sym(val) end
end

---@return string|nil
function base.expect_tmp(val)
  return base.safe_tmp(val) or error('Expected template, got '..base.kind(val))
end

---@return string|nil
function base.safe_unit(val)
  if base.kind(val, 'unit') then return base.unit(val) end
end

---@return string|nil
function base.safe_call_sym(val)
  if base.kind(val, 'call') and base.kind(base.arg(val, 1), 'sym') then return base.safe_sym(base.arg(val, 1)) end
end

---@return any
function base.expect_kind(val, k)
  if base.kind(val) ~= k then error('Expected '..k..', got '..base.kind(val)) end
  return val
end

-- Get (or compare) expression kind
---@param expr Expression|nil
---@return boolean|Kind
function base.kind(expr, ...)
  if not expr then return false end
  assert(type(expr) == 'table')
  if select('#', ...) > 0 then
    return util.set.contains({...}, expr[1])
  end
  return expr[1]
end

-- Returns whether u is const
---@param u Expression|nil
function base.is_const(u)
  return base.kind(u, 'int', 'real', 'frac')
end

-- Returns whether u is const, a symbol or a unit
function base.is_atomic(u)
  return base.is_const(u) or base.kind(u, 'sym', 'tmp', 'unit')
end

-- Returns whether u is a collection (vec, set, list, ...)
function base.is_collection(u)
  return base.kind(u, 'vec')
end

-- Returns whether u is a relational operator
function base.is_relop(u)
  return base.kind(u, '=', '!=', '>', '>=', '<', '<=')
end

-- Get (or compare) expression function name (if kind = 'sym')
---@return boolean|string
function base.sym(u, ...)
  if not u or not base.kind(u, 'sym', 'tmp') then return nil end
  if select('#', ...) > 0 then
    return util.set.contains({...}, u[2])
  end
  return u[2] or ''
end

-- Get (or compare) expression function name (if kind = 'sym')
function base.unit(u, ...)
  if not u or not base.kind(u, 'unit') then return nil end
  if select('#', ...) > 0 then
    return util.set.contains({...}, u[2])
  end
  return u[2]
end

-- Get argument offset
---@param u Expression|nil  Kind
---@return number           Internal argument offest
function base.arg_offset(u)
  return (base.kind(u, 'sym', 'tmp', 'unit') and 2) or 1
end

-- Get number of arguments
---@param u Expression|nil  Kind
---@return number           Number of arguments
function base.num_args(u)
  if not u then return 0 end
  if base.kind(u, 'int', 'frac', 'real', 'unit') then return 0 end
  return u and #u - base.arg_offset(u) or 0
end

-- Get nth arg
---@param u Expression|nil  Source expression
---@param n number          Argument indexn (1 based)
---@return Expression|nil
function base.arg(u, n)
  return u and u[n + base.arg_offset(u)] or nil
end

-- Get nth call argument
---@param u Expression|nil
---@param n number
---@return Expression|nil
function base.call_arg(u, n)
  return base.kind(u, 'call') and base.arg(base.arg(u, 2), n) or nil
end

-- Set nth arg
---@param u Expression|nil  Source expression
---@param n number          Argument indexn (1 based)
---@param v Expression      Value to set
---@return  boolean
function base.set_arg(u, n, v)
  if base.num_args(u) >= n then
    u[n + base.arg_offset(u)] = v
    return true
  end
  return false
end

-- Get arguments as list
---@param u Expression|nil   Source expression
---@param start number?      Offset (defaults to 1)
---@return Expression[]|nil
function base.get_args(u, start)
  return base.num_args(u) > 0 and util.list.slice(u, (start or 1) + base.arg_offset(u))
end

-- Apply function on each operand/argument
---@param fn function  Function to apply (vaule) => replacement
---@param any...  any  Optional values passed to fn
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

-- Map reucursive
---@param u  Expression
---@param fn function
---@return   Expression|nil
function base.map_recurse(u, fn, ...)
  local function map_rec(v, ...)
    local r = base.is_atomic(v) and fn(v, ...) or base.map(v, fn, ...)
    if r and r == v then -- Do not re-iterate replacements
      return map_rec(r)
    end
    return r
  end
  return map_rec(u, ...)
end

-- Inline map
function base.transform(u, fn, ...)
  if base.num_args(u) > 0 then
    for i = base.arg_offset(u) + 1, #u do
      u[i] = fn(u[i], ...)
    end
    return u
  else
    return u
  end
end
function base.transformi(u, fn, ...)
  if base.num_args(u) > 0 then
    for i = base.arg_offset(u) + 1, #u do
      u[i] = fn(i - base.arg_offset(u), u[i], ...)
    end
    return u
  else
    return u
  end
end

-- Compare tables
---@param u Expression|nil
---@param v Expression|nil
---@return  boolean
function base.compare(u, v)
  local function cmp(a, b)
    if base.is_const(a) and base.is_const(b) then
      local calc = require 'calc'
      return calc.is_true_p(calc.eq(a, b))
    elseif base.kind(a) ~= base.kind(b) then
      return false
    elseif (base.kind(a, 'sym') and base.kind(b, 'sym')) or
           (base.kind(a, 'tmp') and base.kind(b, 'tmp')) then
      return base.sym(a) == base.sym(b)
    elseif base.kind(a, 'unit') and base.kind(b, 'unit') then
      return base.unit(a) == base.unit(b)
    elseif base.num_args(a) == base.num_args(b) then
      for i = 1, base.num_args(a) do
        if not cmp(base.arg(a, i), base.arg(b, i)) then
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

-- Returns all args if u is of kind k and arg-count is n
---@param u Expression
---@param k Kind
---@param n number
---@return  Expression|nil, Expression|nil, ...
function base.split_args_if(u, k, n)
  if base.kind(u, k) and base.num_args(u) == n then
    return table.unpack(u, base.arg_offset(u) + 1)
  end
  return nil
end

-- Find arg for which fn returns true
---@param l  Expression|nil
---@param fn function
---@return Expression[]|nil, integer|nil
function base.find_arg(l, fn, ...)
  for i = 1, base.num_args(l) do
    if fn(base.arg(l, i), ...) then
      return base.arg(l, i), i
    end
  end
end

function base.copy_args(a, b, start, stop)
  start = start or 1
  stop = stop or base.num_args(a)
  for i = start, stop do
    table.insert(b, base.arg(a, i))
  end
  return b
end

function base.make_list(...)
  return {'vec', ...}
end

function base.make_list_n(s, v)
  local l = {'vec'}
  for _ = 1, s or 0 do table.insert(l, v) end
  return l
end

function base.sort_list(l, fn)
  local new = base.get_args(l) or {}
  table.sort(new, fn)
  table.insert(new, 0, 'vec')
  return new
end

return base
