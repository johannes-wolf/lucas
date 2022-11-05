local vars = {}

function vars.def(name, descr, exact, approx)
  local Env = require 'env'
  local input = require 'input'
  local simplify = require 'simplify'

  if type(exact) == 'string' then
    exact = simplify.expr(input.read_expression(exact), Env())
  end
  if type(approx) == 'string' then
    approx = simplify.expr(input.read_expression(approx), Env())
  end

  local v = Env.global:set_var(name, exact)
  v.const = true
  v.approx = approx
end

vars.def('e',         'Eulers number e',     nil,  '2.718281828459045235360')
vars.def('pi',        'Pi',                  nil,  '3.141592653589793238463')

vars.def('nan',       'Not a number',        nil)
vars.def('inf',       'Infinity',            nil)

vars.def('true',      'Boolean true',        {'int', 1})
vars.def('false',     'Boolean false',       {'int', 0})

return vars
