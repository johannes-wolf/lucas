local lib = require 'lib'
local Env = require 'env'
local simplify = require 'simplify'
local fn = require 'functions'
local pattern = require 'pattern'
local calc = require 'calc'
local algo = require 'algorithm'
local g = require 'global'
local util = require 'util'
local dbg = require 'dbg'

local eval = {}

-- Returns true if replacement expr b is free of expr a
local function allow_recall(a, b)
  if a and b then
    if not algo.free_of(b, a) then
      if g.kill_recursive_recall then
        g.error(string.format('Stopped recursive recall'))
        return false
      end
    end
  end
  return true
end

function eval.store_sym(target, value, env)
  assert(lib.kind(target, 'sym'))
  env:set_var(target, value)
end

function eval.store_call(target, value, env)
  assert(lib.kind(target, 'call'))

  local ident = lib.arg(target, 1)
  if not lib.kind(ident, 'sym') then
    error('Invalid function name type: '..lib.kind(ident))
    return calc.FALSE
  end

  error('NOT IMPLEMENTED')
  --env:set_var(ident, )
  --local param = lib.get_args(target, 2) or {}
  --env:set_fn(target, value)
end

function eval.store_fn(expr, lazy, env)
  assert(lib.num_args(expr) == 2)

  local target, value = lib.arg(expr, 1), lib.arg(expr, 2)
  if not lazy then
    value = eval.eval(value, env)
  end

  if lib.kind(target, 'call') then
    return eval.store_call(target, value, env)
  elseif lib.kind(target, 'sym') then
    return eval.store_sym(target, value, env)
  else
    error('Invalid target for store: '..lib.kind(expr))
  end
end

function eval.store(expr, eval_rhs, env)
  local a, b = lib.arg(expr, 1), lib.arg(expr, 2)
  if eval_rhs then
    b = eval.eval(b, env)
  end

  if lib.kind(a, 'sym') then
    env:set_var(lib.sym(a), b)
  elseif lib.kind(a, 'call') then
    -- TODO
    error('NOT IMPLEMENTED')
  else
    g.error('store: Invalid pattern')
  end

  return expr
end

function eval.call(expr, env)
  if lib.kind(lib.arg(expr, 1)) ~= 'sym' then
    return expr
  end

  local sym = eval.eval(lib.arg(expr, 1), env)
  local ident = lib.safe_sym(sym)

  -- Hardcoded path for 'hold'
  if ident == 'hold' or ident == 'hold_form' then
    return expr
  end

  local args = lib.arg(expr, 2)
  local attribs = env:get_attribs(ident)

  local listable = util.set.contains(attribs, fn.attribs.listable)
  if listable and lib.num_args(args) > 1 then
    if lib.kind(lib.arg(args, 1), 'vec') then
      return lib.mapi(lib.arg(args, 1), function( sub)
        return {'call', sym, util.list.join({'vec', sub}, lib.get_args(args, 2))}
      end)
    end
  end

  local hold_all = util.set.contains(attribs, fn.attribs.hold_all)
  local hold_first = hold_all or util.set.contains(attribs, fn.attribs.hold_first)
  local hold_rest = hold_all or util.set.contains(attribs, fn.attribs.hold_rest)
  if not hold_all then
    args = lib.mapi(args, function(i, sub)
      if i == 1 and not hold_first then
        return eval.eval(sub, env)
      elseif i > 1 and not hold_rest then
        return eval.eval(sub, env)
      end
      return sub
    end)
  end

  local flatten = util.set.contains(attribs, fn.attribs.flat)
  if flatten then
    local flat_args = {'vec'}
    local function flatten_rec(call_args)
      for i = 1, lib.num_args(call_args) do
        local a = lib.arg(call_args, i)
        if lib.safe_call_sym(a) == ident then
          flatten_rec(lib.arg(a, 2))
        else
          table.insert(flat_args, a)
        end
      end
    end
    flatten_rec(args)
    args = flat_args
  end

  local r = fn.call(ident, expr, args, env)
  if r then
    if allow_recall(expr, r) then
      return eval.eval(r, env)
    else
      return r
    end
  end

  return expr
end

function eval.sym(expr, env)
  local s = lib.safe_sym(expr)
  if env then
    local v = env:get_var(s)
    if v then
      local u = env.approx and v.approx or v.value
      if u and allow_recall(expr, u) then
        return eval.eval(u, env)
      end
    end
  end
  return expr
end

function eval.unit(expr, env)
  local u = lib.safe_unit(expr)
  if env then
    local v = env:get_var(u)
    if v and v.unit and allow_recall(expr, v.unit) then
      return eval.eval(v.unit, env)
    end
  end
  return expr
end

function eval.with_assign(expr, env)
  local sym, replacement = lib.arg(expr, 1), lib.arg(expr, 2)
  if lib.kind(sym, 'sym') then
    env:set_var(lib.sym(sym), replacement)
  elseif lib.kind(sym, 'unit') then
    env:set_var(lib.unit(sym), replacement)
  elseif lib.kind(sym, 'call') then
    -- TODO: :-)
    --env:set_fn(lib.safe_fn(f), sym, replacement)
  else
    error('not implemented')
  end
end

function eval.with_relation(expr, env)
  if lib.kind(expr, 'and') then
    lib.map(expr, eval.with_relation, env)
  elseif lib.kind(expr, '=') then
    eval.with_assign(expr, env)
  end
end

function eval.with(expr, env)
  local target = lib.arg(expr, 1)
  if lib.is_const(target) then
    return target
  end

  local sub_env = Env(env)
  eval.with_relation(lib.arg(expr, 2), sub_env)

  return eval.eval(target, sub_env)
end

function eval.stmt(expr, env)
  local r
  for i = 1, lib.num_args(expr) do
    r = eval.eval(lib.arg(expr, i), env)
  end
  return r
end

function eval.eval_rec(expr, env)
  if lib.is_const(expr) then
    return expr
  elseif lib.kind(expr, 'sym') then
    return eval.sym(expr, env)
  elseif lib.kind(expr, 'unit') then
    return eval.unit(expr, env)
  --elseif lib.kind(expr, ':=') then
  --  return eval.store(expr, false, env)
  elseif lib.kind(expr, ':==') then
    return eval.store(expr, true, env)
  elseif lib.kind(expr, '::') then
    return eval.condition(expr, env)
  elseif lib.kind(expr, '|') then
    return eval.with(expr, env)
  elseif lib.kind(expr, 'call') then
    return eval.call(expr, env)
  elseif lib.kind(expr, ';') then
    return eval.stmt(expr, env)
  else
    return lib.map(expr, eval.eval_rec, env)
  end
end

-- Expression evaluation entry-point
---@param expr Expression|nil  Expression
---@param env  Env?            Environment injection
---@return Expression|nil
function eval.eval(expr, env)
  if not expr then return nil end
  local r = simplify.expr(eval.eval_rec(simplify.expr(expr, env), env), env)
  return r
end

-- Evaluate expression string
---@param str  string                     Expression
---@param env  Env
---@param vars table<string, Expression>  Variables to set
function eval.str(str, env, vars)
  local input = require 'input'

  env = Env(env)
  for k, v in pairs(vars) do
    env:set_var(k, (type(v) == 'string' and input.read_expression(v)) or v)
  end

  return eval.eval(input.read_expression(str), env)
end

return eval
