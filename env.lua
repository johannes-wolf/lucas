require 'class'
local lib = require 'lib'

---@class Env
local Env = Class('Env')
function Env:init(parent, mode)
  if parent ~= 'clean' then
    self.parent = parent or Env.global
  end

  self.approx = mode == 'approx'
  self.vars = {}
  self.fn = {}
  self.units = {}
end

function Env:undef(name)
  if name then
    self.vars[name] = nil
    self.fn[name] = nil
    self.units[name] = nil
    return true
  end
end

function Env:get_var(name)
  return self.vars[name] or (self.parent and self.parent:get_var(name))
end

function Env:get_fn(name)
  return self.fn[name] or (self.parent and self.parent:get_fn(name))
end

function Env:get_unit(name)
  return self.units[name] or (self.parent and self.parent:get_unit(name))
end

-- Store symbol name => expr
function Env:set_var(name, expr, const, override)
  local v = self:get_var(name)
  if not override and v and v.const then
    error('symbol '..name..' is constant')
  end

  if lib.safe_sym(expr) == name then
    self.vars[name] = nil
  else
    self.vars[name] = {
      const = const,
      value = expr,
    }
  end
end

-- Store function pattern => expr
-- Clear old functions if reset is true.
function Env:set_fn(name, pattern, expr, reset, override)
  name = name or lib.safe_fn(pattern)
  if not name then
    error('invalid function name')
  end

  local v = self:get_fn(name)
  if not override and v and v.const then
    error('function '..name..' is marked constant')
  end

  if reset then
    self.fn[name] = nil
  end

  self.fn[name] = self.fn[name] or { rules = {} }
  local f = self.fn[name]
  local rule = require 'rule'
  table.insert(f.rules, rule.make(pattern, expr))

  local functions = require 'functions'
  functions.reorder_rules(f)
end

-- Store unit name => expr
function Env:set_unit(name, expr, override)
  local v = self:get_unit(name)
  if not override and v and v.const then
    error('unit '..name..' is marked constant')
  end

  if lib.safe_unit(expr) == name then
    self.units[name] = nil
  else
    self.units[name] = {
      value = expr
    }
  end
end

-- Reset all (localy) stored information
function Env:reset()
  self.approx = false
  self.vars = {}
  self.fn = {}
  self.units = {}
end

-- Return all (local) information as consumable expressions
---@return string
function Env:print()
  local output = require 'output'

  local str = ''
  for k, v in pairs(self.vars or {}) do
    str = str .. string.format('%s := %s\n', k, output.print_alg(v.value))
  end
  for k, v in pairs(self.units or {}) do
    str = str .. string.format('%s := %s\n', k, output.print_alg(v.value))
  end
  for _, v in pairs(self.fn or {}) do
    for _, r in pairs(v.rules or {}) do
      str = str .. string.format('%s := %s\n', output.print_alg(r.pattern), output.print_alg(r.replacement))
    end
  end
  return str
end

Env.global = Env()

Env.global.get_var = function(self, name)
  local vars = require 'var'
  return self.vars[name] or vars.table[name]
end

Env.global.get_fn = function(self, name)
  local functions = require 'functions'
  return self.fn[name] or functions.table[name]
end

Env.global.get_unit = function(self, name)
  local units = require 'units'
  return self.units[name] or units.table[name]
end

return Env
