package.path = package.path .. ';../?.lua'

local input = require 'input'
local eval = require 'eval'
local lib = require 'lib'
local dbg = require 'dbg'
local Env = require 'env'
_G.test = require 'testlib'

local tests = {}
local function add_tests(s)
  for k, v in pairs(require(s)) do
    tests[s..'.'..k] = v
  end
end

function Parse(str)
  return eval.eval(input.read_expression(str), Env())
end

function Expect(ou, ov)
  local u = (type(ou) == 'string' and Parse(ou)) or eval.eval(ou, Env())
  local v = (type(ov) == 'string' and Parse(ov)) or eval.eval(ov, Env())

  if not lib.compare(u, v) then
    test.info('input: '..dbg.dump((type(ou) == 'string' and Parse(ou)) or ou))
    test.info('   is: '..dbg.dump(u)..', expected: '..dbg.dump(v))
    test.assert(false)
  end
end

require 'fn.all'

add_tests 'test-simplify'
add_tests 'test-algo'
add_tests 'test-relational'
add_tests 'test-poly'
add_tests 'test-pattern'

test.run(tests)
