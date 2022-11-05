local lib = require 'lib'
local op = {
  table = {},
  name = {},
  symbols = {},
}

---@alias OpKind 'infix'|'prefix'|'suffix'
---@alias OpPrec integer

-- Add operator to the global operator table
---@param sym  string  Symbol
---@param name string  Name
---@param kind OpKind
---@param prec OpPrec  Precedence
function op.def_operator(sym, name, kind, prec)
  local t = op.table[sym] or {}
  t[kind] = {
    precedence = prec,
  }
  op.table[sym] = t
  op.name[sym] = name or op.name[sym]

  table.insert(op.symbols, sym)
  table.sort(op.symbols, function(a, b) return a:len() > b:len() end)
  return t
end

-- Add operator that gets replaced by a function call to fn
-- durring automatic simplification.
---@param sym  string           Symbol
---@param name string           Name
---@param kind OpKind           Name
---@param prec OpPrec           Precedence
---@param fn   string|function  Function name or callback function
function op.def_fn_operator(sym, name, kind, prec, fn)
  local t = op.def_operator(sym, name, kind, prec)
  if type(fn) == 'string' then
    t.simplify = function(ns_expr, _)
      local args = {'vec'}
      lib.copy_args(ns_expr:simplify(), args)
      return {'call', {'sym', fn}, args}
    end
  else
    t.simplify = fn
  end
  return t
end

op.def_fn_operator(':=',  'assign',   'infix', 1, 'store')      -- Assignment
op.def_fn_operator(':==', 'assign_e', 'infix', 1, 'store_eval') -- Assignment (evaluated rest)
op.def_operator('|',   'with',   'infix',   2) -- With

op.def_operator('or',  'or',     'infix',   3)
op.def_operator('and', 'and',    'infix',   4)
op.def_operator('not', 'not',    'prefix',  5)

op.def_operator('=',   'eq',     'infix',   6)
op.def_operator('!=',  'neq',    'infix',   6)

--op.def_operator('::',  'cond',   'infix',   6) -- Pattern condition (use nested or parens instead of 'and' to work around precedence conflicts)

op.def_operator('<',   'lt',     'infix',   8)
op.def_operator('<=',  'lteq',   'infix',   8)
op.def_operator('>',   'gt',     'infix',   8)
op.def_operator('>=',  'gteq',   'infix',   8)

op.def_operator('+',   'sum',    'infix',   9)
op.def_operator('-',   'sub',    'infix',   9)
op.def_operator('*',   'mul',    'infix',  10)
op.def_operator('/',   'div',    'infix',  10)
op.def_operator('-',   nil,      'prefix', 11)
op.def_operator('^',   'pow',    'infix',  12)
op.def_operator('!',   'fact',   'suffix', 13)

return op
