package.path = package.path .. ';../?.lua'

_G.test = require 'testlib'

local tests = {}
local function add_tests(s)
  for k, v in pairs(require(s)) do
    tests[s..'.'..k] = v
  end
end

add_tests 'test-simplify'
add_tests 'test-algo'

test.run(tests)
