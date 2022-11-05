local functions = require 'functions'
local operator = require 'operator'
local util = require 'util'
local algo = require 'algorithm'
local lib = require 'lib'
local g = require 'global'


functions.def_lua('op', 2,
function (a, _)
  local n = lib.safe_int(a[2])
  return n and lib.arg(a[1], n)
end)

functions.def_lua('op_list', 1,
function (a, _)
  return a[1] and util.list.prepend('vec', lib.get_args(a[1]) or {})
end)

functions.def_lua('num_op', 1,
function (a, _)
  return {'int', lib.num_args(a[1]) or 0}
end)

functions.def_lua('kind', 1,
function (a, _)
  local expr = a[1]
  local kind
  if lib.kind(expr, 'call') then
    if lib.kind(lib.arg(expr, 1), 'sym') then
      kind = lib.safe_sym(lib.arg(expr, 1)) or 'nil'
    else
      return 'anonymous'
    end
  else
    kind = operator.name[lib.kind(expr)]
    if kind then
      kind = 'op_'..kind
    elseif not kind then
      kind = lib.kind(expr) or 'nil'
    end
  end
  return {'sym', kind}
end)

functions.def_lua('free_of', 2,
function (a, _)
  return algo.free_of(a[1], a[2])
end)

functions.def_lua('substitute', 'var',
function (a, _)
  return algo.subs_sym(a[1], util.list.slice(a, 2))
end)

functions.def_lua('op_order', 'var',
function (a, _)
  local simplify = require 'simplify'
  table.sort(a, function(x, y)
    return simplify.order.front(x, y)
  end)
  return util.list.prepend('vec', a)
end)

functions.def_lua('hold_form', 1,
function (a, _)
  return {'call', {'sym', 'hold'}, {'vec', a[1]}}
end)

functions.def_lua('release', 1,
function (a, _)
  if lib.safe_call_sym(a[1]) == 'plain' then
    return lib.arg(lib.arg(a[1], 2), 1)
  end
  return a[1]
end)
