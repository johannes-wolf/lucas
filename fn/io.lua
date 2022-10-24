local fn = require 'functions'
local memory = require 'memory'
local output = require 'output'

fn.def_lua('mem.load', 'unpack', function()
  local eval = require 'eval'
  local input = require 'input'

  for line in io.lines('.lucas_memory') do
    eval.eval(input.read_expression(line))
  end

  return {'bool', true}
end)

fn.def_lua('mem.store', 'unpack', function()
  local f = io.open('.lucas_memory', 'w+')
  for k, v in pairs(memory.vars) do
    f:write(k, ':=', output.print_alg(v), '\n')
  end

  for _, v in pairs(memory.fn) do
    for _, r in ipairs(v.rules or {}) do
      f:write(output.print_alg(r.pattern), ':=', output.print_alg(r.replacement), '\n')
    end
  end

  f:close()
  return {'bool', true}
end)
