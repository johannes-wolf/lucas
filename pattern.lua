local lib = require 'lib'
local util = require 'util'
local Env = require 'env'
local dbg = require 'dbg'

local pattern = {}

-- List of function names that are pattern specific
pattern.pattern_fn = {'cond', 'quote'}

---@alias Variables table<string, Expression>

local function match_head(left, right)
  if not left or not right then return false end

  if lib.is_const(left) and lib.is_const(right) then
    return lib.compare(left, right)
  end

  return util.table.compare_slice(left, right, 1, lib.arg_offset(right))
end

local function eval_cond_test(test, vars)
  local eval = require 'eval'

  for k, v in pairs(vars) do
    test = pattern.substitute_tmp(test, k, v.expr)
  end

  local r = eval.eval(test, Env())
  return lib.safe_bool(r, false)
end

function pattern._match_nary(expr, p, quote, vars)
  for i = 1, lib.num_args(p) - 1 do
    if not pattern._match_rec(lib.arg(expr, i), lib.arg(p, i), quote, vars) then
      return false
    end
  end

  local rest = {}
  for i = 1, lib.arg_offset(expr) do
    table.insert(rest, expr[i])
  end
  lib.copy_args(expr, rest, lib.num_args(p))
  return pattern._match_rec(rest, lib.arg(p, lib.num_args(p)), quote, vars)
end

function pattern._match_vec(expr, p, quote, vars)
  assert(lib.kind(expr, 'vec') and lib.kind(p, 'vec'))

  local p_idx = 1
  local p_any = false
  for i = 1, lib.num_args(expr) do
    -- Pattern out of bounds
    local current_pattern = lib.arg(p, p_idx)
    if not current_pattern and not p_any then
      return false
    end

    -- Skip $__ patterns, but remember we had one
    while lib.safe_tmp(current_pattern) == '__' do
      p_any = true
      p_idx = p_idx + 1
      current_pattern = lib.arg(p, p_idx)

      -- If last pattern arg is $__ return true
      if p_idx > lib.num_args(p) then
        return true
      end
    end

    -- Match vector element against current pattern element
    local r = pattern._match_rec(lib.arg(expr, i), lib.arg(p, p_idx), quote, vars)
    if r then
      p_any = false
      p_idx = p_idx + 1
    else
      -- If no match, but current pattern element is $__ continue without
      -- incrementing pattern index
      if not p_any then
        return false
      end
    end
  end

  -- Match trailing pattern arguments
  for i = p_idx, lib.num_args(p) do
    if lib.safe_tmp(lib.arg(p, i)) ~= '__' then
      return false
    end
  end

  return true
end

function pattern._match_rec(expr, p, quote, vars)
  assert(vars)

  if not quote then
    if lib.kind(p, 'call') then
      -- TODO ...
    end

    if lib.kind(p, 'tmp') then
      local s = lib.sym(p)
      assert(s)

      if s == '_' then -- $_ matches anything
        return true
      end

      if vars[s] then
        return pattern._match_rec(expr, vars[s].expr, true, vars)
      else
        vars[s] = expr
        return true
      end
    end
  end

  -- Test kind and non-argument fields
  if not match_head(expr, p) then
    return false
  end

  -- If vector, check using special handling
  if lib.kind(expr, 'vec') then
    return pattern._match_vec(expr, p, quote, vars)
  end

  -- Match different argument sizes
  if lib.num_args(expr) > lib.num_args(p) then
    return pattern._match_nary(expr, p, quote, vars)
  elseif lib.num_args(expr) < lib.num_args(p) then
    return false
  end

  -- Match all arguments
  for i = 1, lib.num_args(expr) do
    if not pattern._match_rec(lib.arg(expr, i), lib.arg(p, i), quote, vars) then
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
    if lib.kind(expr, 'call') then
      -- TODO: ...
    end

    if lib.kind(expr, 'tmp') then
      local s = lib.sym(expr)
      if vars[s] then
        return util.table.clone(vars[s])
      end
    end
  end

  return lib.map(expr, substitute_rec, quote, vars)
end

-- Match pattern against expression
---@param expr Expression          Expression
---@param p    Expression          Pattern
---@param vars Variables?          Variables
---@return     boolean, Variables
function pattern.match(expr, p, vars)
  vars = vars or {}
  return pattern._match_rec(expr, p, false, vars), vars
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
function pattern.substitute_tmp(expr, var, with)
  return substitute_rec(expr, false, {[var] = with})
end

-- Pass expressions of kind `kind` to callback `fn` and replace them
-- with the value returned.
--
--   substitute_kind({1, a, 2}, 'int', function() return {'int', 0} end)
--   => {0, a, 0}
function pattern.substitute_kind(expr, kind, fn)
  local function subs_kind_rec(sub)
    if lib.kind(sub, kind) then
      return fn(sub)
    else
      return lib.map(sub, subs_kind_rec)
    end
  end
  return subs_kind_rec(expr)
end

return pattern
