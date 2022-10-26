local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'
local Env = require 'env'

local pattern = {}

---@alias Variables table<string, table>

local function match_head(left, right)
  if not left or not right then return false end

  if lib.is_const(left) and lib.is_const(right) then
    return lib.compare(left, right)
  end

  return util.table.compare_slice(left, right, 1, lib.arg_offset(right))
end

local function match_rec(expr, parent, index, p, quote, vars)
  assert(expr and p and vars)

  -- Evaluate boolean expression
  local function eval_bool(cnd)
    local eval = require 'eval'

    local env = Env()
    for k, v in pairs(vars) do
      env.vars[k] = v.expr
    end

    return lib.safe_bool(eval.eval(cnd, env), false)
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

  expr = lib.make_binary_operator(expr)
  p = lib.make_binary_operator(p)

  if lib.num_args(expr) ~= lib.num_args(p) then return false end

  for i = 1, lib.num_args(p) do
    if not match_rec(lib.arg(expr, i), expr, i, lib.arg(p, i), quote, vars) then
      return false
    end
  end

  return true
end

-- Replace symbols of vars in expr with their replacement expression
---@param expr  Expression   Input expression
---@param quote boolean      Quote (verbatim) mode
---@param vars  Variables[]  Variables
---@return      Expression
local function substitute_rec(expr, quote, vars)
  if not quote then
    if lib.kind(expr, 'fn') then
      local f = lib.fn(expr)
      if f == 'quote' then
        return lib.map(lib.arg(expr, 1), substitute_rec, true, vars)
      end
    end

    if lib.kind(expr, 'sym') then
      local s = lib.sym(expr)
      if vars[s] then
        return util.table.clone(vars[s].expr)
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
