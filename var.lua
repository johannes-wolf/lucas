local vars = { table = {} }

function vars.def(name, descr, expr)
  if type(expr) == 'string' then
    local input = require 'input'
    local simplify = require 'simplify'
    expr = simplify.expr(input.read_expression(expr))
  end
  vars.table[name] = expr
end

local approx_pi = '3.141592653589793238463'

vars.def('e', 'Eulers number e', '1')

return vars
