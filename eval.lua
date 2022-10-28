local lib = require 'lib'
local Env = require 'env'
local simplify = require 'simplify'
local functions = require 'functions'
local pattern = require 'pattern'
local dbg = require 'dbg'

local eval = {}

function eval.store(expr, env)
  env = Env.global

  local a, b = lib.arg(expr, 1), lib.arg(expr, 2)
  if lib.kind(a, 'sym') then
    env:set_var(lib.sym(a), b)
  elseif lib.kind(a, 'fn') then
    env:set_fn(a, b)
  elseif lib.kind(a, 'unit') then
    env:set_unit(lib.unit(a), b)
  else
    return 'undef'
  end

  return expr
end

function eval.fn(expr, env)
  local u = functions.call(expr, env)
  if u and not lib.compare(expr, u) then
    return eval.eval(u, env)
  end
  return expr
end

function eval.sym(expr, env)
  local s = lib.safe_sym(expr)
  if env then
    local v = env:get_var(s)
    if v then return (env.approx and v.approx) or v.value end
  end
  return expr
end

function eval.unit(expr, env)
  local u = lib.safe_unit(expr)
  if env then
    local v = env:get_unit(u)
    if v and v.value then
      return v.value
    end
  end
  return expr
end

-- TODO: Implement recursive pattern matching, and allow non symbol patterns!
function eval.with_assign(expr, env)
  local sym, replacement = lib.arg(expr, 1), lib.arg(expr, 2)
  if lib.kind(sym, 'sym') then
    env:set_var(lib.sym(sym), replacement)
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
  local sub_env = Env(env)
  eval.with_relation(lib.arg(expr, 2), sub_env)

  -- First evaluation with normal env
  local target = eval.eval(lib.arg(expr, 1), env)
  if lib.is_const(target) then
    return target
  end

  -- Second evaluation with sub-env
  return eval.eval(target, sub_env)
end

function eval.eval_rec(expr, env)
  if lib.is_const(expr) then
    return expr
  elseif lib.kind(expr, 'sym') then
    return eval.sym(expr, env)
  elseif lib.kind(expr, 'unit') then
    return eval.unit(expr, env)
  elseif lib.kind(expr, ':=') then
    return eval.store(expr, env)
  elseif lib.kind(expr, '|') then
    return eval.with(expr, env)
  elseif lib.kind(expr, 'fn') then
    return eval.fn(expr, env)
  else
    return lib.map(expr, eval.eval_rec, env)
  end
end

-- Expression evaluation entry-point
---@param expr Expression  Expression
---@param env  Env?        Environment injection
---@return Expression
function eval.eval(expr, env)
  return simplify.expr(eval.eval_rec(simplify.expr(expr, env), env), env)
end

return eval