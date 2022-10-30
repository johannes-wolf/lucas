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

require 'fn.math'
require 'fn.iteration'
require 'fn.memory'
require 'fn.io'
require 'fn.expr'
require 'fn.vec'


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

local env = Env()
local ok, err = true, nil
while true do
  units.compile()

  io.write('['..(ok and 'OK ' or 'ERR')..']> ')

  local str = io.read('l')
  ok, err = pcall(function()
      local expr = input.read_expression(str)
      if expr then
        local simpl = eval.eval(expr, env)
        --print('simplified:   '..output.print_sexp(simpl))
        print('     = '..output.print_alg(simpl))

        env:set_var('ans', simpl)
      end
  end)
  if not ok then
    print('error: '..(err or 'ok'))
    print(debug.traceback())
  end
end
