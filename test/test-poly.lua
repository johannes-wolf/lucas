local tests = {}

function tests.poly_variables()
  Expect('poly.vars(3x+a+sin(x))', '{a,x,sin(x)}')
end

function tests.poly_degree()
  Expect('poly.deg(3,x)',        '0')
  Expect('poly.deg(3x,x)',       '1')
  Expect('poly.deg(3x^2,x)',     '2')
  Expect('poly.deg(3x^3+x,x)',   '3')
  Expect('poly.deg(3x^4+x^2,x)', '4')
end

return tests
