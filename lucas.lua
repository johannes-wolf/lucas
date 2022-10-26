local input = require 'input'
local output = require 'output'
local util = require 'util'
local fraction = require 'fraction'
local Env = require 'env'
local simplify = require 'simplify'
local units = require 'units'
local functions = require 'functions'

local lib = require 'lib'
local dbg = require 'dbg'

local algo = require 'algorithm'
local eval = require 'eval'

require 'fn.iteration'
require 'fn.memory'
require 'fn.io'



local function desimplify(u)
  local rules = {
    {'when(n*a+b,n<0)', 'b-calc(-n a)'},
    {'when(a+n*b,n<0)', 'a-calc(-n b)'},
  }

  --return rewrite.ruleset_apply(rules, u)
end

local function derivative2(u, x)
  x = x or {'sym', 'x'}
  local v = {'fn', 'deriv', u, x}
  --print('derivative2: '..dbg.dump(v))

  local rules = {
    {'deriv(x, x)',      '1'},
    {'deriv(v^w, x)',    'w v^(w-1) deriv(v, x) + deriv(w, x) v^w ln(v)'},
    {'deriv(u+v, x)',    'deriv(u, x) + deriv(v, x)'},
    {'deriv(u*v, x)',    'deriv(u, x) v + deriv(v, x) u'},
    {'deriv(sin(u), x)', 'cos(u) deriv(u, x)'},
    {'deriv(u, x)',      '0'},
  }

  --return rewrite.rueset_apply(rules, v)
end

--functions.def_lua('deriv', 'table', function(args) return derivative2(args[1], args[2]) end)


-- TESTS
functions.def_lua('n', 'unpack', algo.newtons_method)

local ok, err = true, nil
while true do
  units.compile()

  io.write('['..(ok and 'OK ' or 'ERR')..']> ')

  local str = io.read('l')
  --ok, err = pcall(function()
      local expr = input.read_expression(str)
      if expr then
        --print('input:        '..output.print_sexp(expr))

        local simpl = eval.eval(expr, Env.global)
        --print('simplified:   '..output.print_sexp(simpl))
        print('     = '..output.print_alg(simpl))
      end
  --end)
  if not ok then
    --print('error: '..(err or 'ok'))
  end
end
