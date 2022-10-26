local fn = require 'functions'
local Env = require 'env'

fn.def_lua('mem.reset', 'unpack', function()
  Env.global:reset()
  return {'bool', true}
end)

fn.def_lua('mem.show', 'unpack', function()
  print(Env.global:print())
  return {'bool', true}
end)

fn.def_lua('mem.load', 'unpack', function()
  local eval = require 'eval'
  local input = require 'input'

  local ok, err = pcall(function()
      for line in io.lines('.lucas_memory') do
        eval.eval(input.read_expression(line))
      end
  end)

  if not ok then
    print('error: '..tostring(err))
  end

  return {'bool', ok}
end)

fn.def_lua('mem.store', 'unpack', function()
  local f = io.open('.lucas_memory', 'w+')
  if f then
    f:write(Env.global:print())
    f:close()
    return {'bool', true}
  end

  return {'bool', false}
end)
