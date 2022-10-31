local lib = require 'lib'
local Env = require 'env'
local simplify = require 'simplify'
local functions = require 'functions'
local pattern = require 'pattern'
local calc = require 'calc'
local algo = require 'algorithm'
local g = require 'global'
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

function eval.store(expr, eval_rhs, env)
  env = Env.global

  local a, b = lib.arg(expr, 1), lib.arg(expr, 2)
  if eval_rhs then
    b = eval.eval(b, env)
  end

  if lib.kind(a, 'sym') then
    env:set_var(lib.sym(a), b)
  elseif lib.kind(a, 'fn') then
    local f = pattern.arg(a)
    if not lib.kind(f, 'fn') then
      error('expected function, got '..lib.kind(f))
    end
    env:set_fn(lib.safe_fn(f), a, b)
  elseif lib.kind(a, 'unit') then
    env:set_unit(lib.unit(a), b)
  else
    g.error('store: Invalid pattern')
  end

  return expr
end

-- The function 'hold' suppresses evaluation for its argument one time.
function eval.fn_hold(expr)
  return lib.arg(expr, 1)
end

function eval.fn(expr, env)
  -- Hardcoded path for 'hold'
  if lib.safe_fn(expr) == 'hold' then
    return eval.fn_hold(expr)
  end

  -- Evaluate arguments first
  if not functions.get_attrib(expr, functions.attribs.plain, env) then
    expr = lib.map(expr, eval.eval, env)
  end

  local u = functions.call(expr, env)
  if u and allow_recall(expr, u) then
    return eval.eval(u, env)
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
    local v = env:get_unit(u)
    if v and v.value and allow_recall(expr, v.value) then
      return eval.eval(v.value, env)
    end
  end
  return expr
end

function eval.with_assign(expr, env)
  local sym, replacement = lib.arg(expr, 1), lib.arg(expr, 2)
  if lib.kind(sym, 'sym') then
    env:set_var(lib.sym(sym), replacement)
  elseif lib.kind(sym, 'unit') then
    env:set_unit(lib.unit(sym), replacement)
  elseif lib.kind(sym, 'fn') then
    local f = pattern.arg(sym)
    if not lib.kind(f, 'fn') then
      error('expected function, got '..lib.kind(f))
    end
    env:set_fn(lib.safe_fn(f), sym, replacement)
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

function eval.eval_rec(expr, env)
  if lib.is_const(expr) then
    return expr
  elseif lib.kind(expr, 'sym') then
    return eval.sym(expr, env)
  elseif lib.kind(expr, 'unit') then
    return eval.unit(expr, env)
  elseif lib.kind(expr, ':=') then
    return eval.store(expr, false, env)
  elseif lib.kind(expr, ':==') then
    return eval.store(expr, true, env)
  elseif lib.kind(expr, '::') then
    return eval.condition(expr, env)
  elseif lib.kind(expr, '|') then
    return eval.with(expr, env)
  elseif lib.kind(expr, 'fn') then
    return eval.fn(expr, env)
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
