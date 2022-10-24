local fn = require 'functions'
local lib = require 'lib'
local util = require 'lib'
local memory = require 'memory'

-- undef([sym, ...])
--   Undefines all globaly defined symbols passed as arguments.
--   Returns the number of symbols processed.
fn.def_lua_symb('undef', 'table', function(args)
  local n = 0
  for _, s in ipairs(args) do
    if memory.undef(s) then
      n = n + 1
    end
  end

  return {'int', n}
end)
