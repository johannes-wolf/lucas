local fraction = require 'fraction'
local float = require 'float'
local lib = require 'lib'
local units = require 'units'

local functions = { table = {} }

function functions.def_unary(name, fn)
  functions.table[name] = {
    fn = fn
  }
end

function functions.def_custom(name, arguments, fn)
  functions.table[name] = {
    arguments = arguments,
    fn = fn
  }
end

-- Approximate result
functions.def_unary('approx',
  function(args)
    return float.make(args[1])
  end)

-- Remove units
functions.def_custom('urem', {{kind = 'any'}},
  function(args)
    return units.remove_units(args[1]) or {'int', 1}
  end)

-- Extract units
functions.def_custom('uxtr', {{kind = 'any'}},
  function(args)
    return units.extract_units(args[1]) or {'int', 1}
  end)

return functions
