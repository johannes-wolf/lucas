local fn = require 'functions'
local lib = require 'lib'
local calc = require 'calc'
local units = require 'units'

local function sin_deg(x, env)
end

local function sin_rad(x, env)
  if env.approx then
    return calc.make_real(math.sin(calc.to_number_f(x)))
  end
end

local function cos_deg(x, env)
end

local function cos_rad(x, env)
  if env.approx then
    return calc.make_real(math.cos(calc.to_number_f(x)))
  end
end

local function dispatch_type(expr, fn_rad, fn_deg, env)
  local u = units.extract_units(a[1])
  local x = units.remove_units(a[1])

  if lib.safe_unit(u) == 'deg' then
    return fn_deg(x, env)
  elseif lib.safe_unit(u) == 'rad' or not u then
    return fn_rad(x, env)
  end
end

fn.def_lua('sin', 1,
function (a, env)
  return dispatch_type(a[1], sin_rad, sin_deg, env)
end)

fn.def_lua('cos', 1,
function (a, env)
  return dispatch_type(a[1], cos_rad, cos_deg, env)
end)
