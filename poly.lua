local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'
local algo = require 'algorithm'
local g = require 'global'
local env = require 'env'

local poly = { gpe = {} }

local function S(expr, env)
  local s = require 'simplify'
  return s.expr(expr, env or Env())
end

local function exponent(u)
  if lib.kind(u, '^') then
    return lib.arg(u, 2)
  elseif lib.is_const(u) then
    return calc.ZERO
  else
    return calc.ONE
  end
end

local function base(u)
  if lib.kind(u, '^') then
    return lib.arg(u, 1)
  else
    return u
  end
end

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

-- Returns whether u is a polynom of s
---@param u Expression
---@param s table<Expression>
---@return  boolean
function poly.gpe.check(u, s)
  if lib.kind(u, '+') then
    for _, v in ipairs(s) do
      -- TODO: WRONG: Polynoms must have no exponent < 0 !
      --       HOW CHECK IF SOMETHING IS A POLYNOM?
      if algo.free_of(u, v) then
        return false
      end
    end
    return true
  end
  return false
end

-- Find the highest degree of symbol x
--   x^2 + x => 2
function poly.gpe.degree(u, x)
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

-- Return sum of all monom coefficients of x^j
--   a x + b x + c => a + b
---@return table
function poly.gpe.coeff(u, x, j)
  if lib.safe_bool(calc.gt(j, calc.ONE)) then
    x = {'^', x, j}
  end

  local r = {'+'}
  poly.gpe.each_monom(u, function(m)
    if not algo.free_of(m, x) then
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

return poly
