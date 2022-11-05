local input = require 'input'
local output = require 'output'
local util = require 'util'
local fraction = require 'fraction'
local Env = require 'env'
local units = require 'units'
local functions = require 'functions'
local g = require 'global'

local lib = require 'lib'
local dbg = require 'dbg'

local algo = require 'algorithm'
local eval = require 'eval'

local var = require 'var'

require 'fn.all'

local function msg(t, s)
  print(string.format(' %3s : %s', t, s))
end

g.message = function(m) return msg('MSG', m) end
g.warn    = function(m) return msg('WRN', m) end
g.error   = function(m) return msg('ERR', m) end

pcall(function()
  for line in io.lines('.lucas_init') do
    eval.eval(input.read_expression(line), Env())
  end
end)

local env = Env()
local n = 1
local ok, err = true, nil
while true do
  units.compile()

  io.write('['..(ok and 'OK ' or 'ERR')..']> ')
  local str = io.read('l')
  ok, err = xpcall(function()
    local expr = input.read_expression(str)
    if expr then
      local simpl = eval.eval(expr, env)
      --print('simplified:   '..output.print_sexp(simpl))

      print(string.format(' %3d = %s', n, output.print_alg(simpl)))
      n = n + 1

      env:set_var('ans', simpl)
    end
  end, debug.traceback)

  if not ok then
    print('error: '..(err or 'ok'))
    print(debug.traceback())
  end
end
