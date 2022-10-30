local functions = require 'functions'
local util = require 'util'
local lib = require 'lib'
local calc = require 'calc'

--@alias List table
local list = {}

function list.head(l)
  return lib.arg(l, 1) or calc.NAN -- NAN?
end

function list.rest(l)
  return util.table.prepend('vec', lib.get_args(l, 2))
end

function list.slice(l, s, e)
  s = lib.safe_int(s) or 1
  e = lib.safe_int(e)
  return util.table.prepend('vec', util.list.slice(l, lib.arg_offset(l) + s - 1, e))
end

---@alias Vector table
local vector = {
  offset = 1
}

-- Returns a vector of size s with all values set to v or 0
---@param s number  Size
---@param v any?    Value
---@return  Vector
function vector.new(s, v)
  s = lib.safe_int(s) or 0
  assert(s >= 0)
  local t = {'vec'}
  for _ = 1, s do table.insert(t, v or {'int', 0}) end
  return t
end

-- Returns a vector of size s with 1 in the selected position p and 0 elsewhere
---@param s number  Size
---@param p number  Position
---@return  Vector
function vector.unit(s, p)
  --assert(p >= 1 and p <= s)
  local t = vector.new(s)
  lib.set_arg(t, lib.safe_int(p), {'int', 1})
  return t
end

-- Returns the norm of a vector
---@param t Vector
---@return  Expression|nil
function vector.norm(t)
  if lib.kind(t, 'vec') then
    if lib.num_args(t) < 2 then
      return calc.NAN
    end

    local n = {}
    for i = 1, lib.num_args(t) do
      table.insert(n, {'^', lib.arg(t, i), {'int', 2}})
    end
    return {'fn', 'sqrt', util.list.join({'+'}, n)}
  end
  return nil
end

local matrix = {}

function matrix.new(m, n, v)
  local t = vector.new()
  for _ = 1, lib.safe_int(m) or 0 do
    table.insert(t, vector.new(n, v))
  end
  return t
end

function matrix.norm(m, n, r, c)
  local t = matrix.new(m, n)
  lib.set_arg(lib.arg(t, lib.safe_int(r)), lib.safe_int(c), {'int', 1})
  return t
end


functions.def_lua('vec', 'var',
function (a, env)
  return util.list.join({'vec'}, a)
end)

functions.def_lua('vec.unit', 2,
function (a, env)
  return vector.unit(a[1], a[2])
end)

functions.def_lua('vec.new', 1,
function (a, env)
  return vector.new(a[1])
end)

functions.def_lua('vec.len', 1,
function (a, env)
  return lib.kind(a, 'vec') and lib.num_args(a[1])
end)

functions.def_lua('vec.norm', 1,
function (a, env)
  return vector.norm(a[1])
end)

-- Matrix

functions.def_lua('mat.new', 2,
function (a, env)
  return matrix.new(a[1], a[2])
end)

functions.def_lua('mat.norm', 4,
function (a, env)
  return matrix.norm(a[1], a[2], a[3], a[4])
end)
