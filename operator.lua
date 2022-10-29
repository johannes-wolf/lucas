local op = { table = {}, name = {} }

-- Add operator to the global operator table
---@param sym  string                     Symbol
---@param kind 'infix'|'prefix'|'suffix'  Kind
---@param prec number                     Precedence
function op.def_operator(sym, name, kind, prec)
  local t = op.table[sym] or {}
  t[kind] = {
    precedence = prec,
  }
  op.table[sym] = t
  op.name[sym] = name or op.name[sym]
end

op.def_operator(':=',  'assign', 'infix',   1) -- Assignment
op.def_operator('|',   'with',   'infix',   2) -- With

op.def_operator('or',  'or',     'infix',   3)
op.def_operator('and', 'and',    'infix',   4)
op.def_operator('not', 'not',    'prefix',  5)

op.def_operator('=',   'eq',     'infix',   6)
op.def_operator('!=',  'neq',    'infix',   6)

op.def_operator('::',  'cond',   'infix',   6) -- Pattern condition (use nested or parens instead of 'and' to work around precedence conflicts)

op.def_operator('<',   'lt',     'infix',   7)
op.def_operator('<=',  'lteq',   'infix',   7)
op.def_operator('>',   'gt',     'infix',   7)
op.def_operator('>=',  'gteq',   'infix',   7)

op.def_operator('+',   'sum',    'infix',   8)
op.def_operator('-',   'sub',    'infix',   8)
op.def_operator('*',   'mul',    'infix',   9)
op.def_operator('/',   'div',    'infix',   9)
op.def_operator('-',   nil,      'prefix', 10)
op.def_operator('^',   'pow',    'infix',  11)
op.def_operator('!',   'fact',   'suffix', 12)

return op
