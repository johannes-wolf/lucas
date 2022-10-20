local lib = require 'lib'

local units = { table = {} }

local function pow10(n)
  return {'^', {'int', 10}, {'int', n}}
end

local function of_base(u, b)
  if type(u) == 'table' then
    return {'*', u, {'unit', b}}
  elseif type(u) == 'number' then
    return {'*', {'int', u}, {'unit', b}}
  end
  return {'unit', b}
end

local si_prefix = {
  y = {pow10(-24), 'Yocto'},
  z = {pow10(-21), 'Zepto'},
  a = {pow10(-18), 'Atto'},
  f = {pow10(-15), 'Femto'},
  p = {pow10(-12), 'Pico'},
  n = {pow10(-9),  'Nano'},
  u = {pow10(-6),  'Micro'},
  m = {pow10(-3),  'Milli'},
  c = {pow10(-2),  'Centi'},
  d = {pow10(-1),  'Deci'},
  -- 1
  D = {pow10(1),   'Deka'},
  h = {pow10(2),   'Hekto'},
  H = {pow10(2),   'Hekto'},
  k = {pow10(3),   'Kilo'},
  K = {pow10(3),   'Kilo'},
  M = {pow10(6),   'Mega'},
  G = {pow10(9),   'Giga'},
  T = {pow10(12),  'Terra'},
  P = {pow10(15),  'Peta'},
  E = {pow10(18),  'Exa'},
  Z = {pow10(21),  'Zetta'},
  Y = {pow10(24),  'Yotta'},
}

function units.def_unit(sym, name, val, base)
  units.table[sym] = {
    name = name,
    value = val,
    base = base,
  }
end

function units.def_si_unit(sym, name, val)
  units.def_unit(sym, name, val)
  for p, f in pairs(si_prefix) do
    units.def_unit(p..sym, f[2]..name, of_base(f[1], sym), sym)
  end
end

-- Time
units.def_si_unit('s', 'Second')
units.def_unit('min',  'Minute', '60 _s',        's')
units.def_unit('hour', 'Hour',   '60 60 _s',     's')
units.def_unit('day',  'Day',    '24 60 60 _s',  's')

-- Length
units.def_si_unit('m', 'Metre')
units.def_unit('in',   'Inch',   '25400 _um', 'm')

-- Mass
units.def_si_unit('g', 'Gramm')

-- Electric Current
units.def_si_unit('A',   'Ampere')
units.def_si_unit('V',   'Volts', '(_kg _m^2) / (_A _s^3)')
units.def_si_unit('ohm', 'Ohm',   '_V / _A')

-- Thermodynamic Temperature
units.def_si_unit('K', 'Kelvin')

-- Amount of Substance
units.def_si_unit('mol', 'Mol')

-- Luminous Intensity
units.def_si_unit('cd', 'Candela')

-- Volume
units.def_si_unit('l', 'Litre', '_dm^3')

-- Angles
units.def_unit('rad', 'Radians')
units.def_unit('deg', 'Degree',   '(pi _rad) / 180', 'rad')
units.def_unit('gon', 'Gradians', '(pi _rad) / 200', 'rad')
units.def_unit('tr',  'Turn',     '2 pi _rad',       'rad')


-- Compiles all registered (not yet compiled) units
function units.compile()
  local input = require 'input'
  local simplify = require 'simplify'

  for _, u in pairs(units.table) do
    if type(u.value) == 'string' then
      u.value = simplify.expr(input.read_expression(u.value))
    end
  end

  return units.table
end

-- Extract unit from expression u or nil
---@param u table     Expression
---@return table|nil  Unit expression
function units.extract_units(u)
  if lib.is_const(u) or lib.kind(u, 'fn', 'sym') then
    return nil
  elseif lib.kind(u, 'unit') then
    return u
  elseif lib.kind(u, '^') then
    local b = units.extract_units(lib.arg(u, 1))
    if b and #b then
      return {'^', b, units.extract_units(lib.arg(u, 2))}
    end
  else
    return lib.map(u, units.extract_units)
  end
end

-- Remove unit from expression u or nil
---@param u table     Expression
---@return table|nil  Unitless expression
function units.remove_units(u)
  if lib.kind(u, 'unit') then
    return nil
  elseif lib.kind(u, '^') then
    local b = units.remove_units(lib.arg(u, 1))
    if b and #b then
      return {'^', b, units.remove_units(lib.arg(u, 2))}
    end
  else
    return lib.map(u, units.remove_units)
  end
end

return units
