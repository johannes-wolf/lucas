local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'
local functions = require 'functions'
local dbg = require 'dbg'

local function trace_step(step, ...)
  if dbg.trace then
    print(dbg.format_trace(step, ...))
  end
end

-- Simplification rules
local simplify = {}

local function eq_const(u, n)
  if lib.is_const(u) then
    return lib.safe_bool(calc.eq(u, {'int', n}))
  end
  return false
end

-- Return base of an expression
-- Example:
--   x^2 => x
--   x   => x
local function base(u)
  if lib.kind(u, 'vec', 'sym', 'unit', '*', '+', '!', 'fn') then
    return u
  elseif lib.kind(u, '^') then
    return lib.arg(u, 1)
  elseif lib.kind(u, 'int', 'frac', 'real') then
    return 'undef'
  else
    error('unreachable kind='..(lib.kind(u) or 'nil'))
  end
end

-- Return exponent of an expression
-- Example:
--   x^2 => 2
--   x   => 1
local function exponent(u)
  if lib.kind(u, 'vec', 'sym', 'unit', '*', '+', '!', 'fn') then
    return {'int', 1}
  elseif lib.kind(u, '^') then
    return lib.arg(u, 2)
  elseif lib.kind(u, 'int', 'frac', 'real') then
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
  if lib.kind(u, 'vec', 'sym', 'unit', '+', '^', '!', 'fn') then
    -- Return the uession as binary product (* u)
    return {'*', u}
  elseif lib.kind(u, '*') and lib.is_const(lib.arg(u, 1)) then
    -- Return all but the first argument (* u_2..u_n)
    return util.list.join('*', util.list.slice(u, 3))
  elseif lib.kind(u, '*') and not lib.is_const(lib.arg(u, 1)) then
    -- Return the full exrpression (u)
    return u
  elseif lib.kind(u, 'int', 'frac', 'real') then
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
  if lib.kind(expr, 'vec', 'sym', 'unit', '+', '^', '!', 'fn') then
    -- Return constant factor (1)
    return {'int', 1}
  elseif lib.kind(expr, '*') and lib.is_const(lib.arg(expr, 1)) then
    -- Return first argument (u_1)
    return lib.arg(expr, 1)
  elseif lib.kind(expr, '*') and not lib.is_const(lib.arg(expr, 1)) then
    -- Return constant factor (1)
    return {'int', 1}
  elseif lib.kind(expr, 'int', 'frac', 'real') then
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
      if not lib.compare(x[i], y[i]) then
        return x[i], y[i], i
      end
    end
  end

  local function find_neq_rev(x, y)
    for i = 0, math.min(#x, #y) - 1 do
      if not lib.compare(x[#x - i], y[#y - i]) then
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
    return lib.safe_bool(calc.lt(u, v))
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
    if not lib.compare(base(u), base(v)) then
      return order_before(base(u), base(v))
    end
    --return order_before(exponent(u), exponent(v))
    return not order_before(exponent(u), exponent(v)) -- FIXME: Order from high to low!
  elseif lib.kind(u, '!') and lib.kind(v, '!') then
    return order_before(u[2], v[2])
  elseif (lib.kind(u, 'fn') and lib.kind(v, 'fn')) or
         (lib.kind(u, 'vec') and lib.kind(v, 'vec')) then
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
  elseif lib.kind(u, '*') and lib.kind(v, '^', '+', '!', 'fn', 'sym', 'unit', 'vec') then
    return order_before(u, {'*', v})
  elseif lib.kind(u, '^') and lib.kind(v, '+', '!', 'fn', 'sym', 'unit', 'vec') then
    return order_before(u, {'^', v, {'int', 1}})
  elseif lib.kind(u, '+') and lib.kind(v, '!', 'fn', 'sym', 'unit', 'vec') then
    return order_before(u, {'+', v})
  elseif lib.kind(u, '!') and lib.kind(v, 'fn', 'sym', 'unit', 'vec') then
    if lib.compare(u[2], v) then
      return false
    else
      return order_before(u, {'!', v})
    end
  elseif lib.kind(u, 'fn') and lib.kind(v, 'sym', 'unit', 'vec') then
    if lib.fn(u) == v[2] then
      return false
    else
      order_before(lib.fn(u), v[2])
    end
  elseif lib.kind(u, 'sym') and lib.kind(v, 'unit', 'vec') then
    -- Order units last!
    return true
  elseif lib.kind(u, 'vec') and lib.kind(v, 'unit') then
    return true
  else
    return not order_before(v, u)
  end
end

local function merge_operands(p, q, base_simp)
  trace_step('merge_operands', p, q)

  assert(base_simp)
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
    local h = base_simp({p1, q1})

    if #h == 0 then -- 1
      return merge_operands(util.list.rest(p), util.list.rest(q), base_simp)
    elseif #h == 1 then -- 2
      return util.list.join(h, merge_operands(util.list.rest(p), util.list.rest(q), base_simp))
    elseif #h == 2 and lib.compare(h[1], p1) and lib.compare(h[2], q1) then -- 3
      return util.list.join({p1}, merge_operands(util.list.rest(p), q, base_simp))
    elseif #h == 2 and lib.compare(h[1], q1) and lib.compare(h[2], p1) then -- 4
      return util.list.join({q1}, merge_operands(p, util.list.rest(q), base_simp))
    end
  end
end

function simplify.rational_number(u)
  trace_step('rational_number', u)

  if lib.kind(u, 'int') then
    return u
  elseif lib.kind(u, 'frac') then
    return calc.normalize_fraction(u)
  elseif lib.kind(u, 'real') then
    return calc.normalize_real(u)
  end
  return u
end

function simplify.rne_rec(u)
  trace_step('rne_rec', u)

  assert(lib.num_args(u) <= 2)

  local k = lib.kind(u)
  if k == 'int' or k == 'real' or k == 'vec' then
    return u
  elseif k == 'frac' then
    if u[3] == 0 then
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
      return calc.product({'int', -1}, v)
    end
  elseif lib.num_args(u) == 2 then
    if lib.kind(u, '+', '*', '-', '/') then
      local v, w = simplify.rne_rec(u[2]), simplify.rne_rec(u[3])
      if v == 'undef' or w == 'undef' then
        return 'undef'
      else
        if lib.kind(u, '+') then
          return calc.sum(v, w)
        elseif lib.kind(u, '*') then
          return calc.product(v, w)
        elseif lib.kind(u, '-') then
          return calc.difference(v, w)
        elseif lib.kind(u, '/') then
          return calc.quotient(v, w)
        end
      end
    elseif lib.kind(u, '^') then
      local v = simplify.rne_rec(lib.arg(u, 1))
      if v == 'undef' then
        return 'undef'
      end
      return calc.pow(v, lib.arg(u, 2))
    end
  end
end

-- Simplify rational number expression (rne)
function simplify.rne(u)
  trace_step('rne', u)

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
  trace_step('product_rec', l)

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
    elseif lib.kind(a, 'vec') or lib.kind(b, 'vec') then
      local v = simplify.vector_operation('*', l, simplify.product)
      if v then
        return {v}
      else
        return l
      end
    elseif eq_const(a, 1) then
      return {b}
    elseif eq_const(b, 1) then
      return {a}
    elseif lib.compare(base(a), base(b)) then
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
      return merge_operands(util.list.rest(a), util.list.rest(b), simplify.product_rec)
    elseif lib.kind(a, '*') then
      return merge_operands(util.list.rest(a), {b}, simplify.product_rec)
    elseif lib.kind(b, '*') then
      return merge_operands({a}, util.list.rest(b), simplify.product_rec)
    end
  elseif #l > 2 then
    local w = simplify.product_rec(util.list.rest(l))
    if lib.kind(a, '*') then
      return merge_operands(util.list.rest(a), w, simplify.product_rec)
    else
      return merge_operands({a}, w, simplify.product_rec)
    end
  end
  error('unreachable (SPRDREC)')
end

function simplify.vector_operation(k, l, fn)
  trace_step('vector_operation', k, l)

  assert(#l <= 2)
  local a, b = l[1], l[2]
  if lib.kind(a, 'vec') and lib.kind(b, 'vec') and lib.num_args(a) == lib.num_args(b) then
    return lib.mapi(a, function(idx, v)
      return fn({k, v, lib.arg(b, idx)})
    end)
  elseif lib.kind(a, 'vec') and not lib.kind(b, 'vec') then
    return lib.map(a, function(v)
      return fn({k, v, b})
    end)
  elseif not lib.kind(a, 'vec') and lib.kind(b, 'vec') then
    return lib.map(b, function(v)
      return fn({k, a, v})
    end)
  end
end

function simplify.product(expr)
  trace_step('product', expr)

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
  trace_step('sum_rec', l)

  assert(type(l) == 'table')

  local a, b = l[1], l[2]
  if #l == 2 and lib.kind(a) ~= '+' and lib.kind(b) ~= '+' then
    if lib.is_const(a) and lib.is_const(b) then
      local r = simplify.rne({'+', a, b})
      if calc.is_zero_p(r) then
        return {}
      else
        return {r}
      end
    elseif calc.is_zero_p(a) then
      return {b}
    elseif calc.is_zero_p(b) then
      return {a}
    elseif lib.kind(a, 'vec') or lib.kind(b, 'vec') then
      local v = simplify.vector_operation('+', l, simplify.sum)
      if v then
        return {v}
      else
        return l
      end
    elseif lib.compare(term(a), term(b)) then
      local s = simplify.sum({'+', const(a), const(b)})
      local p = simplify.product({'*', s, term(a)})
      if calc.is_zero_p(p) then
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
      return merge_operands(util.list.rest(a), util.list.rest(b), simplify.sum_rec)
    elseif lib.kind(a, '+') then
      return merge_operands(util.list.rest(a), {b}, simplify.sum_rec)
    elseif lib.kind(b, '+') then
      return merge_operands({a}, util.list.rest(b), simplify.sum_rec)
    end
  elseif #l > 2 then
    local w = simplify.sum_rec(util.list.rest(l))
    if lib.kind(a, '+') then
      return merge_operands(util.list.rest(a), w, simplify.sum_rec)
    else
      return merge_operands({a}, w, simplify.sum_rec)
    end
  end

  error('unreachable (SPRDREC)')
end

function simplify.sum(u)
  trace_step('sum', u)

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

-- Simplify power a^b
---@param expr table
---@return table
function simplify.power(expr)
  trace_step('power', expr)

  assert(lib.kind(expr, '^'))

  local b, e = expr[2], expr[3]
  if lib.kind(b, 'vec') or lib.kind(e, 'vec') then
    local v = simplify.vector_operation('^', {b, e}, simplify.power)
    if v then
      return v
    else
      return {'^', b, e}
    end
  elseif lib.is_const(b) then
    return simplify.rne({'^', b, e})
  elseif lib.kind(b, '^') and lib.kind(e, 'int') then
    local r, s = lib.arg(b, 1), lib.arg(b, 2)
    local p = simplify.product({'*', s, e})
    return simplify.power({'^', r, p})
  elseif lib.kind(b, '*') then
    local r = lib.map(b, function(arg)
      return simplify.power({'^', arg, e})
    end)
    return simplify.product(r)
  elseif eq_const(e, 0) then
    return {'int', 1}
  elseif eq_const(e, 1) then
    return b
  elseif lib.safe_sym(b) == 'e' then
    return {'fn', 'exp', e}
  else
    return {'^', b, e}
  end
end

function simplify.quotient(u)
  trace_step('quotient', u)

  assert(lib.kind(u, '/'))

  local p = simplify.power({'^', lib.arg(u, 2), {'int', -1}})
  return simplify.product({'*', lib.arg(u, 1), p})
end

function simplify.difference(u)
  trace_step('difference', u)

  assert(lib.kind(u, '-'))

  if lib.num_args(u) == 1 then
    return simplify.product({'*', {'int', -1}, u[2]})
  else
    local a, b = lib.arg(u, 1), lib.arg(u, 2)
    local d = simplify.product({'*', {'int', -1}, b})
    return simplify.sum({'+', a, d})
  end
end

function simplify.factorial(u)
  trace_step('factorial', u)

  if lib.kind(u, 'vec') then
    return lib.map(u, calc.factorial)
  end
  return calc.factorial(lib.arg(u, 1))
end

local allowed_fn = {
  'sqrt', 'abs',
}

local auto_map_fn = {
  'sqrt', 'abs',
}

function simplify.fn(u, env)
  trace_step('fn', u)

  local name = lib.safe_fn(u)

  -- If allowed, map function over collection
  if lib.num_args(u) == 1 and lib.is_collection(lib.arg(u, 1)) then
    if util.set.contains(auto_map_fn, name) then
      return lib.map(lib.arg(u, 1), function(v)
        return simplify.expr({'fn', name, v}, env)
      end)
    end
  end

  -- If allowed, call function durring simplification
  if util.set.contains(allowed_fn, name) then
    if lib.all_args(u, lib.is_const) then
      return functions.call(u, env)
    end
  end
  return u
end

function simplify.unit(expr, env)
  trace_step('unit', expr)

  local u = lib.safe_unit(expr)
  if env then
    local v = env:get_unit(u)
    if v and v.value then
      return simplify.expr(v.value)
    end
  end
  return expr
end

function simplify.logical(u) -- TODO: merge_operands!
  trace_step('logical', u)

  local a, b = lib.arg(u, 1), lib.arg(u, 2)
  if lib.kind(u, 'not') then
    if lib.is_const(a) then
      return {'bool', not lib.safe_bool(a, false)}
    end
  elseif lib.kind(u, 'and') then
    if lib.is_const(a) and lib.is_const(b) then
      return {'bool', lib.safe_bool(a, false) and lib.safe_bool(b, false)}
    end
  elseif lib.kind(u, 'or') then
    if (lib.is_const(a) and lib.safe_bool(a, false)) or
       (lib.is_const(b) and lib.safe_bool(b, false)) then
      return calc.TRUE
    end
  end
  return u
end

function simplify.relation(u)
  trace_step('relation', u)

  assert(lib.num_args(u) == 2)

  -- Transform a<b<c => a<b and b<c if not mixing <> and =
  local a, b = lib.arg(u, 1), lib.arg(u, 2)
  if lib.is_relop(a) and not lib.is_relop(b) then
    if lib.kind(a, '=', '!=') == lib.kind(u, '=', '!=') then
      local ab = lib.arg(a, 2)
      return simplify.expr({'and', simplify.expr(a),
                            simplify.expr({lib.kind(u), ab, b})})
    end
  end

  u = lib.map(u, simplify.expr)

  if lib.is_atomic(a) and lib.is_atomic(b) then
    if lib.kind(u, '<') then
      return calc.lt(a, b)
    elseif lib.kind(u, '<=') then
      return calc.lteq(a, b)
    elseif lib.kind(u, '>') then
      return calc.gt(a, b)
    elseif lib.kind(u, '>=') then
      return calc.gteq(a, b)
    elseif lib.kind(u, '=') then
      return calc.eq(a, b)
    elseif lib.kind(u, '!=') then
      return calc.neq(a, b)
    else
      error('unimplemented')
    end
  elseif lib.kind(a, 'sym') and lib.kind(b, 'sym') then
    if lib.compare(a, b) then
      if lib.kind(u, '=', '>=', '<=') then
        return calc.TRUE
      elseif lib.kind(u, '<', '>', '!=') then
        return calc.FALSE
      end
    else
      if lib.kind(u, '!=') then
        return calc.TRUE
      elseif lib.kind(u, '=') then
        return calc.FALSE
      end
    end
  end
  return u
end

function simplify.with_assignment(u, env)
  trace_step('with_assignment', u)

  return lib.map(u, simplify.expr, env)
end

function simplify.with_condition(u, env)
  trace_step('with_condition', u)

  if lib.kind(u, 'and') then
    return lib.map(u, simplify.with_condition, env)
  elseif lib.kind(u, '=') then
    return simplify.with_assignment(u, env)
  end
end

function simplify.with(u, env)
  trace_step('with', u)

  local a, b = lib.arg(u, 1), lib.arg(u, 2)
  a = simplify.expr(a, env)
  b = simplify.with_condition(b, env)
  if not b or lib.is_const(b) then
    return a
  end
  return {'|', a, b}
end

function simplify.expr(expr, env)
  trace_step('expr', expr)

  if lib.kind(expr, 'sym') then
    return expr
  elseif lib.kind(expr, 'bool', 'int', 'real') then
    return expr
  elseif lib.kind(expr, 'unit') then
    return simplify.unit(expr, env)
  elseif lib.kind(expr, 'frac') then
    return simplify.rational_number(expr)
  elseif lib.is_relop(expr) then
    return simplify.relation(expr)
  elseif lib.kind(expr, '|') then
    return simplify.with(expr, env)
  else
    local v = lib.map(expr, simplify.expr, env)
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
    elseif k == 'and' or k == 'or' or k == 'not' then
      return simplify.logical(v)
    elseif k == 'fn' then
      return simplify.fn(v, env)
    else
      return v
    end
  end
end

return simplify
