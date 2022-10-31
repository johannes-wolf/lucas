local tests = {}

function tests.poly_variables()
  Expect('poly.vars(3x+a+sin(x))', '{a,sin(x),x}')
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

  -- Validated with maxima and emacs-calc
  Expect('poly.div(6x^6-2x^5-4x^3+3x+3,2x^2+2x-3,x)', '{(12x^4-16x^3+34x^2-66x+117)/4,-(420x-363)/4}')
end

function tests.poly_expand()
  Expect('poly.expand(86+x^5+11x^4+51x^3+124x^2+159x, 5+x^2+4x, x,t)', '1+3t^2+2t+x+t x+t^2 x')
end

return tests
