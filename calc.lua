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
calc.NAN           = {'sym', 'nan'}
calc.INF           = {'sym', 'inf'}
calc.NEG_INF       = {'-', {'sym', 'inf'}}
calc.ZERO          = {'int', 0}
calc.ONE           = {'int', 1}
calc.NEG_ONE       = {'int', -1}
calc.TRUE          = {'bool', true}
calc.FALSE         = {'bool', false}
calc.ZERO_POW_ZERO = calc.ZERO       -- Result for 0^0
calc.DIV_ZERO      = calc.NAN        -- Result for 0^(-n)


function calc.I(n)         return {'int', math.floor(n)} end
function calc.R(n)         return {'real', n} end
function calc.F(n, d)      return fraction.make(n, d) end
function calc.OP(sym, ...) return {sym, ...} end

local function S(expr)
  local simplify = require 'simplify'
  return simplify.expr(expr)
end

-- Returns if u is a function with name fn
---@param u  Expression
---@param fn string
---@return   boolean
local function is_fn_p(u, fn)
  return lib.kind(u, 'fn') and lib.fn(u) == fn
end

-- Returns constant as lua number for internal checks
local function safe_lua_number(n)
  if lib.kind(n, 'bool', 'int', 'real') then
    return n[2]
  elseif lib.kind(n, 'frac') then
    return n[2]/n[3]
  end
  return nil
end

-- Returns true if n is zero
-- Used by many functions: to prevent recursion, this must not call into eq!
function calc.is_zero_p(n)
  if lib.is_const(n) then
    return safe_lua_number(n) == 0
  end
  return false
end

-- Returns true if n is positive or negative infinity.
---@param n Expression
---@param s number      Sign (0) of infiniy to check against
function calc.is_inf_p(n, s)
  s = s or 0
  return (s >= 0 and lib.safe_sym(n) == 'inf') or
         (s <= 0 and calc.is_negative_inf_p(n)) or false
end

function calc.is_negative_inf_p(n)
  do
    local u, v = lib.split_args_if(n, '*', 2)
    if u and v then
      return calc.sign(u) < 0 and lib.safe_sym(v) == 'inf'
    end
  end
  do
    local u = lib.split_args_if(n, '-', 1)
    return lib.safe_sym(u) == 'inf'
  end
  return false
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

-- Returns if n is a rational number
function calc.is_ratnum_p(n)
  return lib.kind(n, 'int', 'frac')
end

-- Returns if a is 'true'
---@param a Expression
---@return  boolean
function calc.is_true_p(a)
  if lib.is_const(a) then
    if lib.kind(a, 'bool') then
      return lib.safe_bool(a)
    else
      return lib.safe_bool(calc.neq(a, calc.ZERO))
    end
  end
  return false
end

local function is_int_i(n)
  return n == math.floor(n)
end

-- GCD
---@param a number
---@param b number
---@return number
function calc.gcd_i(a, b)
  return (b == 0 and a) or calc.gcd_i(b, a % b)
end

-- GCD
---@param a Expression
---@param b Expression
---@return Expression
function calc.gcd(a, b)
  if lib.is_const(a) and lib.is_const(b) then
    if calc.is_zero_p(b) then
      return calc.DIV_ZERO
    end

    local u, v = lib.safe_int(a), lib.safe_int(b)
    if u and v then
      return calc.I(calc.gcd_i(u, v))
    end
  end
  return {'gcd', a, b}
end

function calc.negate_special(n)
  local s = lib.safe_sym(n)
  if s == 'nan' then
    return {'sym', 'nan'}
  end
end

function calc.negate(n)
  local k = lib.kind(n)
  if k == 'int' then
    return {'int', -n[2]}
  elseif k == 'bool' then
    return {'bool', not n[2]}
  elseif k == 'frac' then
    return {k, -n[2], n[3]}
  elseif k == 'real' then
    return {'real', -n[2]}
  elseif k == 'vec' then
    return lib.map(n, calc.negate)
  end
  return calc.negate_special(n) or {'*', calc.NEG_ONE, n}
end

function calc.floor(n)
  if lib.kind(n, 'bool', 'int') then
    return n
  elseif lib.kind(n, 'real') then
    return {'int', math.floor(n[2])}
  elseif lib.kind(n, 'frac') then
    return {'int', math.floor(n[2] / n[3])}
  elseif lib.is_container(n) then
    return lib.map(n, calc.floor)
  else
    return {'fn', 'floor', n}
  end
end

function calc.ceil(n)
  if lib.kind(n, 'bool', 'int') then
    return n
  elseif lib.kind(n, 'real') then
    return {'int', math.ceil(n[2])}
  elseif lib.kind(n, 'frac') then
    return {'int', math.ceil(n[2] / n[3])}
  elseif lib.is_container(n) then
    return lib.map(n, calc.floor)
  else
    return {'fn', 'ceil', n}
  end
end

function calc.integer(n)
  return calc.floor(n)
end

---@return table
function calc.real(n)
  local k = lib.kind(n)
  if k == 'int' then
    return calc.R(n[2])
  elseif k == 'bool' then
    return calc.R(n[2])
  elseif k == 'frac' then
    return calc.real(calc.quotient(real.make(n[2]), real.make(n[3])))
  elseif k == 'real' then
    return n
  elseif lib.is_container(n) then
    return lib.map(n, calc.real)
  end
  return {'fn', 'real', n}
end

function calc.normalize_fraction(n)
  if lib.kind(n, 'frac') then
    return fraction.normalize(n)
  end
  return n
end

function calc.normalize_real(n)
  if lib.kind(n, 'real') then
    n = n[2]
    if is_int_i(n) then
      return calc.I(n)
    end
    return calc.R(n)
  end
  return n
end

function calc.sign_of_sym(factor, sym)
  -- FIXME: Read info out of vars?
  if sym == 'inf' or sym == 'e' or sym == 'pi' then
    return calc.sign(factor)
  end
end

-- Return the sign of number n
---@param n Expression|nil
---@return  number 1 if positive, -1 if negative or 0 if zero
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
  elseif is_fn_p(n, 'abs') then
    return 1
  end

  return 1 -- FIXME: ???
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
  elseif lib.kind(a, 'bool') then
    return {'frac', (a and 1) or 0, 1}
  else
    return a
  end
end

local function vminmax(v, fn)
  if lib.num_args(v) >= 1 then
    local m = lib.arg(v, 1)
    for i = 2, lib.num_args(v) do
      m = fn({m, lib.arg(v, i)})
    end
    return m
  end
  return calc.NAN
end

-- Find min value
---@param v Expression[]
---@return  Expression
function calc.min(v)
  if #v > 0 then
    local m
    for _, n in ipairs(v) do
      if lib.kind(n, 'vec') then
        n = vminmax(n, calc.min)
      end
      if not lib.is_const(n) then return nil end
      if not m or lib.safe_bool(calc.lt(n, m)) then
        m = n
      end
    end
    if not lib.is_const(m) then
      return nil
    end
    return m
  end
  return calc.INF
end

-- Find min value
---@param v Expression[]
---@return  Expression
function calc.max(v)
  if #v > 0 then
    local m
    for _, n in ipairs(v) do
      if lib.kind(n, 'vec') then
        n = vminmax(n, calc.max)
      end
      if not lib.is_const(n) then return nil end
      if not m or lib.safe_bool(calc.gt(n, m))  then
        m = n
      end
    end
    return m
  end
  return calc.NEG_INF
end

local function eq_vector(a, b)
  if lib.num_args(a) ~= lib.num_args(b) or lib.kind(a) ~= lib.kind(b) then
    return calc.FALSE
  end
  for i = 1, math.max(lib.num_args(a), lib.num_args(b)) do
    local r = calc.eq(lib.arg(a, i), lib.arg(b, i))
    if lib.kind(r, 'bool') and not lib.safe_bool(r) then
      return calc.FALSE
    else
      return { '=', a, b }
    end
    return calc.TRUE
  end
end

function calc.eq(a, b)
  do
    local u = int_to_fraction(a)
    local v = int_to_fraction(b)

    if lib.kind(u, 'frac') and
       lib.kind(v, 'frac') then
      return {'bool', u[2] == v[2] and u[3] == v[3]}
    elseif lib.kind(u, 'frac', 'real') and
           lib.kind(v, 'frac', 'real') then
      u = calc.real(u)
      v = calc.real(v)
      return {'bool', u[2] == v[2]}
    elseif lib.is_collection(u) or
          lib.is_collection(v) then
      return eq_vector(u, v)
    end
  end

  if lib.compare(a, b) then
    return calc.TRUE
  end
  return { '=', a, b }
end


function calc.neq(a, b)
  local eq = calc.eq(a, b)
  if lib.kind(eq) ~= '=' then
    return {'bool', not lib.safe_bool(eq)}
  end
  return {'!=', a, b}
end

local function lt_inf(a, b)
  if calc.is_inf_p(a, -1) then
    if calc.is_inf_p(b, -1) then
      return calc.FALSE
    else
      return calc.TRUE
    end
  elseif calc.is_inf_p(b, 1) then
    if calc.is_inf_p(a, 1) then
      return calc.FALSE
    else
      return calc.TRUE
    end
  elseif calc.is_inf_p(a, 1) or calc.is_inf_p(b, -1) then
    return calc.FALSE
  end
end

function calc.lt(a, b)
  local lti = lt_inf(a, b)
  if lti then
    return lti
  end

  local u = int_to_fraction(a)
  local v = int_to_fraction(b)

  if lib.kind(u, 'frac') and
     lib.kind(v, 'frac') then
    u, v = make_compat_fractions(u, v)
    return {'bool', u[2] < v[2]}
  elseif lib.kind(u, 'frac', 'real') and
         lib.kind(v, 'frac', 'real') then
    u = calc.real(u)
    v = calc.real(v)
    return {'bool', u[2] < v[2]}
  end
  if lib.compare(a, b) then
    return calc.FALSE
  end
  return {'<', a, b}
end

function calc.lteq(a, b)
  local lt = calc.lt(a, b)
  if not lib.safe_bool(lt) then
    local eq = calc.eq(a, b)
    if lib.kind(eq) ~= '=' then
      return eq
    end
  end
  if lib.kind(lt) ~= '<' then
    return lt
  end
  return {'<=', a, b}
end

local function gt_inf(a, b)
  if calc.is_inf_p(a, 1) then
    if calc.is_inf_p(b, 1) then
      return calc.FALSE
    else
      return calc.TRUE
    end
  elseif calc.is_inf_p(b, -1) then
    if calc.is_inf_p(a, -1) then
      return calc.FALSE
    else
      return calc.TRUE
    end
  elseif calc.is_inf_p(a, -1) or calc.is_inf_p(b, 1) then
    return calc.FALSE
  end
end

function calc.gt(a, b)
  local gti = gt_inf(a, b)
  if gti then
    return gti
  end

  local u = int_to_fraction(a)
  local v = int_to_fraction(b)

  if lib.kind(a, 'frac') and
     lib.kind(b, 'frac') then
    u, v = make_compat_fractions(u, v)
    return {'bool', u[2] > v[2]}
  elseif lib.kind(u, 'frac', 'real') and
         lib.kind(v, 'frac', 'real') then
    u = calc.real(u)
    v = calc.real(v)
    return {'bool', u[2] > v[2]}
  end
  if lib.compare(a, b) then
    return calc.FALSE
  end
  return {'>', a, b}
end

function calc.gteq(a, b)
  local gt = calc.gt(a, b)
  if not lib.safe_bool(gt) then
    local eq = calc.eq(a, b)
    if lib.kind(eq) ~= '=' then
      return eq
    end
  end
  if lib.kind(gt) ~= '>' then
    return gt
  end
  return {'>=', a, b}
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
  elseif calc.is_inf_p(a, 0) or calc.is_inf_p(b, 0) then
    if calc.sign(a) == calc.sign(b) then
      return a
    else
      return calc.NAN
    end
  end

  return {'+', a, b}
end

function calc.difference(a, b)
  return calc.sum(a, calc.product(calc.NEG_ONE, b))
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
  elseif calc.is_inf_p(a, 0) or calc.is_inf_p(b, 0) then
    if calc.sign(a) == calc.sign(b) then
      return calc.INF
    else
      return calc.NEG_INF
    end
  end

  return {'*', a, b}
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

---@return table
function calc.quotient(a, b)
  if calc.is_zero_p(b) then
    return calc.DIV_ZERO
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
  elseif calc.is_inf_p(a, 0) then
    if calc.is_inf_p(b, 0) then
      return calc.NAN
    else
      return lib.is_const(b) and calc.ZERO or {'/', a, b}
    end
  elseif calc.is_inf_p(a, 0) then
    return calc.ZERO
  end

  return calc.product(a, calc.pow(b, calc.NEG_ONE))
end

function calc.pow_to_zero(a)
  if lib.safe_bool(calc.gt(a, calc.ZERO)) then
    return calc.ZERO
  elseif lib.safe_bool(calc.eq(a, calc.ZERO)) then
    return calc.ZERO_POW_ZERO
  else
    return calc.DIV_ZERO
  end
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
      return calc.NAN
    end
  end
end

function calc.pow_ff(a, b)
  return calc.R(a ^ b)
end

function calc.pow(a, b)
  if calc.is_nan_p(b) then
    return b
  elseif calc.is_inf_p(a, 0) then
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
  return {'^', a, b}
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
    return calc.NAN
  elseif calc.is_inf_p(u, 1) then
    return calc.INF
  elseif calc.is_inf_p(u, -1) then
    return calc.NEG_INF
  end
  return {'!', u}
end

local function sqrt_ii(n, m)
  n = n ^ (1/m)
  if is_int_i(n) then
    return n
  end
end

function calc.sqrt(u, n, approx_p)
  if not n then
    n = calc.I(2)
  end

  if calc.is_inf_p(u, 1) then
    return calc.INF
  elseif not calc.is_natnum_p(n, false) then
    return calc.NAN
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

function calc.ln(x)
  if lib.kind(x, 'int', 'frac', 'float') then
    return {'real', math.log(calc.real(x)[2])}
  end
  return {'fn', 'ln', x}
end

function calc.log(x, b)
  if not b or lib.safe_sym(b) == 'e' then
    return calc.ln(x)
  elseif calc.is_inf_p(x, 0) then
    return calc.INF
  end

  if lib.kind(x, 'int', 'frac', 'float') then
    return {'real', math.log(calc.real(x)[2], calc.real(b)[2])}
  end

  return {'fn', 'log', x, b}
end

function calc.exp(x, approx_p)
  if calc.is_zero_p(x) then
    return calc.ONE
  elseif calc.is_inf_p(x, 0) then
    return calc.INF
  end

  if approx_p then
    return {'real', math.exp(calc.real(x)[2])}
  end
  return {'fn', 'exp', x}
end

function calc.abs(u)
  if lib.is_const(u) then
    if calc.sign(u) < 0 then
      return calc.negate(u)
    end
  elseif calc.is_inf_p(u, 0) then
    return calc.INF
  elseif is_fn_p(u, 'abs') then
    return u
  end
end

function calc.bool(a)
  if lib.is_const(a) then
    return {'bool', calc.is_true_p(a)}
  elseif calc.is_inf_p(a, 0) then
    return calc.INF
  else
    return {'fn', 'bool', a}
  end
end

function calc.land(a, b)
  if calc.is_true_p(a) and calc.is_true_p(b) then
    return b
  elseif lib.is_const(a) and lib.is_const(b) then
    if calc.is_true_p(a) then
      return b
    else
      return a
    end
  end
  return {'and', a, b}
end

function calc.lor(a, b)
  if calc.is_true_p(a) then
    return a
  elseif calc.is_true_p(b) then
    return b
  elseif lib.is_const(a) and lib.is_const(b) then
    return b
  end
  return {'or', a, b}
end

-- Logical not
function calc.lnot(a)
  if lib.is_const(a) then
    return {'bool', not calc.is_true_p(a)}
  end
  if is_fn_p(a, 'not') then
    return lib.arg(a, 1)
  end
  return {'not', a}
end

return calc
