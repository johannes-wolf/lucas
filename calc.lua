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
calc.ZERO  = {'int', 0}
calc.ONE   = {'int', 1}
calc.TRUE  = {'bool', true}
calc.FALSE = {'bool', true}

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

function calc.negate_symbolic(n)
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

function calc.real_symbolic(n)
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

function calc.is_zero(n)
  return calc.sign(n) == 0
end

function calc.is_inf_p(n)
  return lib.safe_sym(n) == 'inf' or
         lib.safe_sym(n) == 'neg_inf'
end

function calc.is_nan_p(n)
  return lib.safe_sym(n) == 'nan'
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
  if calc.is_zero(a) then return b end
  if calc.is_zero(b) then return a end

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
  if a[3] == b[3] then
    return fraction.make(a[2] * b[2],
                         a[3])
  end
  return fraction.make(a[2] * b[2],
                       a[3] * b[3])
end

local function mul_reals(a, b)
  return real.make(a[2] * b[2])
end

function calc.product(a, b)
  if calc.is_zero(a) or calc.is_zero(b) then
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
  if calc.is_zero(b) then
    return 'undef'
  elseif calc.is_zero(a) then
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
      return calc.quotient(ONE, {'int', a})
    elseif b < -1 then
      return calc.quotient(ONE, calc.pow_ii(a, -1 * b))
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
  elseif calc.is_zero(a) then
    return calc.pow_to_zero(b)
  elseif lib.safe_bool(calc.eq(a, ONE)) or
         lib.safe_bool(calc.eq(b, ONE)) then
    return a
  elseif calc.is_zero(b) then
    return {'int', 1}
  else
    if lib.kind(b, 'int') then
      if lib.kind(a, 'int') then
        return calc.pow_ii(a[2], b[2])
      elseif lib.kind(a, 'frac') then
        return fraction.make(lib.safe_int(calc.pow_ii(a[2], b[2])),
                             lib.safe_int(calc.pow_ii(a[3], b[2])))
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

return calc
