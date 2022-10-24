local op = { table = {} }

-- Add operator to the global operator table
---@param sym  string                     Symbol
---@param kind 'infix'|'prefix'|'suffix'  Kind
---@param prec number                     Precedence
function op.def_operator(sym, kind, prec)
  local t = op.table[sym] or {}
  t[kind] = {
    precedence = prec,
  }
  op.table[sym] = t
end

op.def_operator(':=',  'infix',  1) -- Assignment
op.def_operator('|',   'infix',  2) -- With

op.def_operator('or',  'infix',  3)
op.def_operator('and', 'infix',  4)
op.def_operator('not', 'prefix', 5)

op.def_operator('=',  'infix',   6)
op.def_operator('!=', 'infix',   6)

op.def_operator('<',  'infix',   7)
op.def_operator('<=', 'infix',   7)
op.def_operator('>',  'infix',   7)
op.def_operator('>=', 'infix',   7)

op.def_operator('+', 'infix',    8)
op.def_operator('-', 'infix',    8)
op.def_operator('*', 'infix',    9)
op.def_operator('/', 'infix',    9)
op.def_operator('-', 'prefix',  10)
op.def_operator('^', 'infix',   11)
op.def_operator('!', 'suffix',  12)

return op
