local calc = require 'calc'

local tests = {}

function tests.is_zero_p()
  test.TRUE(calc.is_zero_p(calc.ZERO))
  test.TRUE(calc.is_zero_p({'int', 0}))
  test.TRUE(calc.is_zero_p({'real', 0}))
  test.TRUE(calc.is_zero_p({'frac', 0, 1}))

  test.FALSE(calc.is_zero_p(calc.ONE))
  test.FALSE(calc.is_zero_p(calc.NEG_ONE))
  test.FALSE(calc.is_zero_p(calc.NAN))
  test.FALSE(calc.is_zero_p(calc.INF))
  test.FALSE(calc.is_zero_p(calc.NEG_INF))

  test.FALSE(calc.is_zero_p({'int', 1}))
  test.FALSE(calc.is_zero_p({'real', 1}))
  test.FALSE(calc.is_zero_p({'frac', 1, 2}))

  test.FALSE(calc.is_zero_p({'sym', 'a'}))
  test.FALSE(calc.is_zero_p({'tmp', 'a_'}))
  test.FALSE(calc.is_zero_p({'unit', '_a'}))
  test.FALSE(calc.is_zero_p({'fn', 'a'}))
end

function tests.is_nan_p()
  test.TRUE(calc.is_nan_p(calc.NAN) ,'nan')
  test.FALSE(calc.is_nan_p({'int', 0}), '0')
end

function tests.is_inf_p()
  test.TRUE(calc.is_inf_p(calc.INF, 0))
  test.TRUE(calc.is_inf_p(calc.NEG_INF, 0))
  test.TRUE(calc.is_inf_p(calc.INF, 1))
  test.FALSE(calc.is_inf_p(calc.NEG_INF, 1))
  test.FALSE(calc.is_inf_p(calc.INF, -1))
  test.TRUE(calc.is_inf_p(calc.NEG_INF, -1))

  test.FALSE(calc.is_inf_p({'int', 0}, 0))
  test.FALSE(calc.is_inf_p({'sym', 'a'}, 0))
end

function tests.is_natnum_p()
  test.FALSE(calc.is_natnum_p({'int', 0}, false))
  test.TRUE(calc.is_natnum_p({'int', 0}, true))
  test.FALSE(calc.is_natnum_p({'int', -1}, true))
  test.TRUE(calc.is_natnum_p({'int', 1}, true))

  test.FALSE(calc.is_natnum_p({'real', 1.1}, true))
  test.FALSE(calc.is_natnum_p({'frac', 1, 2}, true))
  test.FALSE(calc.is_natnum_p({'sym', 'a'}, true))
  test.FALSE(calc.is_natnum_p({'unit', '_a'}, true))
end

function tests.is_ratnum_p()
  test.TRUE(calc.is_ratnum_p({'int', -1}))
  test.TRUE(calc.is_ratnum_p({'int', 1}))
  test.TRUE(calc.is_ratnum_p({'frac', 1, 2}))
  test.TRUE(calc.is_ratnum_p({'frac', -1, 2}))

  test.FALSE(calc.is_ratnum_p({'real', 1, 2}))
  test.FALSE(calc.is_ratnum_p({'sym', 'a'}))
  test.FALSE(calc.is_ratnum_p({'tmp', 'a_'}))
  test.FALSE(calc.is_ratnum_p({'unit', '_a'}))
  test.FALSE(calc.is_ratnum_p({'fn', 'a'}))
end

function tests.is_true_p()
  test.FALSE(calc.is_true_p({'bool', false}))
  test.TRUE(calc.is_true_p({'bool', true}))
  test.FALSE(calc.is_true_p({'int', 0}))
  test.TRUE(calc.is_true_p({'int', 1}))
  test.FALSE(calc.is_true_p({'real', 0}))
  test.TRUE(calc.is_true_p({'real', 1}))
  test.FALSE(calc.is_true_p({'frac', 0, 1}))
  test.TRUE(calc.is_true_p({'frac', 1, 2}))

  test.FALSE(calc.is_true_p({'sym', 'a'}))
  test.FALSE(calc.is_true_p({'tmp', 'a_'}))
  test.FALSE(calc.is_true_p({'unit', '_a'}))
  test.FALSE(calc.is_true_p({'fn', 'a'}))
end

function tests.gcd()
  Expect('gcd(3,0)', 'nan')
  Expect('gcd(3,2)', '1')
  Expect('gcd(3,9)', '3')
end

function tests.negate()
  Expect(calc.negate({'int', 1}),     '-1')
  Expect(calc.negate({'frac', 1, 2}), '-1:2')
  Expect(calc.negate({'real', 1.2}),  '-1.2')
  Expect(calc.negate({'sym', 'a'}),   '-a')

  Expect(calc.negate({'sym', 'nan'}),   'nan')
  Expect(calc.negate({'sym', 'inf'}),   '-inf')
end

function tests.floor()
  Expect('floor(1)',    '1')
  Expect('floor(1.1)',  '1')
  Expect('floor(1.99)', '1')
  Expect('floor(2)',    '2')
  Expect('floor(1:2)',  '0')
  Expect('floor(a)',    'floor(a)')
  Expect('floor(inf)',  'floor(inf)')
end

function tests.ceil()
  Expect('ceil(1)',    '1')
  Expect('ceil(1.1)',  '2')
  Expect('ceil(1.99)', '2')
  Expect('ceil(2)',    '2')
  Expect('ceil(1:2)',  '1')
  Expect('ceil(a)',    'ceil(a)')
  Expect('ceil(inf)',  'ceil(inf)')
end

function tests.numerator()
  Expect('numerator(1:2)',    '1')
  Expect('numerator(a^b)',    'a^b')
  Expect('numerator(a^2)',    'a^2')
  Expect('numerator(a^(-2))', '1')
end

function tests.denominator()
  Expect('denominator(1:2)',    '2')
  Expect('denominator(a^b)',    '1')
  Expect('denominator(a^2)',    '1')
  Expect('denominator(a^(-2))', '(a^(-2))^(-1)')
end

return tests
