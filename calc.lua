local fraction = require 'fraction'
local dbg = require 'dbg'
local lib = require 'lib'

---@alias Int  table
---@alias Frac table
---@alias Real table

local real = {}

-- Make real
---@param n number
---@return  Real
function real.make(n)
  return {'real', n}
end

local calc = {}
calc.NAN     = {'sym', 'nan'}
calc.INF     = {'sym', 'inf'}
calc.NEG_INF = {'sym', 'ninf'}
calc.ZERO    = {'int', 0}
calc.ONE     = {'int', 1}
calc.NEG_ONE = {'int', -1}
calc.TRUE    = {'bool', true}
calc.FALSE   = {'bool', false}

-- Returns the number of digits of integer n
---@param n number  Integer
---@return  number  Number of digits
local function num_digits(n)
  if n == 0 then
    return 0
  elseif n < 0 then
    n = -n
  end
  if n >= 100 then
    local bin_digits = math.log(n, 2)
    local d = math.floor(bin_digits / math.log(10, 2))
    local b = 10^d
    if b > n then
      return d
    elseif 10 * b > n then
      return d + 1
    else
      return d + 2
    end
  elseif n >= 10 then
    return 2
  else
    return 1
  end
end

local function is_int_i(n)
  return n == math.floor(n)
end

function calc.negate_symbolic(n)
  if lib.kind(n, 'unit') then return n end
  local s = lib.safe_sym(n)
  if s == 'inf' then
    return {'sym', 'ninf'}
  elseif s == 'ninf' then
    return {'sym', 'inf'}
  elseif s == 'nan' then
    return {'sym', 'nan'}
  end
  return {'*', {'int', -1}, n}
end

function calc.negate(n)
  local k = lib.kind(n)
  if k == 'int' then
    return {'int', -n[2]}
  elseif k == 'frac' then
    return {k, -n[2], n[3]}
  elseif k == 'real' then
    return {'real', -n[2]}
  elseif k == 'vec' then
    return lib.map(n, calc.negate)
  end
  return calc.negate_symbolic(n)
end

function calc.floor(n)
  if lib.kind(n, 'int') then
    return n
  elseif lib.kind(n, 'bool') then
    return {'int', n[2] == true}
  elseif lib.kind(n, 'real') then
    return {'int', math.floor(n[2])}
  elseif lib.kind(n, 'frac') then
    return {'int', math.floor(n[2] / n[3])}
  else
    return lib.map(n, calc.ceil)
  end
end

function calc.ceil(n)
  if lib.kind(n, 'int') then
    return n
  elseif lib.kind(n, 'bool') then
    return {'int', n[2] == true}
  elseif lib.kind(n, 'real') then
    return {'int', math.ceil(n[2])}
  elseif lib.kind(n, 'frac') then
    return {'int', math.ceil(n[2] / n[3])}
  else
    return lib.map(n, calc.ceil)
  end
end

function calc.integer(n)
  return calc.floor(n)
end

function calc.real_symbolic(n)
  if lib.kind(n, 'unit') then return n end
  return {'fn', 'real', n}
end

function calc.real(n)
  local k = lib.kind(n)
  if k == 'int' then
    return real.make(n[2])
  elseif k == 'frac' then
    return calc.quotient(real.make(n[2]), real.make(n[3]))
  elseif k == 'real' then
    return real.make(n[2])
  elseif k == 'vec' then
    return lib.map(n, calc.real)
  end
  return calc.real_symbolic(n)
end

function calc.normalize_real(n)
  if lib.kind(n, 'real') then
    n = n[2]
    if is_int_i(n) then
      return {'int', n}
    end

    return real.make(n)
  end
  return n
end

-- Return numerator of value n
---@param n any
---@return number
function calc.numerator(n)
  if lib.kind(n, 'int') then
    return n[2]
  elseif lib.kind(n, 'frac') then
    return n[2]
  elseif lib.kind(n, 'bool') then
    return n[2] and 1 or 0
  elseif lib.kind(n, 'real') then
    return n[2]
  end
  error('not implemented')
end

-- Return denominator of value n
---@param n any
---@return number
function calc.denominator(n)
  if lib.kind(n, 'frac') then
    return n[3]
  end
  return 1
end

-- Return the sign of number n
---@param n any
---@return number 1 if positive, -1 if negative or 0 if zero
function calc.sign(n)
  local function int_sign(d)
    return (d > 0 and 1) or (d == 0 and 0) or -1
  end

  if lib.is_const(n) then
    if lib.kind(n, 'int') then
      return int_sign(n[2])
    elseif lib.kind(n, 'frac', 'real') then
      return int_sign(n[2])
    elseif lib.kind(n, 'bool') then
      return (n[2] > 0 and 1) or 0
    else
      error('not implemented')
    end
  else
    return 'undef'
  end
end

-- Returns true if n is zero
function calc.is_zero_p(n)
  return calc.sign(n) == 0
end

-- Returns true if n is positive or negative infinity.
function calc.is_inf_p(n)
  return lib.safe_sym(n) == 'inf' or
         lib.safe_sym(n) == 'ninf'
end

-- Returns true if n is NAN.
function calc.is_nan_p(n)
  return lib.safe_sym(n) == 'nan'
end

-- Returns true if n is a natural number. Returns true for 0 if with_zero is set.
function calc.is_natnum_p(n, with_zero)
  n = lib.safe_int(n)
  if with_zero then
    return n and n >= 0
  else
    return n and n > 0
  end
end

local function make_compat_fractions(a, b)
  if a[3] == b[3] then
    return a, b
  end
  local denom = a[3] * b[3]
  return {'frac', a[2] * b[3], denom},
         {'frac', b[2] * a[3], denom}
end

local function int_to_fraction(a)
  if lib.kind(a, 'int') then
    return {'frac', a[2], 1}
  else
    return a
  end
end

function calc.eq(a, b)
  a = int_to_fraction(a)
  b = int_to_fraction(b)

  if lib.kind(a, 'frac') and
     lib.kind(b, 'frac') then
    return {'bool', a[2] == b[2] and a[3] == b[3]}
  elseif lib.kind(a, 'frac', 'real') and
         lib.kind(b, 'frac', 'real') then
    if lib.kind(a, 'real') then
      b = calc.real(b)
    elseif lib.kind(b, 'real') then
      a = calc.real(a)
    end
    return {'bool', a[2] == b[2] and a[3] == b[3]}
  else
    return 'undef'
  end
end

function calc.neq(a, b)
  return {'bool', not calc.eq(a, b)}
end

function calc.lt(a, b)
  a = int_to_fraction(a)
  b = int_to_fraction(b)

  if lib.kind(a, 'frac') and
     lib.kind(b, 'frac') then
    a, b = make_compat_fractions(a, b)
    return {'bool', a[2] < b[2]}
  else


    return 'undef' -- TODO
  end
end

function calc.lteq(a, b)
  local lt = calc.lt(a, b)
  if not lib.safe_bool(lt) then
    return calc.eq(a, b)
  end
  return lt
end

function calc.gt(a, b)
  a = int_to_fraction(a)
  b = int_to_fraction(b)

  if lib.kind(a, 'frac') and
     lib.kind(b, 'frac') then
    a, b = make_compat_fractions(a, b)
    return {'bool', a[2] > b[2]}
  else
    return 'undef' -- TODO
  end
end

function calc.gteq(a, b)
  local lt = calc.gt(a, b)
  if not lib.safe_bool(lt) then
    return calc.eq(a, b)
  end
  return lt
end

local function sum_fractions(a, b)
  if a[3] == b[3] then
    return fraction.make(a[2] + b[2],
                         a[3])
  end
  return fraction.make(a[2] * b[3] + b[2] * a[3],
                       a[3] * b[3])
end

local function sum_reals(a, b)
  return real.make(a[2] + b[2])
end

function calc.sum(a, b)
  if calc.is_zero_p(a) then return b end
  if calc.is_zero_p(b) then return a end

  a = int_to_fraction(a)
  b = int_to_fraction(b)

  if lib.kind(a, 'frac') and
     lib.kind(b, 'frac') then
    return sum_fractions(a, b)
  elseif lib.kind(a, 'frac', 'real') and
         lib.kind(b, 'frac', 'real') then
    if lib.kind(a, 'real') then
      b = calc.real(b)
    elseif lib.kind(b, 'real') then
      a = calc.real(a)
    end
    return sum_reals(a, b)
  else
    return 'undef'
  end
end

function calc.difference(a, b)
  return calc.sum(a, calc.negate(b))
end

local function mul_fractions(a, b)
  return fraction.make(a[2] * b[2],
                       a[3] * b[3])
end

local function mul_reals(a, b)
  return real.make(a[2] * b[2])
end

function calc.product(a, b)
  if calc.is_zero_p(a) or calc.is_zero_p(b) then
    return {'int', 0}
  end

  a = int_to_fraction(a)
  b = int_to_fraction(b)

  if lib.kind(a, 'frac') and
     lib.kind(b, 'frac') then
    return mul_fractions(a, b)
  elseif lib.kind(a, 'frac', 'real') and
         lib.kind(b, 'frac', 'real') then
    if lib.kind(a, 'real') then
      b = calc.real(b)
    elseif lib.kind(b, 'real') then
      a = calc.real(a)
    end
    return mul_reals(a, b)
  else
    return 'undef'
  end
end

local function div_fractions(a, b)
  if a[2] == b[3] and a[3] == b[2] then
    return {'int', 1}
  end
  return fraction.make(a[2] * b[3],
                       b[2] * a[3])
end

local function div_reals(a, b)
  return real.make(a[2] / b[2])
end

function calc.quotient(a, b)
  if calc.is_zero_p(b) then
    return 'undef'
  elseif calc.is_zero_p(a) then
    return {'int', 0}
  end

  a = int_to_fraction(a)
  b = int_to_fraction(b)

  if lib.kind(a, 'frac') and
     lib.kind(b, 'frac') then
    return div_fractions(a, b)
  elseif lib.kind(a, 'frac', 'real') and
         lib.kind(b, 'frac', 'real') then
    if lib.kind(a, 'real') then
      b = calc.real(b)
    elseif lib.kind(b, 'real') then
      a = calc.real(a)
    end
    return div_reals(a, b)
  else
    return 'undef'
  end
end

function calc.pow_to_zero(a)
  -- TODO: Power to zero
  return {'sym', 'nan'}
end

-- Calc power of two integers a^b
---@param a number  Base
---@param b number  Exponent
function calc.pow_ii(a, b)
  if a ~= 0 then
    if b > 0 then
      local s = calc.pow_ii(a, b - 1)
      return calc.product(s, {'int', a})
    elseif b == 0 then
      return {'int', 1}
    elseif b == -1 then
      return calc.quotient(calc.ONE, {'int', a})
    elseif b < -1 then
      return calc.quotient(calc.ONE, calc.pow_ii(a, -1 * b))
    end
  else
    if b >= 1 then
      return {'int', 0}
    else
      return 'undef'
    end
  end
end

function calc.pow_ff(a, b)
  return real.make(a ^ b)
end

function calc.pow_symbolic(a, b)
  return {'^', a, b}
end

function calc.pow(a, b)
  if calc.is_nan_p(b) then
    return b
  elseif calc.is_inf_p(a) then
    return a
  elseif calc.is_zero_p(a) then
    return calc.pow_to_zero(b)
  elseif lib.safe_bool(calc.eq(a, calc.ONE)) or
         lib.safe_bool(calc.eq(b, calc.ONE)) then
    return a
  elseif calc.is_zero_p(b) then
    return {'int', 1}
  else
    if lib.kind(b, 'int') then
      if lib.kind(a, 'int') then
        return calc.pow_ii(a[2], b[2])
      elseif lib.kind(a, 'frac') then
        return calc.quotient(calc.pow_ii(a[2], b[2]),
                             calc.pow_ii(a[3], b[2]))
      elseif lib.kind(a, 'real') then
        a = calc.real(a)
        b = calc.real(b)
        return calc.pow_ff(a[2], b[2])
      else
        return lib.map(a, calc.pow)
      end
    elseif lib.kind(b, 'frac', 'real') then
      a = calc.real(a)
      b = calc.real(b)
      return calc.pow_ff(a[2], b[2])
    end
  end

  return calc.pow_symbolic(a, b)
end

function calc.factorial_symbolic(u)
  return {'!', u}
end

function calc.factorial(u)
  if calc.is_natnum_p(u, true) then
    local n = lib.safe_int(u)
    local r = 1
    for i = 1, n do
      r = r * i
    end
    return {'int', r}
  elseif lib.is_const(u) then
    return 'undef'
  end

  return calc.factorial_symbolic(u)
end

local function sqrt_ii(n, m)
  n = n ^ (1/m)
  if is_int_i(n) then
    return n
  end
end

function calc.sqrt(u, n, approx_p)
  if not n then
    n = {'int', 2}
  end

  if not calc.is_natnum_p(n, false) then
    return 'undef'
  end

  if lib.kind(u, 'frac') then
    u = int_to_fraction(u)
    return {'/', calc.sqrt({'int', u[2]}, n, approx_p),
                 calc.sqrt({'int', u[3]}, n, approx_p)}
  end

  n = lib.safe_int(n)
  if approx_p then
    if n > 1 then
      return {'^', u, fraction.make(1, n)}
    else
      return u
    end
  elseif lib.kind(u, 'int') then
    local p = sqrt_ii(lib.safe_int(u), n)
    if p then
      return {'int', p}
    end
  end

  if n ~= 2 then
    return {'fn', 'sqrt', u, {'int', n}}
  end
  return {'fn', 'sqrt', u}
end

return calc
