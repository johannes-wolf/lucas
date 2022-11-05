local lib = require 'lib'
local calc = require 'calc'
local algo = require 'algorithm'
local poly = require 'poly'
local g = require 'global'

local function S(expr, env)
  local simplify = require 'simplify'
  return simplify.expr(expr, env)
end

local solve = {}

function solve.solve(eq, var, env)
  if lib.is_relop(eq) and lib.num_args(eq) == 2 then
    local lhs, rhs = lib.arg(eq, 1), lib.arg(eq, 2)
    return solve.solve_for(lhs, rhs, var, env)
  else
    g.error('solve: Not an equation')
    return nil
  end
end

function solve.solve_linear(lhs, rhs, var, env)
  local form = algo.linear_form(lhs, var)
  if form then
    local m, n = form[1], form[2]
    return S({'/', n, m}, env)
  end
end

function solve.solve_quadratic(lhs, rhs, var, env)
  local form = algo.quadratic_form(lhs, var)
  if form then
    local a, p, q = table.unpack(form)
    p = S({'/', p, a})
    q = S({'/', q, a})
    return {'vec', S({'-', {'-', {'/', p, {'int', 2}}}, {'^', {'-', {'^', {'/', p, {'int', 2}}, {'int', 2}}, q}, {'frac', 1, 2}}}, env),
                   S({'+', {'-', {'/', p, {'int', 2}}}, {'^', {'-', {'^', {'/', p, {'int', 2}}, {'int', 2}}, q}, {'frac', 1, 2}}}, env)}
  end
end

function solve.try_solve_for(lhs, rhs, var, env)
  if lib.compare(lhs, var) then
    return rhs
  end

  -- TODO: Test if this is a GPE first!
  local deg = poly.gpe.degree(lhs, var)
  if deg then
    deg = calc.to_number(deg, 'int')

    -- TODO: We need polynom decomposition here!

    if deg == 1 then
      return solve.solve_linear(lhs, rhs, var, env)
    elseif deg == 2 then
      return solve.solve_quadratic(lhs, rhs, var, env)
    else
      return {'sym', 'CAN_NOT_SOLVE'}
    end
  end
end

function solve.solve_for(lhs, rhs, var, env)
  if not calc.is_zero_p(rhs) then
    return solve.solve_for(S({'-', lhs, rhs}), calc.ZERO, var, env)
  end

  if not algo.free_of(lhs, var) then
    return solve.try_solve_for(lhs, rhs, var, env)
  end
end

function solve.solve_eq(eq, var, env)
  -- Inequality
  if lib.kind(eq, '!=', '>', '>=', '<', '<=') then
    --local r = solve.solve_for(S({'-', eq}, env), calc.ZERO, var, env)
    -- if r is_negative_p then -> nil, else 1
  end

  return solve.solve_for(eq, calc.ZERO, var, env)
end


return solve
