local functions = require 'functions'
local operator = require 'operator'
local pattern = require 'pattern'
local Env = require 'env'
local algo = require 'algorithm'
local lib = require 'lib'
local g = require 'global'
local dbg = require 'dbg'

functions.def_lua('op', 2,
function (a, _)
  local n = lib.safe_int(a[2])
  return n and lib.arg(a[1], n)
end)

functions.def_lua('num_op', 1,
function (a, _)
  return {'int', lib.num_args(a[1]) or 0}
end)

functions.def_lua('kind', 1,
function (a, _)
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

functions.def_lua('free_of', 2,
function (a, _)
  return algo.free_of(a[1], a[2])
end)
