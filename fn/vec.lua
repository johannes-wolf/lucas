local fn = require 'functions'
local util = require 'util'
local lib = require 'lib'
local calc = require 'calc'

---@alias Vector table
local vector = {
  offset = 1
}

-- Returns a vector of size s with all values set to v or 0
function vector.new(s, v)
  s = lib.safe_int(s) or 0
  assert(s >= 0)
  local t = {'vec'}
  for _ = 1, s do table.insert(t, v or {'int', 0}) end
  return t
end

-- Returns a vector of size s with 1 in the selected position p and 0 elsewhere
function vector.unit(s, p)
  local t = vector.new(s)
  lib.set_arg(t, lib.expect_int(p), {'int', 1})
  return t
end

-- Returns the norm of a vector
---@param t Vector
---@return  Expression|nil
function vector.norm(t)
  t = lib.expect_kind(t, 'vec')
  if lib.kind(t, 'vec') then
    if lib.num_args(t) < 2 then
      return calc.NAN
    end

    local n = {}
    for i = 1, lib.num_args(t) do
      table.insert(n, {'^', lib.arg(t, i), {'int', 2}})
    end
    return calc.make_fn_call('sqrt', util.list.prepend('+', n))
  end
  return nil
end

fn.def_lua('vec', 'var',
function (a, env)
  return util.list.join({'vec'}, a)
end)

fn.def_lua('vec.unit', 2,
function (a, env)
  return vector.unit(a[1], a[2])
end)

fn.def_lua('vec.new', {{name = 'len', match = 'if_natnum0', transform = 'as_int'},
                       {name = 'v', opt = true}},
function (a, env)
  return vector.new(a.len, a.v)
end)

fn.def_lua('vec.len', 1,
function (a, env)
  return lib.kind(a, 'vec') and lib.num_args(a[1])
end)

fn.def_lua('vec.norm', 1,
function (a, env)
  return vector.norm(a[1])
end)

