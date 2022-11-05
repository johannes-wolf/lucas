local tests = {}

require 'fn.math'

function tests.seq()
  Expect('seq[x_,   x_, 1, 10]', 'vec[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]')
  Expect('seq[x_^2, x_, 1,  3]', 'vec[1, 4, 9]')
  Expect('seq[x_^2, x_=1,   3]', 'vec[1, 4, 9]')
  Expect('seq[x_^2, y_, 1,  3]', 'vec[x_^2, x_^2, x_^2]')
  Expect('seq[x_,   x_, 3,  1]', 'vec[]')
end

function tests.map()
  Expect('map[sin[$1], vec[1, 2, 3]]', 'vec[sin[1], sin[2], sin[3]]')
  Expect('map[f[$1,1], vec[1, 2, 3]]', 'vec[f[1,1], f[2,1], f[3,1]]')
end

function tests.sum_seq()
  Expect('sum_seq[x_, x_=1, 5]', '1+2+3+4+5')
end

function tests.prod_seq()
  Expect('prod_seq[x_, x_=1, 5]', '1*2*3*4*5')
end

function tests.derivative()
  Expect('derivative[y, x]',          '0')
  Expect('derivative[x, x]',          '1')
  Expect('derivative[x^4+5x^4-6, x]', '4 x^3 + 4 5 x^3')
end

function tests.factor_out()
  Expect('factor_out[(x^2+x y)^3]',       'x^3(x+y)^3')
  Expect('factor_out[a*(b+b x)]',         'a b*(1+x)')
  Expect('factor_out[a b x+a c x+b c x]', 'x*(a b+a c+b c)')
  Expect('factor_out[a/x+b/x]',           '1/x*(a+b)')
  Expect('factor_out[(a+b)^2,a]',         'a^2*(1+b/a)^2')
end

function tests.min()
  Expect('min[a,b]',        'min[a,b]')
  Expect('min[1,2]',        '1')
  Expect('min[1,0.1]',      '0.1')
  Expect('min[3]',          '3')
  Expect('min[1,2,3]',      '1')
  Expect('min[vec[1,2,3]]', '1')
end

function tests.max()
  Expect('max[a,b]',        'max[a,b]')
  Expect('max[1,2]',        '2')
  Expect('max[1,0.1]',      '1')
  Expect('max[3]',          '3')
  Expect('max[1,2,3]',      '3')
  Expect('max[vec[1,2,3]]', '3')
end

function tests.expand()
  Expect('expand[(x+2)(x+3)  ]', '6+x^2+5x')
  Expect('expand[x^4*(x+2)   ]', 'x^5+2x^4')
  Expect('expand[a*b*(c+d)   ]', 'a b c+a b d')
  Expect('expand[a*b*(c+d)2  ]', '2a b c+2a b d')
  Expect('expand[(a+b)^2     ]', 'a^2+2a b+b^2')
  Expect('expand[(a-b)^2     ]', 'a^2-2a b+b^2')
  Expect('expand[(a+b)^3:2   ]', 'a*(a+b)^1:2+b*(a+b)^1:2')
  Expect('expand[(a+b)^5:2   ]', 'a^2*(a+b)^1:2+2 a b*(a+b)^1:2+b^2*(a+b)^1:2')
  Expect('expand[sin[a*(b+c)]]', 'sin[a b+a c]')
  Expect('expand[a/(b*(c+d)) ]', 'a/(b c+b d)')
  Expect('expand[1/(x*(x+1)-x*(x+1))]', 'nan')
end

return tests
