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

op.def_operator('+', 'infix',  3)
op.def_operator('-', 'infix',  3)
op.def_operator('*', 'infix',  4)
op.def_operator('/', 'infix',  4)
op.def_operator('-', 'prefix', 5)
op.def_operator('!', 'suffix', 7)
op.def_operator('^', 'infix',  7)

return op
