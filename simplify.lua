local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'
local functions = require 'functions'
local op = require 'operator'
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
  if lib.kind(u, 'vec', 'sym', 'tmp', 'unit', '*', '+', '!', 'fn') then
    return u
  elseif lib.kind(u, '^') then
    return lib.arg(u, 1)
  elseif lib.kind(u) then
    return nil
  else
    error('unreachable kind='..(lib.kind(u) or 'nil'))
  end
end

-- Return exponent of an expression
-- Example:
--   x^2 => 2
--   x   => 1
local function exponent(u)
  if lib.kind(u, 'vec', 'sym', 'tmp', 'unit', '*', '+', '!', 'fn') then
    return {'int', 1}
  elseif lib.kind(u, '^') then
    return lib.arg(u, 2)
  elseif lib.is_const(u) then
    return nil
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
  if lib.kind(u, 'vec', 'sym', 'tmp', 'unit', '+', '^', '!', 'fn') then
    -- Return the uession as binary product (* u)
    return {'*', u}
  elseif lib.kind(u, '*') and lib.is_const(lib.arg(u, 1)) then
    -- Return all but the first argument (* u_2..u_n)
    return util.list.join('*', util.list.slice(u, 3))
  elseif lib.kind(u, '*') and not lib.is_const(lib.arg(u, 1)) then
    -- Return the full exrpression (u)
    return u
  elseif lib.is_const(u) then
    return nil
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
  if lib.kind(expr, 'vec', 'sym', 'tmp', 'unit', '+', '^', '!', 'fn') then
    return {'int', 1}
  elseif lib.kind(expr, '*') and lib.is_const(lib.arg(expr, 1)) then
    return lib.arg(expr, 1)
  elseif lib.kind(expr, '*') and not lib.is_const(lib.arg(expr, 1)) then
    return {'int', 1}
  elseif lib.is_const(expr) then
    return nil
  else
    error('unreachable')
  end
end


local order = {}

function order.lexicographical(u, v)
  return u < v
end

function order.sum_prod(u, v)
  local m, n = lib.num_args(u), lib.num_args(v)
  if m ~= n then
    return order.front(lib.arg(u, m), lib.arg(v, n))
  end

  for j = 0, math.min(m, n) - 2 do -- -2 or -1?
    if not lib.compare(lib.arg(u, m - j), lib.arg(v, n - j)) then
      return order.front(lib.arg(u, m - j), lib.arg(v, n - j))
    end
  end

  local k = math.min(m, n) - 1
  if lib.compare(lib.arg(u, m - k), lib.arg(v, n - k)) then
    return m < n
  end

  return false
end

function order.power(u, v)
  if not lib.compare(base(u), base(v)) then
    return order.front(base(u), base(v))
  else
    return order.front(exponent(u), exponent(v))
  end
end

function order.fn(u, v)
  if lib.fn(u) ~= lib.fn(v) then
    return order.lexicographical(lib.fn(u), lib.fn(v))
  else
    local m, n = lib.num_args(u), lib.num_args(v)

    for j = 1, math.min(m, n) do
      if not lib.compare(lib.arg(u, j), lib.arg(u, j)) then
        return order.front(lib.arg(u, j), lib.arg(u, j))
      end
    end

    local k = math.min(m, n)
    if lib.compare(lib.arg(u, k), lib.arg(u, k)) then
      return m < m
    end
  end
end

function order.front(u, v)
  -- Do not reorder placeholders
  if lib.kind(u, 'tmp') then
    return false
  end

  -- Ordered operands
  local uk, vk = lib.kind(u), lib.kind(v)
  if lib.is_const(u) and lib.is_const(v) then
    return lib.safe_bool(calc.lt(u, v))
  elseif uk == vk then
    if uk == 'sym' then
      return order.lexicographical(lib.sym(u), lib.sym(v))
    elseif uk == 'unit' then
      return order.lexicographical(lib.unit(u), lib.unit(v))
    elseif uk == '*' or uk == '+' then
      return order.sum_prod(u, v)
    elseif uk == '^' then
      return order.power(u, v)
    elseif uk == '!' then
      return order.front(lib.arg(u, 1), lib.arg(v, 1))
    elseif uk == 'fn' then
      return order.fn(u, v)
    end
  else
    if lib.is_const(u) and not lib.is_const(v) then
      return true
    elseif uk == '*' and (vk == '^' or vk == '+' or vk == '!' or vk == 'fn' or vk == 'sym') then
      return order.front(u, {'*', v})
    elseif uk == '^' and (vk == '+' or vk == '!' or vk == 'fn' or vk == 'sym') then
      return order.front(u, {'^', v, calc.ONE})
    elseif uk == '+' and (vk == '!' or vk == 'fn' or vk == 'sym') then
      return order.front(u, {'+', v})
    elseif uk == '!' and (vk == 'fn' or vk == 'sym') then
      if lib.compare(lib.arg(u, 1), v) then
        return false
      else
        return order.front(u, {'!', v})
      end
    elseif uk == 'fn' and (vk == 'sym') then
      if lib.fn(u) == lib.sym(v) then
        return false
      else
        return order.lexicographical(lib.fn(u), lib.sym(v))
      end
    elseif uk == 'unit' then
      return false
    elseif vk == 'unit' then
      return true
    else
      return not order.front(v, u)
    end
  end
  error('unreachable')
end

local function merge_operands(p, q, base_simp, ...)
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
    local h = base_simp({p1, q1}, ...)

    if #h == 0 then -- 1
      return merge_operands(util.list.rest(p), util.list.rest(q), base_simp, ...)
    elseif #h == 1 then -- 2
      return util.list.join(h, merge_operands(util.list.rest(p), util.list.rest(q), base_simp, ...))
    elseif #h == 2 and lib.compare(h[1], p1) and lib.compare(h[2], q1) then -- 3
      return util.list.join({p1}, merge_operands(util.list.rest(p), q, base_simp, ...))
    elseif #h == 2 and lib.compare(h[1], q1) and lib.compare(h[2], p1) then -- 4
      return util.list.join({q1}, merge_operands(p, util.list.rest(q), base_simp, ...))
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
      return calc.DIV_ZERO
    else
      return u
    end
  elseif k == 'unit' then
    return u
  elseif lib.num_args(u) == 1 then
    local v = simplify.rne_rec(u[2])
    if calc.is_nan_p(v) then
      return calc.NAN
    elseif lib.kind(v, '+') then
      return v
    elseif lib.kind(v, '-') then
      return calc.product({'int', -1}, v)
    end
  elseif lib.num_args(u) == 2 then
    if lib.kind(u, '+', '*', '-', '/') then
      local v, w = simplify.rne_rec(u[2]), simplify.rne_rec(u[3])
      if calc.is_nan_p(v) or calc.is_nan_p(w) then
        return calc.NAN
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
      if calc.is_nan_p(v) then
        return v
      end
      return calc.pow(v, lib.arg(u, 2))
    end
  end
end

-- Simplify rational number expression (rne)
function simplify.rne(u)
  trace_step('rne', u)

  local v = simplify.rne_rec(u)
  if calc.is_nan_p(v) then
    return v
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
    elseif lib.kind(a, 'vec') and lib.kind(b, 'vec') then
      local v = simplify.vector_operation('*', l, simplify.product)
      if v then
        return {simplify.sum(util.list.join({'+'}, lib.get_args(v)))}
      else
        return l
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
    elseif order.front(b, a) then
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

function simplify.product(expr)
  trace_step('product', expr)

  assert(lib.kind(expr, '*'))

  if util.set.contains(expr, calc.NAN) then
    return calc.NAN
  elseif util.set.contains(expr, calc.ZERO) then
    return calc.ZERO
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
    elseif order.front(b, a) then
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

  if util.set.contains(u, calc.NAN) then
    return calc.NAN
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
  if lib.kind(b, 'vec') and not lib.kind(e, 'vec') then
    local v = simplify.vector_operation('^', {b, e}, simplify.power)
    if v then
      return simplify.sum(util.list.join({'+'}, lib.get_args(v)))
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

  -- Do not simplify arguments if tagged as 'plain'
  if not functions.get_attrib(u, functions.attribs.plain, env) then
    u = lib.map(u, simplify.expr, env)
  end

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
      return simplify.expr(v.value, env)
    end
  end
  return expr
end

-- Simplify n-ary operator
---@param l  Expression[]  Argument list
---@param k  Kind          Operator kind
---@param fn function      Operator callback
---@return   Expression[]
function simplify.nary_operator_rec(l, k, fn)
  local a, b = l[1], l[2]
  if #l == 1 then
    return {a}
  elseif #l == 2 and (lib.kind(a) ~= k and lib.kind(b) ~= k) then
    local r = fn(a, b)
    if r then
      return {r}
    elseif order.front(b, a) then
      return {b, a}
    else
      return l
    end
  elseif #l == 2 then
    if lib.kind(a) == k and lib.kind(b) == k then
      return merge_operands(lib.get_args(a), lib.get_args(b), simplify.nary_operator_rec, k, fn)
    elseif lib.kind(a) == k then
      return merge_operands(lib.get_args(a), {b}, simplify.nary_operator_rec, k, fn)
    elseif lib.kind(b) == k then
      return merge_operands({a}, lib.get_args(b), simplify.nary_operator_rec, k, fn)
    end
  elseif #l >= 2 then
    local w = simplify.nary_operator_rec(util.list.rest(l), k, fn)
    if lib.kind(a) == k then
      return merge_operands(lib.get_args(a), w, simplify.nary_operator_rec, k, fn)
    else
      return merge_operands({a}, w, simplify.nary_operator_rec, k, fn)
    end
  end
  return l -- unreachable
end

-- Simplify and merge n-ary operator
---@param u       Expression   Input expression
---@param k       Kind         Kind
---@param fn      function     Calculation function
---@param neutral Expression?  Neutral element
---@return        Expression|nil
function simplify.nary_operator(u, k, fn, neutral)
  trace_step('nary_operator_'..k, {u, k, neutral})

  if util.set.contains(u, calc.NAN) then
    return calc.NAN
  elseif lib.num_args(u) == 1 then
    return lib.arg(u, 1)
  else
    local v = simplify.nary_operator_rec(lib.get_args(u), k, fn) or {}
    if #v == 1 then
      return v[1]
    elseif #v >= 2 then
      return util.list.join(k, v)
    elseif #v == 0 then
      return neutral
    end
  end
end

function simplify.lnot(u)
  trace_step('lnot', u)

  return calc.lnot(lib.arg(u, 1))
end

function simplify.relation(u, env)
  trace_step('relation', u)

  local a, b = lib.arg(u, 1), lib.arg(u, 2)

  -- Transform a<b<c => a<b and b<c if not mixing <> and =
  if lib.is_relop(a) and not lib.is_relop(b) then
    if lib.kind(a, '=', '!=') == lib.kind(u, '=', '!=') then
      local ab = lib.arg(a, 2)
      return simplify.expr({'and', simplify.expr(a, env),
                            simplify.expr({lib.kind(u), ab, b}, env)})
    end
  end

  u = lib.map(u, simplify.expr, env)
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

function simplify.condition(u, env)
  trace_step('condition', u)

  local a, b = lib.arg(u, 1), lib.arg(u, 2)
  if not b or lib.safe_bool(b) then
    return a
  end
  return {'fn', 'cond', a, b}
end

-- Returns a table with expression expr, env and a convenient
-- method to call simplify on it.
local function forward_expression(expr, env)
  return {
    env = env,
    expr = expr,
    simplify = function(self, opt_env)
      return lib.map(self.expr, simplify.expr, opt_env or self.env)
    end
  }
end

function simplify.expr(expr, env)
  trace_step('expr', expr)
  assert(expr and env)

  if lib.kind(expr, 'sym', 'tmp') then
    return expr
  elseif lib.kind(expr, 'bool', 'int', 'real') then
    return expr
  elseif lib.kind(expr, 'unit') then
    return simplify.unit(expr, env)
  elseif lib.kind(expr, 'frac') then
    return simplify.rational_number(expr)
  elseif lib.is_relop(expr) then
    return simplify.relation(expr, env)
  elseif lib.kind(expr, '|') then
    return simplify.with(expr, env)
  elseif lib.kind(expr, 'fn') then
    return simplify.fn(expr, env)
  else
    local k = lib.kind(expr)

    -- Call registered operator
    local o = op.table[k]
    if o and o.simplify then
      return o.simplify(forward_expression(expr, env))
    end

    -- Call fixed simplification
    local v = lib.map(expr, simplify.expr, env)
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
    elseif k == 'and' then
      return simplify.nary_operator(v, k, calc.land)
    elseif k == 'or' then
      return simplify.nary_operator(v, k, calc.lor)
    elseif k == 'not' then
      return simplify.lnot(v)
    elseif k == '::' then
      return simplify.condition(v, env)
    else
      return v
    end
  end
end

return simplify
