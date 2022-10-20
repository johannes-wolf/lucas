local input = require 'input'
local output = require 'output'
local util = require 'util'
local fraction = require 'fraction'
local float = require 'float'
local eval = require 'eval'
local rewrite = require 'rewrite'
local simplify = require 'simplify'
local units = require 'units'

local lib = require 'lib'


function dump(o)
  if type(o) == "table" then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      --s = s .. '['..k..'] = ' .. dump(v) .. ','
      s = s .. dump(v) .. ', '
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

local function derivative(u, x)
  assert(u and x)

  local function test_sym(s)
    return lib.kind(s, 'sym') and lib.sym(s) == lib.sym(x)
  end

  -- FIXME: ln log and exp BUG! HUGE EXPONENTS WHEN USING CHAIN or PRODUCT RULE
  -- TEST WITH: sin(x^2)-ln(x) exp(x)   => Int overflow!
  local function diff_rec(u, x)
    u = util.table.clone(u) -- ???

    if lib.is_const(u) then
      -- Constant rule
      return {'int', 0}
    elseif test_sym(u) then
      -- x^1
      return {'int', 1}
    elseif lib.kind(u, '^') and test_sym(lib.arg(u, 1)) then
      -- Power rule x^a
      local a, b = lib.arg(u, 1), lib.arg(u, 2)
      return {'*', b, {'^', a, {'-', b, {'int', 1}}}}
    elseif lib.kind(u, '^') and test_sym(lib.arg(u, 2)) then
      -- Exponent rule a^x
      local a = lib.arg(u, 1)
      if eval.gt(a, {'int', 0}) then
        return {'*', u, {'fn', 'ln', a}}
      end
    elseif lib.kind(u, 'fn') and lib.fn(u, 'exp') then
      -- Exponent rule e^x
      return {'fn', 'exp', lib.arg(u, 1)}
    elseif lib.kind(u, 'fn') and lib.fn(u, 'ln') then
      -- Log rule ln(x)
      local a = lib.arg(u, 1)
      return {'/', {'int', 1}, a}
    elseif lib.kind(u, 'fn') and lib.fn(u, 'log') then
      -- Log rule log(x, base)
      local a, b = lib.arg(u, 1), lib.arg(u, 2)
      if eval.gt(a, {'int', 0}) and eval.gt(b, {'int', 0}) then
        return {'/', {'int', 1}, {'*', a, {'fn', 'ln', b}}}
      end
    elseif lib.kind(u, '+') then
      -- Sum rule
      return lib.map(u, derivative, x)
    elseif lib.kind(u, '*') and lib.num_args(u) >= 2 then
      -- Product rule
      local a, b = lib.arg(u, 1), lib.arg(u, 2)
      local d = {'+', {'*', derivative(a, x), b}, {'*', a, derivative(b, x)}}
      if lib.num_args(u) > 2 then

print('big *')
local rest = util.list.slice(u, lib.arg_offset(u) + 2)
print('rest='..#rest..' '..dump(rest))
        return derivative(util.list.join({'*', d}, rest), x)
      end
      return d
    elseif lib.kind(u, 'fn') then
      local function chain(r)
        return {'*', r, derivative(lib.arg(u, 1), x)}
      end

      -- Trigonometric functions
      if lib.fn(u, 'sin') then
        return chain({'fn', 'cos', lib.arg(u, 1)})
      elseif lib.fn(u, 'cos') then
        return chain({'-', {'fn', 'sin', lib.arg(u, 1)}})
      elseif lib.fn(u, 'tan') then
        return chain({'/', {'int', 1}, {'^', {'fn', 'cos', lib.arg(u, 1)}, {'int', 2}}}) -- BUG
        -- Inverse trigonometric functions
      elseif lib.fn(u, 'arcsin') then
        -- TODO Roots
      elseif lib.fn(u, 'arccos') then
        -- TODO Roots
      elseif lib.fn(u, 'arctan') then
        -- TODO Roots
      elseif lib.kind(lib.arg(u, 1), 'fn') then
        -- TODO Chain rule
      end
    end

    return u
  end

  return simplify.expr(diff_rec(simplify.expr(u), x))
end

units.compile()

while true do
  local expr = input.read_expression(io.read('l'))
  print('input: ' .. output.print_sexp(expr))

  local simpl = simplify.expr(expr)
  --print('  = ' .. output.print_sexp(simpl))
  print('  = ' .. output.print_alg(simpl))

  do
   --print(' dx = ' .. output.print_alg(derivative(simpl, {'sym', 'x'})))
  end

  do
    local n = rewrite.rewrite(simpl,
                              simplify.expr(lib.make_op('^', lib.make_op('+', lib.make_fn('quote', lib.make_sym('a')), lib.make_sym('b')), {'int', 2})),
                              lib.make_op('+', lib.make_op('^', lib.make_sym('a'), {'int', 2}), lib.make_op('*', {'int', 2}, lib.make_sym('a'), lib.make_sym('b')), lib.make_op('^', lib.make_sym('b'), {'int', 2})),
    'recurse')
    if n then
     --  print('rewrite to: '..output.print_alg(simplify.expr(n)))
    end
  end
end
