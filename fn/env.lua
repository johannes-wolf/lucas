local fn = require 'functions'
local lib = require 'lib'
local util = require 'util'
local calc = require 'calc'

local function store_expr(sym, expr, env)
  env:set_var(lib.safe_sym(sym), expr)
end

local function get_condition_call(call)
  if lib.safe_call_sym(call) == 'cond' then
    return get_condition_call(lib.call_arg(call, 1))
  else
    return lib.arg(call, 1)
  end
end

local function store_call(call, expr, env)
  local sym = get_condition_call(call)
  env:set_call(lib.safe_sym(sym), call, expr)
end

-- store
--   store expression for symbol
fn.def_lua('store', {{name = 'symbol'},
                     {name = 'expr'}},
function (a, env)
  if lib.kind(a.symbol, 'sym') then
    return store_expr(a.symbol, a.expr, env)
  elseif lib.kind(a.symbol, 'call') then
    return store_call(a.symbol, a.expr, env)
  end
end, fn.attribs.hold_all)

-- store_eval
--   store expression for symbol (with expr evaluated)
fn.def_lua('store_eval', {{name = 'symbol'},
                          {name = 'expr'}},
function (a, env)
  if lib.kind(a.symbol, 'sym') then
    return store_expr(a.symbol, a.expr, env)
  elseif lib.kind(a.symbol, 'call') then
    return store_call(a.symbol, a.expr, env)
  end
end, fn.attribs.hold_first)

-- set_attribute
--   set attribute to symbol
fn.def_lua('set_attribute', {{name = 'symbol'},
                             {name = 'attribute'}},
function (a, env)
  if env and lib.kind(a.symbol, 'sym') and lib.kind(a.attribute, 'sym') then
    env:set_attribute(lib.safe_sym(a.symbol),
                      lib.safe_sym(a.attribute))
    return calc.SYM_OK
  end
  return calc.SYM_ERROR
end, fn.attribs.hold_all)

-- get_attributes
--   returns if symbol has attribute set
fn.def_lua('has_attribute', {{name = 'symbol'},
                             {name = 'attribute'}},
function (a, env)
  if env and lib.kind(a.symbol, 'sym') and lib.kind(a.attribute, 'sym') then
    return env:has_attribute(lib.safe_sym(a.symbol),
                             lib.safe_sym(a.attribute)) and calc.TRUE or calc.FALSE
  end
  return calc.SYM_ERROR
end, fn.attribs.hold_all)

-- get_attributes
--   returns list of attributes of symbol
fn.def_lua('get_attributes', {{name = 'symbol'}},
function (a, env)
  if env and lib.kind(a.symbol, 'sym') and lib.kind(a.attribute, 'sym') then
    return util.list.prepend('vec', env:get_attributes(lib.safe_sym(a.symbol)))
  end
  return calc.SYM_ERROR
end, fn.attribs.hold_all)
