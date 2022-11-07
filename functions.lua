local lib = require 'lib'
local units = require 'units'
local calc = require 'calc'
local pattern = require 'pattern'
local util = require 'util'
local Env = require 'env'
local dbg = require 'dbg'
local g = require 'global'

local functions = {}

---@enum
functions.attribs = {
  hold_first = 'hold_first', -- Hold first argument
  hold_rest  = 'hold_rest',  -- Hold all but first argument
  hold_all   = 'hold_all',   -- Hold all arguments
  listable   = 'listable',   -- Auto call on each list value  f({1,2,3}) => {f(1),f(2),f(3)}
  flat       = 'flat',       -- Auto flatten arguments        f(f(x), y) => f(x, y)
}

functions.match = {
  is_sym       = function(v) return lib.kind(v, 'sym') end,
  is_tmp       = function(v) return lib.kind(v, 'tmp') end,
  is_unit      = function(v) return lib.kind(v, 'unit') end,
  is_const     = function(v) return lib.is_const(v) end,
  is_container = function(v) return lib.is_container(v) end,
  is_natnum0   = function(v) return calc.is_natnum_p(v, true) end,
  is_natnum1   = function(v) return calc.is_natnum_p(v, false) end,
  is_equation  = function(v) return lib.is_relop(v) end,
}

functions.transform = {
  as_int  = function(v) return calc.integer(v) end,
  as_real = function(v) return calc.real(v) end,
}


local function get_argument(name, idx, arg, spec)
  if spec.match and not spec.match(arg) then
    g.error(string.format('%s: Argument %s (%d) does not match', name, tostring(spec.name or idx), idx))
    return nil
  end
  return spec.name, spec.transform and spec.transform(arg) or arg
end

local function match_arguments(name, args, spec)
  local r = {}
  for i = 1, math.max(#args, #spec) do
    local sa = spec[i]
    if not sa then
      g.error(string.format('%s: Invalid number of arguments %d', name, #args))
      return nil
    end

    if not args[i] then
      if sa.opt then
        break
      else
        g.error(string.format('%s: Missing argument "%s" (%d)', name, sa.name, i))
        return nil
      end
    end

    if sa.variadic then
      r['rest'] = util.list.slice(args, i)
      break
    end

    local id, v = get_argument(name, i, args[i], sa)
    if v then
      r[id or i] = v
    else
      return nil
    end
  end
  return r
end

-- Register lua function
---@param name string              Function name
---@param args 'var'|number|table  Argument pass mode
---@vararg ... string              Function attributes
function functions.def_lua(name, args, fn, ...)
  args = args or 'var'

  local new_fn = fn
  if not args or args == 'var' then
    new_fn = function(a, env)
      return fn(a, env)
    end
  elseif type(args) == 'number' then
    new_fn = function(a, env)
      if a and #a ~= args then
        g.error(string.format('%s: Invalid argument count %d', name, args))
        return nil
      end
      return fn(a, env)
    end
  elseif type(args) == 'table' then
    for _, v in ipairs(args) do
      if type(v.match) == 'string' then
        v.match = functions.match[v.match]
      end
      if type(v.transform) == 'string' then
        v.transform = functions.transform[v.transform]
      end
    end

    new_fn = function(a, env)
      a = match_arguments(name, a, args)
      return a and fn(a, env)
    end
  end

  Env.global:set_var(name, new_fn, ...)
end

functions.def_lua('approx', 1, function(u, env)
  local eval = require 'eval'
  return eval.eval(u[1], Env(env, 'approx'))
end)

--functions.def_lua('fact', 1, function(u)
--  return calc.factorial(u)
--end)

-- Number
functions.def_lua('sign',  1, function(u)
                    u = u[1]
                    if lib.is_const(u) then
                      return {'int', calc.sign(u)}
                    end
end)

-- Type checking functions
local function isa_helper(args, k)
  if not args or #args == 0 then return {'int', 0} end
  for _, v in ipairs(args) do
    if not lib.kind(v, k) then return {'int', 0} end
  end
  return {'int', 1}
end

functions.def_lua('is.function', 'var', function(u) return isa_helper(u, 'call') end)
functions.def_lua('is.unit',     'var', function(u) return isa_helper(u, 'unit') end)
functions.def_lua('is.symbol',   'var', function(u) return isa_helper(u, 'sym') end)
functions.def_lua('is.integer',  'var', function(u) return isa_helper(u, 'int') end)
functions.def_lua('is.fraction', 'var', function(u) return isa_helper(u, 'frac') end)
functions.def_lua('is.real',     'var', function(u) return isa_helper(u, 'real') end)
functions.def_lua('is.vec',      'var', function(u) return isa_helper(u, 'vec') end)

-- Unit specific functions
functions.def_lua('units.remove',  1, function(u) return units.remove_units(u[1]) or {'int', 1} end)
functions.def_lua('units.extract', 1, function(u) return units.extract_units(u[1]) or {'int', 1} end)

-- Pattern stub functions to prevent argument evaluation
for _, v in ipairs(pattern.pattern_fn) do
  functions.def_lua(v, 'var',  function() end, functions.attribs.hold_all)
end

-- Helper function for calling functions
function functions.call(name, call, arguments, env)
  assert(name)
  assert(arguments and lib.kind(arguments, 'vec'))

  local v = env:get_var(name)
  if not v then return nil end

  if v.lua_fn then
    local ok, res = pcall(v.lua_fn, lib.get_args(arguments) or {}, env)
    if ok then
      return res
    elseif type(res) == 'string' then
      g.error(res)
    end
  elseif v.rules then
    env = Env(env)
    for _, r in ipairs(v.rules) do
      local vars = {}
      if pattern.match(call, r.pattern, vars) then
        return pattern.substitute(r.expr, vars)
      end
    end

    return nil -- No match
  else
    error('Invalid call type')
  end

  return nil
end

return functions
