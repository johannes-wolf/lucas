local vars = { table = {} }

function vars.def(name, descr, exact, approx)
  local input = require 'input'
  local simplify = require 'simplify'
  local Env = require 'env'

  if type(exact) == 'string' then
    exact = simplify.expr(input.read_expression(exact), Env())
  end
  if type(approx) == 'string' then
    approx = simplify.expr(input.read_expression(approx), Env())
  end
  vars.table[name] = {
    const = true,
    value = exact,
    approx = approx,
  }
end

vars.def('e',         'Eulers number e',     'e',  '2.718281828459045235360')
vars.def('pi',        'Pi',                  'pi', '3.141592653589793238463')

vars.def('nan',       'Not a number',        'nan')
vars.def('inf',       'Infinity',            'inf')
vars.def('ninf',      'Negative infinity',   'ninf')

vars.def('true',      'Boolean true',        {'bool', true})
vars.def('false',     'Boolean false',       {'bool', false})

return vars
