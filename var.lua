local vars = { table = {} }

function vars.def(name, descr, exact, approx)
  local input = require 'input'
  local simplify = require 'simplify'
  if type(exact) == 'string' then
    exact = simplify.expr(input.read_expression(exact))
  end
  if type(approx) == 'string' then
    approx = simplify.expr(input.read_expression(approx))
  end
  vars.table[name] = {
    const = true,
    value = exact,
    approx = approx,
  }
end

vars.def('e',         'Eulers number e',     'e')
vars.def('pi',        'Pi',                  'pi', '3.141592653589793238463')

vars.def('inf',       'Infinity',            'inf')
vars.def('ninf',      'Negative infinity',   'ninf')

return vars
