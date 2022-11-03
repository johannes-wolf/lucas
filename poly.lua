local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'
local algo = require 'algorithm'
local g = require 'global'
local Env = require 'env'
local dbg = require 'dbg'

-- GPE = Genera Polynomial Expression
local poly = { gpe = {} }

---@alias Polynom Expression

local function S(expr, env)
  local s = require 'simplify'
  return s.expr(expr, env or Env())
end

---@param u Expression|nil
local function exponent(u)
  if lib.kind(u, '^') then
    return lib.arg(u, 2)
  elseif lib.is_const(u) then
    return calc.ZERO
  else
    return calc.ONE
  end
end

---@param u Expression|nil
local function base(u)
  if lib.kind(u, '^') then
    return lib.arg(u, 1)
  else
    return u
  end
end

-- Iterate monomials of polynom u
-- Single element monoms ar returned as single argument
-- product.
function poly.gpe.each_monom(u, fn)
  if lib.kind(u, '+') then
    for i = 1, lib.num_args(u) do
      poly.gpe.each_monom(lib.arg(u, i), fn)
    end
  elseif lib.kind(u, '*') then
    fn(u)
  else
    fn({'*', u})
  end
end

-- Tests if u is a valid monomial with respect to x
-- Not true for GPEs.
---@param u Polynom
---@param x Symbol
---@reutrn  boolean
function poly.is_monomial(u, x)
  local function test(u, x, inner)
    if lib.kind(u, '^') then
      return lib.compare(lib.arg(u, 1), x) and
             lib.kind(lib.arg(u, 2), 'int') and
             lib.safe_bool(calc.gt(lib.arg(u, 2), calc.ONE))
    elseif not inner and lib.kind(u, '*') and lib.num_args(u) == 2 then
      return inner(lib.arg(u, 1), x, true) and
             inner(lib.arg(u, 1), x, true)
    end
    return lib.is_const(u) or
           lib.compare(u, x)
  end
  return test(u, x, false)
end

-- Returns whether u is a polynom of x
-- Not true for GPEs.
---@param u Expression
---@param x Symbol
---@return  boolean
function poly.is_poly(u, x)
  if lib.kind(u, '+') then
    return lib.all_args(u, poly.gpe.is_monomial, x)
  end
  return poly.gpe.is_monomial(u, x)
end

-- Find the highest degree of symbol x
--
-- Example:
--   x^2 + x => 2
--
---@param u Polynom
---@param x Symbol
---@return  Int
function poly.gpe.degree(u, x)
  assert(u and x, "missing arguments")

  if calc.is_zero_p(u) then
    return calc.NEG_INF
  end

  local r = calc.ZERO
  poly.gpe.each_monom(u, function(m)
    for i = 1, lib.num_args(m) do
      local s = lib.arg(m, i)
      if lib.compare(base(s), x) then
        r = calc.max({r, exponent(s)})
      end
    end
  end)
  return r
end

-- Returns a list of all monomials of polynom u
--
-- Example:
--   (x + y) ^ 3 => { x ^ 3, 3 x ^ 2 y, 3 x y ^ 2, y ^ 3 }
--
---@param u Polynom
---@return  Expression[]
function poly.gpe.monomial_list(u)
  local l = {}

  poly.gpe.each_monom(u, function(m)
    table.insert(l, m)
  end)

  return l
end

-- Returns a list of all coefficients of x in u from degree 0 to hi.
--
-- Example:
--   x ^ 3 + 3 x + 9 => { 9, 3, 0, 1 }
--
---@param u Polynom
---@param x Symbol
---@return  Expression[]
function poly.gpe.coeff_list(u, x)
  assert(u and x, "missing arguments")
  local l = {}

  local deg = poly.gpe.degree(u, x)
  if lib.safe_bool(calc.gteq(deg, calc.ZERO)) then
    for n = 0, calc.to_number(deg) do
      table.insert(l, poly.gpe.coeff(u, x, calc.make_int(n)))
    end
  end

  return l
end

-- Return sum of all monom coefficients of x^j
--
-- Example:
--   a x + b x + c => a + b
--
---@param u Polynom
---@param x Symbol
---@param j Expression  Expontent of x
---@return  Expression
function poly.gpe.coeff(u, x, j)
  local deg_zero = calc.is_zero_p(j)
  if lib.safe_bool(calc.gt(j, calc.ONE)) then
    x = {'^', x, j}
  end

  local r = {'+'}
  poly.gpe.each_monom(u, function(m)
    if not deg_zero and not algo.free_of(m, x) then
      for i = 1, lib.num_args(m) do
        local s = lib.arg(m, i)
        if lib.compare(s, x) then
          local c = {'*'}
          for j = 1, lib.num_args(m) do
            if j ~= i then
              table.insert(c, lib.arg(m, j))
            end
          end

          if lib.num_args(c) == 0 then
            c = calc.ONE
          elseif lib.num_args(c) == 1 then
            c = lib.arg(c, 1)
          end
          table.insert(r, c)
        end
      end
    elseif deg_zero and algo.free_of(m, x) then
      if lib.num_args(m) == 1 then
        table.insert(r, lib.arg(m, 1))
      else
        table.insert(r, m)
      end
    end
  end)

  if lib.num_args(r) == 1 then
    return lib.arg(r, 1)
  elseif lib.num_args(r) > 1 then
    return r
  end
  return calc.ZERO
end

-- Returns sum of all coefficients of x^(deg(u,x))
function poly.gpe.leading_coeff(u, x)
  if calc.is_zero_p(u) then
    return calc.ZERO
  end

  local deg = poly.gpe.degree(u, x)
  return poly.gpe.coeff(u, x, deg)
end

-- Returns all non-constant symbols of all monoms
function poly.variables(u)
  local r = {}
  poly.gpe.each_monom(u, function(m)
    for i = 1, lib.num_args(m) do
      local s = base(lib.arg(m, i))
      if lib.kind(s, 'sym') then
        -- Catch symbols 'x'
        table.insert(r, s)
      elseif lib.kind(s, 'fn') and not lib.is_const(lib.arg(s, 1)) then
        -- Catch functions with symbols 'sin(x)'
        table.insert(r, s)
      end
    end
  end)
  return util.set.unique(r, lib.compare)
end

-- Polynom division u/v with respect to x
function poly.division(u, v, x, env)
  -- TODO: Test if u and v are polynoms in x

  local q = calc.ZERO
  local r = u
  local m = poly.gpe.degree(r, x)
  local n = poly.gpe.degree(v, x)
  local lcv = poly.gpe.leading_coeff(v, x)
  assert(lcv, 'lcv is nil')

  local limit = 1
  while lib.safe_bool(calc.gteq(m, n)) do
    local lcr = poly.gpe.leading_coeff(r, x)
    assert(lcr, 'lcr is nil')

    -- lcr / lcv
    local s = S({'/', lcr, lcv}, env)
    assert(s, 's is nil')

    -- q + s * x ^ (m - n)
    q = S({'+', q, {'*', s, {'^', x, {'-', m, n}}}}, env)
    assert(q, 'q is nil')

    -- expand((r - (lcr * x ^ m)) - (v - (lcv x ^ n)) s * x ^ (m - n))
    r = S(algo.expand(
            {'-', {'-', r, {'*', lcr, {'^', x, m}}},
            {'*', {'-', v, {'*', lcv, {'^', x, n}}}, s, {'^', x, {'-', m, n}}}}), env)
    m = poly.gpe.degree(r, x)
    limit = limit + 1
    if limit > g.kill_iteration_limit then
      return g.KILL
    end
  end
  return q, r
end

function poly.expand(u, v, x, t, env)
  assert(lib.safe_bool(calc.gt(poly.gpe.degree(v, x), {'int', 0})))

  if calc.is_zero_p(u) then
    return calc.ZERO
  else
    local q, r = poly.division(u, v, x, env)
    return S(algo.expand({'+', {'*', t, poly.expand(q, v, x, t, env)}, r}), env)
  end
end

function poly.horner_form(u, x)
  local coeffs = poly.gpe.coeff_list(u, x)
  if not coeffs then
    return calc.ZERO
  end

  local function build_form(degree, high)
    local idx = degree + 1
    if degree == 0 then
      if degree == high then
        return coeffs[idx] -- Constant polynom
      end
      return {'+', coeffs[idx], build_form(degree + 1, high)}
    elseif degree == high then
      return {'*', coeffs[idx], x}
    else
      return {'*', x, {'+', coeffs[idx], build_form(degree + 1, high)}}
    end
  end

  return build_form(0, #coeffs - 1)
end

function poly.horner_solve(u, x)
  local form = poly.horner_form(u, x)
  dbg.call('horner_solve', form)

  local function solve_rec(v)
    local offset, factor = lib.split_args_if(v, '+', 2)
    if lib.kind(lib.arg(factor, 2)) ~= '+' then
      --return {S({'/', offset, lib.arg(factor, 1)})}
      return { S({'/', {'*', calc.NEG_ONE, offset}, lib.arg(factor, 1)}) }
    end

    factor = solve_rec(lib.arg(factor, 2))
    print(dbg.dump({'                      =', factor}))

    local r = {}
    for _, f in ipairs(factor) do
      if calc.is_zero_p(f) then
        dbg.call('horner_solve factor zero offset=', offset)
        table.insert(r, S({'*', calc.NEG_ONE, {'^', {'fn', 'abs', offset}, {'real', 0.5}}}))
        table.insert(r, S({'*', calc.ONE, {'^', {'fn', 'abs', offset}, {'real', 0.5}}}))
      else
        local rr = S({'/', offset, f})
        table.insert(r, rr)
      end
    end
    --dbg.call('horner_solve', offset, '/', factor, ' = ', r)
    return r
  end

  return util.list.prepend('vec', solve_rec(form))
end

return poly
