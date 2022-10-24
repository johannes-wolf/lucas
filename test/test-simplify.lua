local tests = {}

local dbg = require 'dbg'
local util = require 'util'
local input = require 'input'
local simplify = require 'simplify'

local function parse(str)
  return simplify.expr(input.read_expression(str))
end

local function expect(ou, ov)
  local u = (type(ou) == 'string' and parse(ou)) or simplify.expr(ou)
  local v = (type(ov) == 'string' and input.read_expression(ov)) or ov

  if not util.table.compare(u, v) then
    test.info('input: '..dbg.dump((type(ou) == 'string' and parse(ou)) or ou))
    test.info('is: '..dbg.dump(u)..', expected: '..dbg.dump(v))
    test.assert(false)
  end
end

function tests.const_int()
  expect("1", {'int', 1})
end

function tests.const_fraction()
  expect("1:2", {'frac', num=1, denom=2})
end

--[[
function tests.const_float()
  expect("3.141", "3.141")
end
--]]

function tests.add_int()
  expect("1+2", {'int', 3})
  expect("1:2+1:2", {'int', 1})
end

function tests.add_sym()
  expect("a+b", {'+', {'sym', 'a'}, {'sym', 'b'}})
  expect("b+a", {'+', {'sym', 'a'}, {'sym', 'b'}})

  expect("a+b+c", {'+', {'sym', 'a'}, {'sym', 'b'}, {'sym', 'c'}})
  expect("c+b+a", {'+', {'sym', 'a'}, {'sym', 'b'}, {'sym', 'c'}})

  expect("a+a+a", {'*', {'int', 3}, {'sym', 'a'}})
  expect("a+a+b", {'+', {'*', {'int', 2}, {'sym', 'a'}}, {'sym', 'b'}})
  expect("a+b+a", {'+', {'*', {'int', 2}, {'sym', 'a'}}, {'sym', 'b'}})
  expect("b+a+a", {'+', {'*', {'int', 2}, {'sym', 'a'}}, {'sym', 'b'}})
end

test.run(tests)
