local lib = require 'lib'
local rule = require 'rule'

local memory = {
  vars = {},
  fn = {},
}

-- Store variable
---@param sym Expression|string  Symbol name
function memory.store(sym, expr)
  if type(sym) == 'string' then sym = {'sym', sym} end
  assert(lib.kind(sym, 'sym'))

  memory.vars[lib.sym(sym)] = expr
end

-- Recall stored variable
---@param sym Expression|string  Symbol name
---@return Expression|nil
function memory.recall(sym)
  if type(sym) == 'string' then sym = {'sym', sym} end
  assert(lib.kind(sym, 'sym'))

  return memory.vars[lib.sym(sym)]
end

-- Store function pattern := expr
---@param pattern   Expression  Function pattern
---@param expr      Expression  Function content
---@param overwrite boolean?    Overwrite existing function
function memory.store_fn(pattern, expr, overwrite)
  assert(lib.kind(pattern, 'fn'))

  local name = lib.fn(pattern)
  local f = memory.recall_fn(name)
  if f and not overwrite then
    f.rules = f.rules or {}
    table.insert(f.rules, rule.make(pattern, expr))

    local functions = require 'functions'
    functions.reorder_rules(f)
  else
    memory.fn[name] = {
      rules = {
        rule.make(pattern, expr)
      }
    }
  end
end

-- Recall stored function
---@param sym Expression|string  Function symbol
---@return Expression|nil
function memory.recall_fn(sym)
  if type(sym) == 'string' then sym = {'fn', sym} end
  assert(lib.kind(sym, 'fn'))

  return memory.fn[lib.fn(sym)]
end

-- Fully undefine symbol or function sym
---@param sym Expression
function memory.undef(sym)
  if lib.kind(sym, 'sym') then
    memory.vars[lib.sym(sym)] = nil
    return true
  elseif lib.kind(sym, 'fn') then
    memory.fn[lib.fn(sym)] = nil
    return true
  end
end

return memory
