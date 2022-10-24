local float = require 'float'
local lib = require 'lib'
local units = require 'units'
local calc = require 'calc'
local pattern = require 'pattern'
local algo = require 'algorithm'
local dbg = require 'dbg'

local functions = { table = {} }

-- Register lua function
---@param name     string            Function name
---@param arg_mode 'unpack'|'table'  Argument pass mode
---@param attribs  table             Function attributes
function functions.def_lua(name, arg_mode, fn, attribs)
  arg_mode = arg_mode or 'unpack'

  local new_fn = fn
  if arg_mode == 'unpack' then
    new_fn = function(a) return fn(table.unpack(a)) end
  end

  functions.table[name] = {
    fn = new_fn,
    attribs = attribs or {},
  }
end

-- Define function that gets arguments passed unevaluated
function functions.def_lua_symb(name, arg_mode, fn)
  functions.def_lua(name, arg_mode, fn, {no_eval_args = true})
end

-- Debug
functions.def_lua_symb('dbg', 'table', function(args)
  for _, v in ipairs(args) do
    print(dbg.dump(v))
  end
  return {'int', 0}
end)


-- Expression
functions.def_lua('free_of', 'unpack', function(u, v)
  return {'bool', algo.free_of(u, v)}
end)

functions.def_lua('derivative', 'unpack', function(f, x)
  return algo.derivative(f, x)
end)

-- Number
functions.def_lua('sign',  'unpack', function(u)
                    if lib.is_const(u) then
                      return {'int', calc.sign(u)}
                    end
end)
functions.def_lua('num',   'unpack', function(u)
                    if lib.is_const(u) then
                      return {'int', calc.numerator(u)}
                    end
end)
functions.def_lua('denom', 'unpack', function(u) return {'int', calc.denominator(u)} end)

-- Type conversion
functions.def_lua('real', 'unpack', function(u)
  if lib.is_const(u) then
    return float.make(u)
  end
end)

-- Type checking functions
local function isa_helper(args, k)
  if not args or #args == 0 then return {'bool', false} end
  for _, v in ipairs(args) do
    if not lib.kind(v, k) then return {'bool', false} end
  end
  return {'bool', true}
end

functions.def_lua('is.function', 'table', function(u) return isa_helper(u, 'fn') end)
functions.def_lua('is.unit',     'table', function(u) return isa_helper(u, 'unit') end)
functions.def_lua('is.symbol',   'table', function(u) return isa_helper(u, 'sym') end)
functions.def_lua('is.bool',     'table', function(u) return isa_helper(u, 'bool') end)
functions.def_lua('is.integer',  'table', function(u) return isa_helper(u, 'int') end)
functions.def_lua('is.fraction', 'table', function(u) return isa_helper(u, 'frac') end)
functions.def_lua('is.real',     'table', function(u) return isa_helper(u, 'real') end)

-- Unit specific functions
functions.def_lua('units.remove',  'unpack', function(u) return units.remove_units(u) or {'int', 1} end)
functions.def_lua('units.extract', 'unpack', function(u) return units.extract_units(u) or {'int', 1} end)


-- Reorder funciton patterns by argument count and type
-- Order by constant
function functions.reorder_rules(f)
  local function score_kind(k)
    if lib.is_const(k) then return 0 end
    if lib.kind(k, 'sym', 'fn') then return 1 end
    return 2
  end

  local function order_first(a, b)
    a = a.pattern; b = b.pattern
    assert(lib.kind(a, 'fn') and lib.kind(b, 'fn'))

    if lib.num_args(a) < lib.num_args(b) then
      return true
    elseif lib.num_args(a) > lib.num_args(b) then
      return false
    end

    for i = 1, lib.num_args(a) do
      local x, y = score_kind(lib.arg(a, i)), score_kind(lib.arg(b, i))
      if x ~= y then
        return x < y
      end
    end

    return false
  end

  if f.rules then
    table.sort(f.rules, order_first)
  end
end



local function get_attrib(f, name, default)
  if f.attribs then
    return f.attribs[name] or default
  end
  return default
end

function functions.call(call, env)
  assert(lib.kind(call, 'fn'))

  local eval = require 'eval'
  local memory = require 'memory'

  local name = lib.fn(call)
  local f = memory.recall_fn(name) or functions.table[name]
  if f then
    if not get_attrib(f, 'no_eval_args') then
      call = lib.map(call, eval.eval, env)
    end

    if f.rules then
      -- CAS function
      for _, ov in ipairs(f.rules) do
        local ok, match = pattern.match(call, ov.pattern)
        if ok then
          local sfn = pattern.substitute(ov.replacement, match)
          return eval.eval(sfn)
        end
      end
    elseif f.fn then
      -- Lua based function
      return f.fn(lib.get_args(call)) or call
    end
  end
  return nil
end

return functions
