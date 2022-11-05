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
  local out = require 'output'

  local function dump_env(env)
    local str
    for k, v in pairs(env.vars) do
      str = (str and (str..' ') or '')..k..' = '..(out.print_alg(v.value or v.unit) or 'nil')
    end
    return str and '{'..str..'}' or '{}'
  end

  local env = Env()
  local u = (type(ou) == 'string' and Parse(ou)) or eval.eval(ou, Env(env))
  local v = (type(ov) == 'string' and Parse(ov)) or eval.eval(ov, Env(env))

  if not lib.compare(u, v) then
    test.info('   input: '..(type(ou) ~= 'string' and dbg.dump(Parse(ou)) or ou))
    test.info('      is: '..out.print_alg(u))--..' = '..dbg.dump(u))
    test.info('expected: '..out.print_alg(v))--..' = '..dbg.dump(v))
    test.info('     env: '..dump_env(env))
    test.assert(false)
  end
end

require 'fn.all'

add_tests 'test-calc'
add_tests 'test-simplify'
add_tests 'test-algo'
add_tests 'test-relational'
add_tests 'test-poly'
add_tests 'test-pattern'
add_tests 'test-list'
add_tests 'test-dict'
add_tests 'test-matrix'
add_tests 'test-vector'

test.run(tests)
