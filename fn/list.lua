local fn = require 'functions'
local op = require 'operator'
local util = require 'util'
local lib = require 'lib'

-- List Operators
op.def_fn_operator('in',           'in',           'infix', 7, 'list.in')
op.def_fn_operator('union',        'union',        'infix', 7, 'list.union')
op.def_fn_operator('intersection', 'intersection', 'infix', 7, 'list.intersection')

--@alias List Expression
local list = {}

function list.head(l)
  return lib.arg(l, 1)
end

function list.rest(l)
  return util.list.prepend('vec', lib.get_args(l, 2))
end

function list.slice(l, s, e)
  s = lib.expect_int(s)
  e = lib.safe_int(e)
  return lib.copy_args(l, {'vec'}, s, e)
end

function list.get(l, path)
  for i = 1, #path do
    l = lib.arg(l, lib.expect_int(path[i]))
  end
  return l
end

function list.contains(l, elem)
  return {'bool', lib.find_arg(l, lib.compare, elem) ~= nil}
end

function list.union(a, b)
  a = lib.expect_kind(a, 'vec')
  b = lib.expect_kind(b, 'vec')
  return lib.copy_args(b, a)
end

function list.intersection(a, b)
  a = lib.expect_kind(a, 'vec')
  b = lib.expect_kind(b, 'vec')
  local c = {'vec'}
  for i = 0, lib.num_args(a) do
    local e = lib.arg(a, i)
    if lib.safe_bool(list.contains(b, e)) then
      table.insert(c, e)
    end
  end
  return c
end

function list.unique(l)
  l = lib.expect_kind(l, 'vec')
  local r = {'vec'}
  for i = 1, lib.num_args(l) do
    local e = lib.arg(l, i)
    if not lib.safe_bool(list.contains(r, e)) then
      table.insert(r, e)
    end
  end
  return r
end

fn.def_lua('list', 'var',
function(a, _)
  local l = {'vec'}
  for _, v in ipairs(a) do table.insert(l, v) end
  return l
end)

fn.def_lua('list.head', 1,
function(a, _)
  return list.head(a[1])
end)

fn.def_lua('list.rest', 1,
function(a, _)
  return list.rest(a[1])
end)

fn.def_lua('list.slice', {{name = 'list'},
                          {name = 'start'},
                          {name = 'stop', opt = true}},
function(a, _)
  return list.slice(a.list, a.start, a.stop)
end)

fn.def_lua('list.get', {{name = 'list'},
                        {variadic = true}},
function(a, _)
  return list.get(a.list, a.rest)
end)

fn.def_lua('list.contains', {{name = 'list'},
                             {name = 'element'}},
function(a, _)
  return list.contains(a.list, a.element)
end)

fn.def_lua('list.in', {{name = 'element'}, -- Reversed version of contains (for operator in)
                       {name = 'list'}},
function(a, _)
  return list.contains(a.list, a.element)
end)

fn.def_lua('list.union', {{name = 'a'},
                          {name = 'b'}},
function(a, _)
  return list.union(a.a, a.b)
end)

fn.def_lua('list.unique', 1,
function(a, _)
  return list.unique(a[1])
end)

return list
