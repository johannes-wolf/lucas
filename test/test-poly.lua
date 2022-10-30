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

function tests.poly_div()
  Expect('poly.div(5x^2+4x+1,2x+3,x)',       '{-7:4+5:2x,25:4}')
  Expect('poly.div(x^3-12x^2+5x+150,x-5,x)', '{x^2-7x-30,0}')
end

return tests
