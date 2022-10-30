local lib = require 'lib'
local units = require 'units'
local calc = require 'calc'
local pattern = require 'pattern'
local algo = require 'algorithm'
local util = require 'util'
local Env = require 'env'
local dbg = require 'dbg'
local g = require 'global'

local functions = { table = {} }

---@enum
functions.attribs = {
  plain    = 'plain',
  no_units = 'no_units',
}

functions.match = {
  if_sym       = function(v) return lib.kind(v, 'sym') end,
  if_unit      = function(v) return lib.kind(v, 'unit') end,
  if_const     = function(v) return lib.is_const(v) end,
  if_container = function(v) return lib.is_container(v) end,
  if_natnum0   = function(v) return calc.is_natnum_p(v, true) end,
  if_natnum1   = function(v) return calc.is_natnum_p(v, false) end,
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
        g.error(string.format('%s: Invalid argument count %d', args))
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

  functions.table[name] = {
    fn = new_fn,
    attribs = {...},
  }
end

-- Define function that gets arguments passed unevaluated
function functions.def_lua_symb(name, arg_mode, fn)
  functions.def_lua(name, arg_mode, fn, 'plain')
end

functions.def_lua('approx', 1, function(u, env)
  local eval = require 'eval'
  return eval.eval(u[1], Env(env, 'approx'))
end, 'plain')

functions.def_lua('fact', 1, function(u)
  return calc.factorial(u)
end)


-- Debug
functions.def_lua_symb('dbg.trace', 'var',
function (a, env)
  local prev = dbg.trace
  dbg.trace = true
  local eval = require 'eval'
  local r = eval.eval(a[1], env)
  dbg.trace = prev
  return r
end)
functions.def_lua_symb('dbg', 'var', function(args)
  for _, v in ipairs(args) do
    print(dbg.dump(v))
  end
  return {'int', 0}
end)

-- Number
functions.def_lua('sign',  1, function(u)
                    u = u[1]
                    if lib.is_const(u) then
                      return {'int', calc.sign(u)}
                    end
end)
functions.def_lua('num',   1, function(u)
                    u = u[1]
                    if lib.is_const(u) then
                      return {'int', calc.numerator(u)}
                    end
end)
functions.def_lua('denom', 1, function(u) return {'int', calc.denominator(u[1])} end)

-- Type checking functions
local function isa_helper(args, k)
  if not args or #args == 0 then return {'bool', false} end
  for _, v in ipairs(args) do
    if not lib.kind(v, k) then return {'bool', false} end
  end
  return {'bool', true}
end

functions.def_lua('is.function', 'var', function(u) return isa_helper(u, 'fn') end)
functions.def_lua('is.unit',     'var', function(u) return isa_helper(u, 'unit') end)
functions.def_lua('is.symbol',   'var', function(u) return isa_helper(u, 'sym') end)
functions.def_lua('is.bool',     'var', function(u) return isa_helper(u, 'bool') end)
functions.def_lua('is.integer',  'var', function(u) return isa_helper(u, 'int') end)
functions.def_lua('is.fraction', 'var', function(u) return isa_helper(u, 'frac') end)
functions.def_lua('is.real',     'var', function(u) return isa_helper(u, 'real') end)
functions.def_lua('is.vec',      'var', function(u) return isa_helper(u, 'vec') end)

-- Unit specific functions
functions.def_lua('units.remove',  1, function(u) return units.remove_units(u[1]) or {'int', 1} end)
functions.def_lua('units.extract', 1, function(u) return units.extract_units(u[1]) or {'int', 1} end)

-- Pattern stub functions to prevent argument evaluation
for _, v in ipairs(pattern.pattern_fn) do
  functions.def_lua(v, 'var',  function() end, 'plain')
end


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

function functions.get_attrib(call, name, env)
  local f = env:get_fn(lib.safe_fn(call))
  return f and util.set.contains(f.attribs or {}, name)
end

function functions.call(call, env)
  assert(lib.kind(call, 'fn'))

  local eval = require 'eval'

  local name = lib.fn(call)
  assert(name)

  local f = env:get_fn(name)
  if f then
    if functions.get_attrib(f, functions.attribs.no_units, env) then
      call = units.remove_units(call)
    end

    if f.rules then
      -- CAS function
      for _, ov in ipairs(f.rules) do
        local ok, match = pattern.match(call, ov.pattern)
        if ok then
          local sfn = pattern.substitute(ov.replacement, match)
          return eval.eval(sfn, env)
        end
      end
    end

    if f.fn then
      -- Lua based function
      return f.fn(lib.get_args(call) or {}, env)
    end
  end
  return nil
end

return functions
