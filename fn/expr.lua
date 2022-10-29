local functions = require 'functions'
local operator = require 'operator'
local lib = require 'lib'

functions.def_lua('op', 2,
function (a, env)
  local n = lib.safe_int(a[2])
  return n and lib.arg(a[1], n)
end)

functions.def_lua('num_op', 1,
function (a, env)
  return {'int', lib.num_args(a[1]) or 0}
end)

functions.def_lua('kind', 1,
function (a, env)
  local kind
  if lib.kind(a[1], 'fn') then
    kind = lib.safe_fn(a[1]) or 'nil'
  else
    kind = operator.name[lib.kind(a[1])]
    if kind then
      kind = 'op_'..kind
    elseif not kind then
      kind = lib.kind(a[1]) or 'nil'
    end
  end
  return {'sym', kind}
end)
