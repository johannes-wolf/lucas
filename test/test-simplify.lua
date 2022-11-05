local tests = {}

local dbg = require 'dbg'
local util = require 'util'
local input = require 'input'
local simplify = require 'simplify'
local Env = require 'env'

local function parse(str)
  return simplify.expr(input.read_expression(str), Env())
end

local function expect(ou, ov)
  local u = (type(ou) == 'string' and parse(ou)) or simplify.expr(ou, Env())
  local v = (type(ov) == 'string' and input.read_expression(ov)) or ov

  if not util.table.compare(u, v) then
    test.info('input: '..dbg.dump((type(ou) == 'string' and parse(ou)) or ou))
    test.info('   is: '..dbg.dump(u)..', expected: '..dbg.dump(v))
    test.assert(false)
  end
end

function tests.const_int()
  expect("1",  {'int', 1})
  expect("-1", {'int', -1})
end

function tests.const_fraction()
  expect("1:2", {'frac', 1, 2})
  expect("2:2", {'int',  1})
end

function tests.const_real()
  expect("1.0",   {'real', 1})
  expect("3.141", {'real', 3.141})
end

function tests.add_const()
  expect("1+2",     {'int', 3})
  expect("1:2+1:2", {'int', 1})
  expect("1+1:2",   {'frac', 3, 2})
  expect("1.1+1",   {'real', 2.1})
  expect("1.1+1.1", {'real', 2.2})
  expect("1.5+1:2", {'int',  2.0})
end

function tests.add_inf()
  -- TODO
  --expect("inf+1",   {'sym', 'inf'})
  --expect("1+inf",   {'sym', 'inf'})
  --expect("inf+inf", {'sym', 'inf'})
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

function tests.sub_const()
  expect("1-2",     {'int', -1})
  expect("1:2-1:2", {'int',  0})
  expect("1-1:2",   {'frac', 1, 2})
  expect("1.1-1",   {'real', 1.1-1})
  expect("1.1-1.1", {'int',  0})
  expect("1.5-1:2", {'int',  1.5-0.5})
end

function tests.mul_const()
  expect("1*2",     {'int',  2})
  expect("1:2*1:2", {'frac', 1, 4})
  expect("1*1:2",   {'frac', 1, 2})
  expect("1.1*1",   {'real', 1.1*1})
  expect("1.1*1.1", {'real', 1.1*1.1})
  expect("1.5*1:2", {'real', 1.5*1/2})
end

function tests.mul_inf()
  -- TODO
  --expect("inf*2",   {'sym', 'inf'})
  --expect("2*inf",   {'sym', 'inf'})
  --expect("inf*inf", {'sym', 'inf'})
end

function tests.div_const()
  expect("1/2",     {'frac', 1, 2})
  expect("1:2/1:2", {'int',  1})
  expect("1/1:2",   {'int',  2})
  expect("1.1/1",   {'real',  1.1/1})
  expect("1.1/1.1", {'int',  1})
  expect("1.5/1:2", {'int',  1.5/(1/2)})
end

function tests.div_inf()
  --expect("inf/2",   {'sym', 'inf'})
  --expect("2/inf",   {'int', 0})
  --expect("inf/inf", {'sym', 'nan'})
end

function tests.op_order()
  -- Op_Order constants by value
  Expect('op_order[2, 1]',   '{1,2}')
  Expect('op_order[5:2, 2]', '{2,5:2}')

  -- Op_Order symbols by name
  Expect('op_order[z,b,c]',    '{b,c,z}')
  Expect('op_order[xa,x1,x2]', '{x1,x2,xa}')

  -- Op_Order */+
  Expect('op_order[2b, 3a]',       '{3a,2b}')
  Expect('op_order[a+b, a+c]',     '{a+b,a+c}')
  Expect('op_order[a+c+d, b+c+d]', '{a+c+d,b+c+d}')
  Expect('op_order[c+d,b+c+d]',    '{c+d,b+c+d}')

  -- Op_Order ^
  Expect('op_order[(1+x)^2,(1+x)^3,(1+y)^2]',
                 '{(1+x)^2,(1+x)^3,(1+y)^2}')

  -- Op_Order !
  Expect('op_order[b!,a!]', '{a!,b!}')

  -- Op_Order functions
  Expect('op_order[f[x],g[x]]', '{f[x],g[x]}')
  Expect('op_order[f[x],f[y]]', '{f[x],f[y]}')

  -- Order constants first */+
  Expect('op_list[a 4 b]', '{4,a,b}')
  Expect('op_list[a+4+b]', '{4,a,b}')

  -- Order units last
  Expect('op_list[_u a 4 b]', '{4,a,b,_u}')
  Expect('op_list[_u+a+4+b]', '{4,a,b,_u}')

  -- Do not order templates
  Expect('op_list[$m a 4 b]', '{$m,4,a,b}')
  Expect('op_list[a $m 4 b]', '{4,a,$m,b}')
  Expect('op_list[$m+a+4+b]', '{$m,4,a,b}')
end

return tests
