local fn = require 'functions'
local lib = require 'lib'
local Env = require 'env'


-- mem.reset()
--   Clears local and global memory
fn.def_lua('mem.reset', 0,
function(_, env)
  Env.global:reset()
  env:reset()
end)
