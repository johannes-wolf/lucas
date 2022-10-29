local tests = {}

local dbg = require 'dbg'
local util = require 'util'
local input = require 'input'
local eval = require 'eval'
local Env = require 'env'

require 'fn.math'

local function parse(str)
  return eval.eval(input.read_expression(str), Env())
end

local function expect(ou, ov)
  local u = (type(ou) == 'string' and parse(ou)) or eval.eval(ou, Env())
  local v = (type(ov) == 'string' and parse(ov)) or eval.eval(ov, Env())

  if not util.table.compare(u, v) then
    test.info('input: '..dbg.dump((type(ou) == 'string' and parse(ou)) or ou))
    test.info('   is: '..dbg.dump(u)..', expected: '..dbg.dump(v))
    test.assert(false)
  end
end

function tests.seq()
  expect('seq(x, x, 1, 10)',  'vec(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)')
  expect('seq(x^2, x, 1, 3)', 'vec(1, 4, 9)')
  expect('seq(x^2, x=1, 3)',  'vec(1, 4, 9)')
  expect('seq(x^2, y, 1, 3)', 'vec(x^2, x^2, x^2)')
  expect('seq(x, x, 3, 1)',   'vec()')
end

function tests.map()
  expect('map(sin,    vec(1, 2, 3))', 'vec(sin(1), sin(2), sin(3))')
  expect('map(f(x,1), vec(1, 2, 3))', 'vec(f(1,1), f(2,1), f(3,1))')
end

function tests.sum_seq()
  expect('sum_seq(x, x=1, 5)', '1+2+3+4+5')
end

function tests.prod_seq()
  expect('prod_seq(x, x=1, 5)', '1*2*3*4*5')
end

function tests.derivative()
  expect('derivative(y, x)',          '0')
  expect('derivative(x, x)',          '1')
  expect('derivative(x^4+5x^4-6, x)', '4 x^3 + 4 5 x^3')
end

function tests.factor_out()
  expect('factor_out((x^2+x y)^3)',       'x^3(x+y)^3')
  expect('factor_out(a*(b+b x))',         'a b*(1+x)')
  expect('factor_out(a b x+a c x+b c x)', 'x*(a b+b c+a c)')
  expect('factor_out(a/x+b/x)',           '1/x*(a+b)')
  expect('factor_out((a+b)^2,a)',         'a^2*(1+b/a)^2')
end

function tests.min()
  expect('min(a,b)',   'min(a,b)')
  expect('min(1,2)',   '1')
  expect('min(1,0.1)', '0.1')
  expect('min(3)',     '3')
  expect('min(1,2,3)', '1')
  expect('min(vec(1,2,3))', '1')
end

function tests.max()
  expect('max(a,b)',   'max(a,b)')
  expect('max(1,2)',   '2')
  expect('max(1,0.1)', '1')
  expect('max(3)',     '3')
  expect('max(1,2,3)', '3')
  expect('max(vec(1,2,3))', '3')
end

test.run(tests)
