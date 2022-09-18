local cmath = {}

function cmath.is_zero(a)
  return a == 0
end

function cmath.is_neg(a)
  return a < 0
end

function cmath.neg(a)
  return -1 * a
end

function cmath.add(a, b)
  return a + b
end

function cmath.sub(a, b)
  return a - b
end

function cmath.mul(a, b)
  return a * b
end

function cmath.div(a, b)
  return a / b
end

function cmath.pow(a, b)
  return a ^ b
end

function cmath.mod(a, b)
  return a % b
end

function cmath.gcd(a, b)
  return cmath.is_zero(b) and a or cmath.gcd(b, cmath.mod(a, b))
end

return cmath
