local fn = require 'functions'
local lib = require 'lib'
local calc = require 'calc'
local list = require 'fn.list'
local dbg = require 'dbg'

local matrix = {}

function matrix.size(a)
  return {'int', lib.num_args(a) or 0},
         {'int', lib.num_args(lib.arg(a, 1)) or 0}
end

function matrix.new(m, n, v)
  local t = {'vec'}
  m = lib.expect_int(m)
  n = lib.expect_int(n)
  v = v or {'int', 0}
  for _ = 1, m do
    table.insert(t, lib.make_list_n(n, v))
  end
  return t
end

function matrix.norm(m, n, r, c)
  local t = matrix.new(m, n)
  lib.set_arg(lib.arg(t, lib.expect_int(r)), lib.expect_int(c), {'int', 1})
  return t
end

function matrix.get_col(l, m)
  m = lib.expect_int(m)
  local v = {'vec'}
  for i = 1, lib.num_args(l) do
    table.insert(v, lib.arg(lib.arg(l, i), m))
  end
  return v
end

function matrix.get_row(l, n)
  n = lib.expect_int(n)
  return lib.arg(l, n)
end

function matrix.apply2(a, b, fn)
  a = lib.expect_kind(a, 'vec')
  b = lib.expect_kind(b, 'vec')
  if lib.num_args(a) == lib.num_args(b) then
    if lib.num_args(lib.arg(a, 1)) == lib.num_args(lib.arg(b, 1)) then
      return lib.mapi(a, function(m, r)
        return lib.mapi(r, function(n, v)
          return fn(v, lib.arg(lib.arg(b, m), n))
        end)
      end)
    end
  end
  error('Incompatible matrixes')
end

function matrix.map(a, fn)
  return lib.mapi(a, function(m, r)
    return lib.mapi(r, function(n, v)
      return fn(m, n, v)
    end)
  end)
end

function matrix.transpose(a)
  local m, n = matrix.size(a)
  local l = matrix.new(n, m)
  return matrix.map(l, function(nm, nn)
    return lib.arg(lib.arg(a, nn), nm)
  end)
end

function matrix.sum(a, b)
  return matrix.apply2(a, b, calc.sum)
end

function matrix.mul_scalar(a, s)
  return matrix.map(a, function(_, _, v) return calc.product(v, s) end)
end

fn.def_lua('mat', 'var',
function (a, _)
  local m = {'vec'}
  local c = nil
  for _, v in ipairs(a) do
    local row = lib.expect_kind(v, 'vec')
    if c and c ~= lib.num_args(row) then
      error('Varying row length')
    end
    c = lib.num_args(row)
    table.insert(m, row)
  end
  return m
end)

fn.def_lua('mat.new', {{name = 'm'},
                       {name = 'n'},
                       {name = 'v', opt = true}},
function (a, _)
  return matrix.new(a.m, a.n, a.v)
end)

fn.def_lua('mat.norm', {{name = 'm'},
                        {name = 'n'},
                        {name = 'r'},
                        {name = 'c'}},
function (a, _)
  return matrix.norm(a.m, a.n, a.r, a.c)
end)

fn.def_lua('mat.at', {{name = 'matrix'},
                      {variadic = true}},
function (a, _)
  return list.get(a.matrix, a.rest)
end)

fn.def_lua('mat.row', {{name = 'matrix'},
                       {name = 'm'}},
function (a, _)
  return matrix.row(a.matrix, a.m)
end)

fn.def_lua('mat.col', {{name = 'matrix'},
                       {name = 'n'}},
function (a, _)
  return matrix.row(a.matrix, a.n)
end)

fn.def_lua('mat.size', 1,
function (a, _)
  local l = lib.expect_kind(a[1], 'vec')
  local m, n = matrix.size(l)
  return {'vec', m, n}
end)

fn.def_lua('mat.transpose', {{name = 'matrix'}},
function (a, _)
  return matrix.transpose(a.matrix)
end)

fn.def_lua('mat.add', 2,
function (a, _)
  return matrix.sum(a[1], a[2])
end)

fn.def_lua('mat.smul', 2,
function (a, _)
  return matrix.mul_scalar(a[1], a[2])
end)

return matrix
