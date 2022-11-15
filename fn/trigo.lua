local fn = require 'functions'
local lib = require 'lib'
local calc = require 'calc'

-- Returns the factor of pi in x, if it exists
---@return number|nil numerator
---@return number|nil denominator
local function pi_fraction(x)
  if calc.is_zero_p(x) then
    return 0, 1
  elseif lib.safe_sym(x) == 'pi' then
    return 1, 1
  elseif lib.kind(x, '*') and lib.num_args(x) == 2 then
    local a, b = lib.arg(x, 1), lib.arg(x, 2)
    if a and lib.is_const(a) and lib.safe_sym(b) == 'pi' then
      local n, d = calc.to_number(a)
      return n, d or 1
    end
  end
  return nil, nil
end

-- Known sine/cosine/tan values
local sin_tab = {
  [0] = {
    [1] = calc.make_int(0),
  },
  [1] = {
    [6] = calc.make_fraction(1, 2),
    [2] = calc.make_int(1),
  }
}
local cos_tab = {
  [0] = {
    [1] = calc.make_int(1),
  },
  [1] = {
    [3] = calc.make_fraction(1, 2),
    [2] = calc.make_int(0),
  }
}
local tan_tab = {
  [0] = {
    [1] = calc.make_int(0),
  },
  [1] = {
    [4] = calc.make_int(1),
    [2] = calc.DIV_ZERO,
  }
}
local cot_tab = {
  [0] = {
    [1] = calc.DIV_ZERO,
  },
  [1] = {
    [4] = calc.make_int(1),
    [2] = calc.make_int(0),
  }
}

local function lookup_dn_tab(num, denom, tab)
  local nt = tab[num]
  if nt then
    return nt[denom]
  end
end

local sin_rad_pi, cos_rad_pi, tan_rad_pi, cot_rad_pi

sin_rad_pi = function(num, denom)
  if calc.is_true_p(calc.gt(calc.make_fraction(num, denom),
                            calc.make_fraction(1, 2))) then
    local o = calc.sum(calc.make_fraction(num, denom),
                       calc.make_fraction(-1, 2))
    return cos_rad_pi(calc.to_number(o))
  end

  if num then
    return lookup_dn_tab(num, denom, sin_tab)
  end

  return calc.make_fn_call('sin', calc.make_fraction(num, denom))
end

cos_rad_pi = function(num, denom)
  if calc.is_true_p(calc.gt(calc.make_fraction(num, denom),
                            calc.make_fraction(1, 2))) then
    local o = calc.sum(calc.make_fraction(num, denom),
                       calc.make_fraction(-1, 2))
    return {'*', calc.NEG_ONE, sin_rad_pi(calc.to_number(o))}
  end

  if num then
    return lookup_dn_tab(num, denom, cos_tab)
  end

  return calc.make_fn_call('cos', calc.make_fraction(num, denom))
end

tan_rad_pi = function(num, denom)
  if calc.is_true_p(calc.gt(calc.make_fraction(num, denom),
                            calc.make_fraction(1, 2))) then
    local o = calc.sum(calc.make_fraction(num, denom),
                       calc.make_fraction(-1, 2))
    return {'*', calc.NEG_ONE, cot_rad_pi(calc.to_number(o))}
  end

  if num then
    return lookup_dn_tab(num, denom, tan_tab)
  end

  return calc.make_fn_call('tan', calc.make_fraction(num, denom))
end

cot_rad_pi = function(num, denom)
  if calc.is_true_p(calc.gt(calc.make_fraction(num, denom),
                            calc.make_fraction(1, 2))) then
    local o = calc.sum(calc.make_fraction(num, denom),
                       calc.make_fraction(-1, 2))
    return {'*', calc.NEG_ONE, tan_rad_pi(calc.to_number(o))}
  end

  if num then
    return lookup_dn_tab(num, denom, cot_tab)
  end

  return calc.make_fn_call('cot', calc.make_fraction(num, denom))
end


local function sin_rad(x, env)
  -- Approx mode
  if env.approx then
    return calc.make_real(math.sin(calc.to_number_f(x) or 0))
  end

  -- Lookup exact values
  local n, d = pi_fraction(x)
  if n then
    return sin_rad_pi(n, d)
  end
end

local function cos_rad(x, env)
  -- Approx mode
  if env.approx then
    return calc.make_real(math.cos(calc.to_number_f(x) or 0))
  end

  -- Lookup exact values
  local n, d = pi_fraction(x)
  if n then
    return cos_rad_pi(n, d)
  end
end

local function tan_rad(x, env)
  -- Approx mode
  if env.approx then
    return calc.make_real(math.tan(calc.to_number_f(x) or 0))
  end

  -- Lookup exact values
  local n, d = pi_fraction(x)
  if n then
    return tan_rad_pi(n, d)
  end
end

local function cot_rad(x, env)
  -- Approx mode
  if env.approx then
    return calc.make_real(math.tan(calc.to_number_f(x) or 0))
  end

  -- Lookup exact values
  local n, d = pi_fraction(x)
  if n then
    return cot_rad_pi(n, d)
  end
end

fn.def_lua('sin', 1,
function (a, env)
  return sin_rad(a[1], env)
end)

fn.def_lua('cos', 1,
function (a, env)
  return cos_rad(a[1], env)
end)

fn.def_lua('tan', 1,
function (a, env)
  return tan_rad(a[1], env)
end)

fn.def_lua('cot', 1,
function (a, env)
  return cot_rad(a[1], env)
end)
