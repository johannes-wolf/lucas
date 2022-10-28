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

test.run(tests)
