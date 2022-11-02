local util = require 'util'
local lib = require 'lib'
local fn = require 'functions'
local g = require 'global'

-- dict is an unsorted non-unique list of tuples
-- acting as key-value pairs.

-- Returns if d qualifies as dictionary
local function is_dict_p(d)
  if lib.kind(d, 'vec') then
    return lib.all_args(d, function(a) return lib.kind(a, 'vec') and lib.num_args(a) == 2 end)
  end
  return false
end

fn.def_lua('dict', 'var',
function (a, _)
  local l = lib.make_list()
  for i, v in ipairs(a) do
    local x, y = lib.split_args_if(v, '=', 2)
    if not x or not y then
      g.error(string.format('dict: Invalid key/value pair at index %d', i))
      return
    end
    table.insert(l, lib.make_list(x, y))
  end
  return l
end)

fn.def_lua('dict.get', {{name = 'dict', match = is_dict_p},
                        {name = 'key'},
                        {name = 'default', opt = true}},
function (a, _)
  local item = lib.find_arg(a.dict, function(i)
    return lib.compare(lib.arg(i, 1), a.key)
  end)
  return item and lib.arg(item, 2) or (a.default or {'int', 0})
end)

fn.def_lua('dict.get_all', {{name = 'dict', match = is_dict_p},
                            {name = 'key'}},
function (a, _)
  local l = lib.make_list()
  local d = a.dict
  for i = 1, lib.num_args(d) do
    if lib.compare(lib.arg(lib.arg(d, i), 1), a.key) then
      table.insert(l, lib.arg(lib.arg(d, i), 2))
    end
  end
  return l
end)

fn.def_lua('dict.keys', {{name = 'dict', match = is_dict_p}},
function (a, _)
  local l = lib.make_list()
  local d = a.dict
  for i = 1, lib.num_args(d) do
    table.insert(l, lib.arg(lib.arg(d, i), 1))
  end
  return l
end)

fn.def_lua('dict.values', {{name = 'dict', match = is_dict_p}},
function (a, _)
  local l = lib.make_list()
  local d = a.dict
  for i = 1, lib.num_args(d) do
    table.insert(l, lib.arg(lib.arg(d, i), 2))
  end
  return l
end)

fn.def_lua('dict.merge', {{name = 'a', match = is_dict_p},
                          {name = 'b', match = is_dict_p}},
function (a, _)
  local l = lib.make_list()
  for _, d in ipairs({a.a, a.b}) do
    lib.copy_args(d, l)
  end
  return l
end)

fn.def_lua('dict.sort', {{name = 'dict'}},
function (a, _)
  local simplify = require 'simplify'
  local t = lib.get_args(a.dict) or {}
  table.sort(t, function(l, r)
    if lib.kind(l, 'vec') and lib.kind(r, 'vec') then
      l, r = lib.arg(l, 1), lib.arg(r, 1)
      -- order.front does not touch templates
      if lib.kind(l, 'tmp') and lib.kind(r, 'tmp') then
        return lib.safe_sym(l) < lib.safe_sym(r)
      end
      return simplify.order.front(l, r) -- TODO: move to own file
    end
    return false
  end)
  return util.list.prepend('vec', t)
end)
