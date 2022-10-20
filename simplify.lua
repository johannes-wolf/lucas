local lib = require 'lib'
local util = require 'util'
local eval = require 'eval'
local float = require 'float'

local units = require 'units'
local functions = require 'functions'

-- Simplification rules
local simplify = {}

local function eq_const(u, n)
  if lib.is_const(u) then
    return eval.eq(u, {'int', n})
  end
  return false
end

-- Return base of an expression
-- Example:
--   x^2 => x
--   x   => x
local function base(u)
  if lib.kind(u, 'sym', 'unit', '*', '+', '!', 'fn') then
    return u
  elseif lib.kind(u, '^') then
    return lib.arg(u, 1)
  elseif lib.kind(u, 'int', 'frac', 'float') then
    return 'undef'
  else
    error('unreachable kind='..lib.kind(u))
  end
end

-- Return exponent of an expression
-- Example:
--   x^2 => 2
--   x   => 1
local function exponent(u)
  if lib.kind(u, 'sym', 'unit', '*', '+', '!', 'fn') then
    return {'int', 1}
  elseif lib.kind(u, '^') then
    return lib.arg(u, 2)
  elseif lib.kind(u, 'int', 'frac', 'float') then
    return 'undef'
  else
    error('unreachable kind='..lib.kind(u))
  end
end

-- Returns the non-const term of an expression as product (variable)
-- Example:
--   x   => *x
--   2*y => *y
--   x*y => x*y
local function term(u)
  if lib.kind(u, 'sym', 'unit', '+', '^', '!', 'fn') then
    -- Return the uession as binary product (* u)
    return {'*', u}
  elseif lib.kind(u, '*') and lib.is_const(lib.arg(u, 1)) then
    -- Return all but the first argument (* u_2..u_n)
    return util.list.join('*', util.list.slice(u, 3))
  elseif lib.kind(u, '*') and not lib.is_const(lib.arg(u, 1)) then
    -- Return the full exrpression (u)
    return u
  elseif lib.kind(u, 'int', 'frac', 'float') then
    return 'undef'
  else
    error('unreachable')
  end
end

-- Returns the constant factor of an expression as product (coefficient)
-- Example:
--   x   => 1
--   2*y => 2
--   x*y => 1
local function const(expr)
  if lib.kind(expr, 'sym', 'unit', '+', '^', '!', 'fn') then
    -- Return constant factor (1)
    return {'int', 1}
  elseif lib.kind(expr, '*') and lib.is_const(lib.arg(expr, 1)) then
    -- Return first argument (u_1)
    return lib.arg(expr, 1)
  elseif lib.kind(expr, '*') and not lib.is_const(lib.arg(expr, 1)) then
    -- Return constant factor (1)
    return {'int', 1}
  elseif lib.kind(expr, 'int', 'frac', 'float') then
    return 'undef'
  else
    error('unreachable')
  end
end

-- Return if u comes before v (u < v)
---@param u table
---@param v table
---@return boolean
local function order_before(u, v)
  local function find_neq(x, y, offset)
    for i = offset or 2, math.min(#x, #y) do
      if not util.table.compare(x[i], y[i]) then
        return x[i], y[i], i
      end
    end
  end

  local function find_neq_rev(x, y)
    for i = 0, math.min(#x, #y) - 1 do
      if not util.table.compare(x[#x - i], y[#y - i]) then
        return x[#x - i], y[#y - i], i
      end
    end
  end

  if type(u) == 'string' and type(v) == 'string' then
    return u < v
  elseif type(u) == 'number' and type(v) == 'number' then
    return u < v
  end

  if lib.is_const(u) and lib.is_const(v) then
    return eval.lt(u, v)
  elseif lib.kind(u, 'sym') and lib.kind(v, 'sym') or
         lib.kind(u, 'unit') and lib.kind(v, 'unit') then
    return u[2] < v[2]
  elseif (lib.kind(u, '+') and lib.kind(v, '+')) or
         (lib.kind(u, '*') and lib.kind(v, '*')) then
    local um, vm = find_neq_rev(u, v)
    if um and vm then
      return order_before(um, vm)
    end
    return #u < #v
  elseif lib.kind(u, '^') and lib.kind(v, '^') then
    if not util.table.compare(base(u), base(v)) then
      return order_before(base(u), base(v))
    end
    --return order_before(exponent(u), exponent(v))
    return not order_before(exponent(u), exponent(v)) -- FIXME: Order from high to low!
  elseif lib.kind(u, '!') and lib.kind(v, '!') then
    return order_before(u[2], v[2])
  elseif lib.kind(u, 'fn') and lib.kind(v, 'fn') then
    if lib.fn(u) ~= lib.fn(v) then
      return lib.fn(u) < lib.fn(v)
    end

    local um, vm = find_neq(u, v, 3)
    if um and vm then
      return order_before(um, vm)
    end
    return #u < #v
  elseif lib.is_const(u) and not lib.is_const(v) then
    return true
  elseif lib.kind(u, 'unit') and not lib.kind(v, 'unit') then
    return false
  elseif lib.kind(u, '*') and lib.kind(v, '^', '+', '!', 'fn', 'sym', 'unit') then
    return order_before(u, {'*', v})
  elseif lib.kind(u, '^') and lib.kind(v, '+', '!', 'fn', 'sym', 'unit') then
    return order_before(u, {'^', v, {'int', 1}})
  elseif lib.kind(u, '+') and lib.kind(v, '!', 'fn', 'sym', 'unit') then
    return order_before(u, {'+', v})
  elseif lib.kind(u, '!') and lib.kind(v, 'fn', 'sym', 'unit') then
    if util.table.compare(u[2], v) then
      return false
    else
      return order_before(u, {'!', v})
    end
  elseif lib.kind(u, 'fn') and lib.kind(v, 'sym', 'unit') then
    if lib.fn(u) == v[2] then
      return false
    else
      order_before(lib.fn(u), v[2])
    end
  elseif lib.kind(u, 'sym') and lib.kind(v, 'unit') then
    -- Order units last!
    return true
  else
    return not order_before(v, u)
  end
end

local function merge_operands(p, q)
  assert(type(p) == 'table')
  if #p > 0 then assert(type(p[1]) == 'table') end
  assert(type(q) == 'table')
  if #q > 0 then assert(type(q[1]) == 'table') end

  if not q or #q == 0 then -- MPRD-1
    return p
  elseif not p or #p == 0 then -- MPRD-2
    return q
  else -- MPRD-3
    local p1, q1 = p[1], q[1]
    local h = simplify.product_rec({p1, q1})

    if #h == 0 then -- 1
      return merge_operands(util.list.rest(p), util.list.rest(q))
    elseif #h == 1 then -- 2
      return util.list.join(h, merge_operands(util.list.rest(p), util.list.rest(q)))
    elseif #h == 2 and util.table.compare(h[1], p1) and util.table.compare(h[2], q1) then -- 3
      return util.list.join({p1}, merge_operands(util.list.rest(p), q))
    elseif #h == 2 and util.table.compare(h[1], q1) and util.table.compare(h[2], p1) then -- 4
      return util.list.join({q1}, merge_operands(p, util.list.rest(q)))
    end
  end
end

local function is_unary(e)
  return lib.num_args(e) == 1
end

local function is_binary(e)
  return lib.num_args(e) == 2
end

function simplify.rational_number(u)
  if lib.kind(u, 'int') then
    return u
  elseif lib.kind(u, 'frac') then
    return u -- TODO: Either remove this function, or do not simplify fractions by default
  end
end

function simplify.rne_rec(u)
  assert(lib.num_args(u) <= 2)

  local k = lib.kind(u)
  if k == 'int' or k == 'float' then
    return u
  elseif k == 'frac' then
    if u.denom == 0 then
      return 'undef'
    else
      return u
    end
  elseif k == 'unit' then
    return u
  elseif lib.num_args(u) == 1 then
    local v = simplify.rne_rec(u[2])
    if v == 'undef' then
      return 'undef'
    elseif lib.kind(v, '+') then
      return v
    elseif lib.kind(v, '-') then
      return eval.product({'int', -1}, v)
    end
  elseif lib.num_args(u) == 2 then
    if lib.kind(u, '+', '*', '-', '/') then
      local v, w = simplify.rne_rec(u[2]), simplify.rne_rec(u[3])
      if v == 'undef' or w == 'undef' then
        return 'undef'
      else
        if lib.kind(u, '+') then
          return eval.sum(v, w)
        elseif lib.kind(u, '*') then
          return eval.product(v, w)
        elseif lib.kind(u, '-') then
          return eval.difference(v, w)
        elseif lib.kind(u, '/') then
          return eval.quotient(v, w)
        end
      end
    elseif lib.kind(u, '^') then
      local v = simplify.rne_rec(u[2])
      if v == 'undef' then
        return 'undef'
      end
      return eval.power(v, u[3])
    end
  end
end

-- Simplify rational number expression (rne)
function simplify.rne(u)
  local v = simplify.rne_rec(u)
  if v == 'undef' then
    return 'undef'
  end
  return simplify.rational_number(v)
end

-- Simplify product arguments
---@param l table  List of arguments
---@return table   Simplified list of arguments
function simplify.product_rec(l)
  assert(type(l) == 'table')

  local a, b = l[1], l[2]
  if #l == 2 and lib.kind(a) ~= '*' and lib.kind(b) ~= '*' then
    if lib.is_const(a) and lib.is_const(b) then
      local r = simplify.rne({'*', a, b})
      if eq_const(r, 1) then
        return {}
      else
        return {r}
      end
    elseif eq_const(a, 1) then
      return {b}
    elseif eq_const(b, 1) then
      return {a}
    elseif util.table.compare(base(a), base(b)) then
      local s = simplify.sum({'+', exponent(a), exponent(b)})
      local p = simplify.power({'^', base(a), s})
      if eq_const(p, 1) then
        return {}
      else
        return {p}
      end
    elseif order_before(b, a) then
      return {b, a}
    else
      return l
    end
  elseif #l == 2 and (lib.kind(a, '*') or lib.kind(b, '*')) then
    if lib.kind(a, '*') and lib.kind(b, '*') then
      return merge_operands(util.list.rest(a), util.list.rest(b))
    elseif lib.kind(a, '*') then
      return merge_operands(util.list.rest(a), {b})
    elseif lib.kind(b, '*') then
      return merge_operands({a}, util.list.rest(b))
    end
  elseif #l > 2 then
    local w = simplify.product_rec(util.list.rest(l))
    if lib.kind(a, '*') then
      return merge_operands(util.list.rest(a), w)
    else
      return merge_operands({a}, w)
    end
  end

  error('unreachable (SPRDREC)')
end

function simplify.product(expr)
  assert(lib.kind(expr, '*'))

  if util.set.contains(expr, 'undef') then
    return 'undef'
  elseif util.set.contains(expr, {'int', 0}) then
    return {'int', 0}
  elseif lib.num_args(expr) == 1 then
    return expr[2]
  else
    local v = simplify.product_rec(util.list.rest(expr)) or {}
    if #v == 1 then
      return v[1]
    elseif #v == 2 and lib.is_const(v[1]) and lib.kind(v[2], '+') then -- a(b+c) => ab + ac
      return lib.map(v[2], function(s) return simplify.product({'*', v[1], s}) end)
    elseif #v == 2 and lib.is_const(v[2]) and lib.kind(v[1], '+') then -- (b+c)a => ab + ac
      return lib.map(v[1], function(s) return simplify.product({'*', v[2], s}) end)
    elseif #v >= 2 then -- ((ab)c) => abc
      return util.list.join('*', v)
    elseif #v == 0 then
      return {'int', 1}
    end
  end
end

function simplify.sum_rec(l)
  assert(type(l) == 'table')

  local a, b = l[1], l[2]
  if #l == 2 and lib.kind(a) ~= '+' and lib.kind(b) ~= '+' then
    if lib.is_const(a) and lib.is_const(b) then
      local r = simplify.rne({'+', a, b})
      if eval.is_zero(r) then
        return {}
      else
        return {r}
      end
    elseif eval.is_zero(a) then
      return {b}
    elseif eval.is_zero(b) then
      return {a}
    elseif util.table.compare(term(a), term(b)) then
      local s = simplify.sum({'+', const(a), const(b)})
      local p = simplify.product({'*', s, term(a)})
      if eval.is_zero(p) then
        return {}
      else
        return {p}
      end
    elseif order_before(b, a) then
      return {b, a}
    else
      return l
    end
  elseif #l == 2 and (lib.kind(a, '+') or lib.kind(b, '+')) then
    if lib.kind(a, '+') and lib.kind(b, '+') then
      return merge_operands(util.list.rest(a), util.list.rest(b))
    elseif lib.kind(a, '+') then
      return merge_operands(util.list.rest(a), {b})
    elseif lib.kind(b, '+') then
      return merge_operands({a}, util.list.rest(b))
    end
  elseif #l > 2 then
    local w = simplify.sum_rec(util.list.rest(l))
    if lib.kind(a, '+') then
      return merge_operands(util.list.rest(a), w)
    else
      return merge_operands({a}, w)
    end
  end

  error('unreachable (SPRDREC)')
end

function simplify.sum(u)
  assert(lib.kind(u, '+'))

  if util.set.contains(u, 'undef') then
    return 'undef'
  elseif lib.num_args(u) == 1 then
    return u[2]
  else
    local v = simplify.sum_rec(util.list.rest(u)) or {}
    if #v == 1 then
      return v[1]
    elseif #v >= 2 then
      return util.list.join('+', v)
    elseif #v == 0 then
      return {'int', 0}
    end
  end
end

-- Simplify power a^b with b of type int
---@param expr table
---@return table
function simplify.int_power(expr)
  assert(lib.kind(expr, '^'))
  assert(lib.kind(expr[3], 'int'))

  local b, e = expr[2], expr[3]
  local n = e[2] -- e is of lib.kind 'int'
  if lib.kind(b, 'int', 'frac') then -- SINTPOW-1
    return simplify.rne({'^', b, e})
  elseif n == 0 then -- SINTPOW-2
    return {'int', 1}
  elseif n == 1 then -- SINTPOW-3
    return b
  elseif lib.kind(b, '^') then -- SINTPOW-4
    local r, s = lib.arg(b, 1), lib.arg(b, 2)
    local p = simplify.product({'*', s, e})
    if lib.kind(p, 'int') then
      return simplify.int_power({'^', r, p})
    else
      return {'^', r, p}
    end
  elseif lib.kind(b, '*') then -- SINTPOW-5
    local r = lib.map(b, function(arg)
                        return simplify.int_power({'^', arg, e})
    end)
    return simplify.product(r)
  else -- SINTPOW-6
    return {'^', b, e}
  end
end

-- Simplify power a^b
---@param expr table
---@return table
function simplify.power(expr)
  assert(lib.kind(expr, '^'))

  local b, e = base(expr), exponent(expr)
  if b == 'undef' or e == 'undef' then -- SPOW-1
    return 'undef'
  else
    if eval.is_zero(b) then -- SPOW-2
      if true then -- FIXME: is positive?
        return {'int', 0}
      else
        return 'undef'
      end
    elseif eq_const(b, 1) then -- SPOW-3
      return {'int', 1}
    elseif lib.kind(e, 'int') then -- SPOW-4
      return simplify.int_power(expr)
    else -- SPOW-5
      return expr
    end
  end
end

function simplify.quotient(u)
  assert(lib.kind(u, '/'))

  local p = simplify.power({'^', lib.arg(u, 2), {'int', -1}})
  return simplify.product({'*', lib.arg(u, 1), p})
end

function simplify.difference(u)
  assert(lib.kind(u, '-'))

  if is_unary(u) then
    return simplify.product({'*', {'int', -1}, u[2]})
  else
    local d = simplify.product({'*', {'int', -1}, u[3]})
    return simplify.sum({'+', u[2], d})
  end
end

function simplify.factorial(u)
  error('not implemented')
end

function simplify.fn(u)
  local name = lib.fn(u)

  local f = functions.table[name]
  if not f then
    return u
  end

  for i = 1, lib.num_args(u) do
    local simplify_mode = 'auto'
    local arg_kind = 'any'
    if f.arguments and f.arguments[i] then
      simplify_mode = f.arguments[i].simplify or 'auto'
      arg_kind = f.arguments[i].kind or 'any'
      if arg_kind == 'sym' or arg_kind == 'unit' then
        simplify_mode = 'none'
      end
    end

    if simplify_mode == 'auto' then
      u[lib.arg_offset(u) + i] = simplify.expr(lib.arg(u, i))
    end
  end

  return simplify.expr(f.fn(lib.get_args(u)))
end

function simplify.unit(u)
  if units.table[lib.unit(u)].value then
    return simplify.expr(units.table[lib.unit(u)].value)
  end
  return u
end

function simplify.expr(expr)
  if lib.kind(expr, 'sym', 'int', 'float') then
    return expr
  elseif lib.kind(expr, 'unit') then
    return simplify.unit(expr)
  elseif lib.kind(expr, 'frac') then
    return simplify.rational_number(expr)
  elseif lib.kind(expr, 'fn') then
    return simplify.fn(expr)
  else
    local v = lib.map(expr, simplify.expr)
    local k = lib.kind(v)
    if k == '^' then
      return simplify.power(v)
    elseif k == '*' then
      return simplify.product(v)
    elseif k == '+' then
      return simplify.sum(v)
    elseif k == '/' then
      return simplify.quotient(v)
    elseif k == '-' then
      return simplify.difference(v)
    elseif k == '!' then
      return simplify.factorial(v)
    end
  end
end

functions.def_custom('simplify', {{kind = 'any'}}, function(args) return simplify.expr(args[1]) end)

return simplify
