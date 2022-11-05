require 'class'
local lib = require 'lib'
local util = require 'util'


---@class Env
local Env = Class('Env')
function Env:init(parent, mode)
  if parent ~= 'clean' then
    self.parent = parent or Env.global
  end

  self.approx = mode == 'approx'
  self.vars = {}
end

function Env:_set_lua_fn(name, fn, attribs)
  self.vars[name] = {
    lua_fn = fn,
    attribs = attribs,
  }
end

function Env:_set_call(name, pattern, expr, attribs)
  assert(name and pattern and expr)

  if not self.vars[name] then
    self.vars[name] = {
      rules = {},
      attribs = {},
    }
  end

  local t = self.vars[name]
  t.attribs = util.set.unique(util.set.union(t.attribs, attribs))
  table.insert(t.rules, {
    pattern = pattern,
    expr = expr
  })
end

function Env:_set_var(name, expr, attribs)
  self.vars[name] = {
    value = expr,
    attribs = attribs
  }
end

function Env:set_var(name, expr, attribs)
  if type(attribs) ~= 'table' then
    attribs = {attribs or {}}
  end

  if type(expr) == 'function' then
    self:_set_lua_fn(name, expr, attribs)
  else
    self:_set_var(name, expr, attribs)
  end
  return self.vars[name]
end

function Env:set_call(name, pattern, expr, attribs)
  self:_set_call(name, pattern, expr, attribs)
  return self.vars[name]
end

function Env:get_var(name)
  return self.vars[name] or (self.parent and self.parent:get_var(name))
end

-- Set attrib(s) for symbol with name
function Env:set_attrib(name, attr)
  if not type(attr) == 'table' then
    attr = {attr}
  end

  local v = self:get_var(name)
  if v then
    v.attribs = util.set.union(v.attribs or {}, attr)
  end
end

-- Test if symbol with name has attrib set
function Env:has_attrib(name, attr)
  local v = self:get_var(name)
  if v then
    return util.set.contains(v.attribs, attr)
  end
  return false
end

-- Get list of attribs for symbol with name
function Env:get_attribs(name)
  local v = self:get_var(name)
  if v then
    return v.attribs
  end
end

function Env:undef(name)
  if name then
    self.vars[name] = nil
    return true
  end
end

-- Reset all (localy) stored information
function Env:reset()
  self.vars = {}
end

-- Return all (local) information as consumable expressions
---@return string
function Env:print()
  local output = require 'output'

  local str = ''
  for k, v in pairs(self.vars or {}) do
    str = str .. string.format('%s := %s\n', k, output.print_alg(v.value))
  end
  return str
end

Env.global = Env('clean')

return Env
