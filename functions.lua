local fraction = require 'fraction'
local lib = require 'lib'

local functions = { table = {} }

function functions.def_unary(name, fn)
  functions.table[name] = {
    nargs = 1,
    fn = fn
  }
end

return functions
