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

function units.def_unit(sym, name, val)
  units.table[sym] = {
    name = name,
    value = val,
  }
end

function units.def_si_unit(sym, name, val)
  units.def_unit(sym, name, val)
  for p, f in pairs(si_prefix) do
    units.def_unit(p..sym, f[2]..name, of_base(f[1], sym))
  end
end

-- Time
units.def_si_unit('s', 'Second')
units.def_unit('min',  'Minute', of_base(60, 's'))
units.def_unit('hour', 'Hour',   of_base(60, 'min'))
units.def_unit('day',  'Day',    of_base(24, 'hour'))

-- Length
units.def_si_unit('m', 'Metre')
units.def_unit('in',   'Inch',   of_base(25400, 'um'))

-- Mass
units.def_si_unit('g', 'Gramm')

-- Electric Current
units.def_si_unit('A',   'Ampere')
units.def_si_unit('V',   'Volts')
units.def_si_unit('ohm', 'Ohm', {'/', {'unit', 'V'}, {'unit', 'A'}})

-- Thermodynamic Temperature
units.def_si_unit('K', 'Kelvin')

-- Amount of Substance
units.def_si_unit('mol', 'Mol')

-- Luminous Intensity
units.def_si_unit('cd', 'Candela')

-- Volume
units.def_si_unit('l', 'Litre', {'^', {'unit', 'dm'}, {'int', 3}})

-- Angles
units.def_unit('rad', 'Radians')
units.def_unit('deg', 'Degree',   of_base({'/', {'sym', 'pi'}, {'int', 180}}, 'rad'))
units.def_unit('gon', 'Gradians', of_base({'/', {'sym', 'pi'}, {'int', 200}}, 'rad'))
units.def_unit('tr',  'Turn',     of_base({'*', {'sym', 'pi'}, {'int', 2}}, 'rad'))

return units
