local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'
local dbg = require 'dbg'

local pattern = {}

---@alias Variables table<string, table>

local function match_head(expr, p)
  if not expr or not p then return false end

  if lib.is_const(expr) and lib.is_const(p) then
    return lib.compare(expr, p)
  end

  local n = lib.arg_offset(p)
  for i = 1, n do
    if expr[i] ~= p[i] then return false end
  end

  return true
end

local function match_rec(expr, parent, index, p, quote, vars)
  assert(expr and p and vars)

  -- Evaluate boolean expression
  local function eval_bool(cnd)
    local eval = require 'eval'

    local env = eval.make_env()
    for k, v in pairs(vars) do
      env.vars[k] = v.expr
    end

    return calc.is_true(eval.eval(cnd, env))
  end

  if not quote then
    if lib.kind(p, 'fn') then
      local f = lib.fn(p)
      if f == 'quote' then -- quote(sub-pattern)
        return match_rec(expr, parent, index, lib.arg(p, 1), true, vars)
      elseif f == 'cond' then -- cond(sub-pattern, condition)
        local sub, cond = lib.arg(p, 1), lib.arg(p, 2)
        if match_rec(expr, parent, index, sub, quote, vars) then
          return eval_bool(cond)
        end
        return false
      end
    end

    if lib.kind(p, 'sym') then
      local s = lib.sym(p)
      if vars[s] then
        return match_rec(expr, parent, index, vars[s].expr, true, vars)
      else
        vars[s] = {expr = expr, pos = {parent = parent, index = index}}
        return true
      end
    end
  end

  if not match_head(expr, p) then return false end

  if lib.kind(expr, '+', '*') and (lib.num_args(expr) > 2 or lib.num_args(p) > 2) then
    -- Split n-arg +/* into binary operator
    local k = lib.kind(expr)

    local split_p = p
    if lib.num_args(p) > 2 then
      split_p = {k, lib.arg(p, 1), util.list.join({k}, lib.get_args(p, 2))}
    end

    local split_e = expr
    if lib.num_args(expr) > 2 then
      split_e = {k, lib.arg(expr, 1), util.list.join({k}, lib.get_args(expr, 2))}
    end

    return match_rec(split_e, expr, 1, split_p, quote, vars)
  else
    if lib.num_args(expr) ~= lib.num_args(p) then return false end

    for i = 1, lib.num_args(p) do
      if not match_rec(lib.arg(expr, i), expr, i, lib.arg(p, i), quote, vars) then
        return false
      end
    end
  end

  return true
end

local function substitute_rec(expr, quote, vars)
  if not quote then
    if lib.kind(expr, 'fn') then
      local f = lib.fn(expr)
      if f == 'quote' then
        return expr --lib.arg(expr, 1)
      end
    end

    if lib.kind(expr, 'sym') then
      local s = lib.sym(expr)
      if vars[s] then
        expr = util.table.clone(vars[s].expr)
      end
    end
  end

  return lib.map(expr, substitute_rec, quote, vars)
end

-- Match pattern against expression
---@param expr Expression  Expression
---@param p    Expression  Pattern
---@param vars Variables?  Variables
function pattern.match(expr, p, vars)
  vars = vars or {}
  return match_rec(expr, nil, 1, p, false, vars), vars
end

-- Substitute set of variable vars
---@param expr Expression  Expression
---@param vars Variables   Variables
function pattern.substitute(expr, vars)
  return substitute_rec(expr, false, vars)
end

-- Substitute single variale var with expression
---@param expr Expression  Expression
---@param var  string      Symbol name
---@param with Expression  Replacement
function pattern.substitute_var(expr, var, with)
  return substitute_rec(expr, false, {[var] = {expr = with}})
end

return pattern
