local lib = require 'lib'
local calc = require 'calc'

local order = {}

function order.lexicographical(u, v)
  return u < v
end

function order.sum_prod(u, v)
  local m, n = lib.num_args(u), lib.num_args(v)
  if m ~= n then
    return order.front(lib.arg(u, m), lib.arg(v, n))
  end

  for j = 0, math.min(m, n) - 2 do -- -2 or -1?
    if not lib.compare(lib.arg(u, m - j), lib.arg(v, n - j)) then
      return order.front(lib.arg(u, m - j), lib.arg(v, n - j))
    end
  end

  local k = math.min(m, n) - 1
  if lib.compare(lib.arg(u, m - k), lib.arg(v, n - k)) then
    return m < n
  end

  return false
end

function order.power(u, v)
  if not lib.compare(calc.base(u), calc.base(v)) then
    return order.front(calc.base(u), calc.base(v))
  else
    return order.front(calc.exponent(u), calc.exponent(v))
  end
end

function order.call(u, v)
  if lib.compare(lib.arg(u, 1), lib.arg(v, 1)) then
    return order.front(lib.arg(u, 1), lib.arg(v, 1))
  else
    local m, n = lib.num_args(lib.arg(u, 2)), lib.num_args(lib.arg(v, 2))

    for j = 2, math.min(m, n) do
      if not lib.compare(lib.call_arg(u, j), lib.call_arg(v, j)) then
        return order.front(lib.call_arg(u, j), lib.call_arg(v, j))
      end
    end

    local k = math.min(m, n)
    if lib.compare(lib.call_arg(u, k), lib.call_arg(v, k)) then
      return m < m
    end
  end
end

function order.front(u, v)
  -- Do not reorder placeholders
  if lib.kind(u, 'tmp') or lib.kind(v, 'tmp') then
    return false
  end

  -- Ordered operands
  local uk, vk = lib.kind(u), lib.kind(v)
  if lib.is_const(u) and lib.is_const(v) then
    return lib.safe_bool(calc.lt(u, v))
  elseif uk == vk then
    if uk == 'sym' then
      return order.lexicographical(lib.sym(u), lib.sym(v))
    elseif uk == 'unit' then
      return order.lexicographical(lib.unit(u), lib.unit(v))
    elseif uk == '*' or uk == '+' then
      return order.sum_prod(u, v)
    elseif uk == '^' then
      return order.power(u, v)
    elseif uk == '!' then
      return order.front(lib.arg(u, 1), lib.arg(v, 1))
    elseif uk == 'call' then
      return order.call(u, v)
    else
      return false
    end
  else
    if lib.is_const(u) and not lib.is_const(v) then
      return true
    elseif uk == '*' and (vk == '^' or vk == '+' or vk == '!' or vk == 'call' or vk == 'sym') then
      return order.front(u, {'*', v})
    elseif uk == '^' and (vk == '+' or vk == '!' or vk == 'call' or vk == 'sym') then
      return order.front(u, {'^', v, calc.ONE})
    elseif uk == '+' and (vk == '!' or vk == 'call' or vk == 'sym') then
      return order.front(u, {'+', v})
    elseif uk == '!' and (vk == 'call' or vk == 'sym') then
      if lib.compare(lib.arg(u, 1), v) then
        return false
      else
        return order.front(u, {'!', v})
      end
    elseif uk == 'call' and (vk == 'sym') then
      if lib.safe_call_sym(u) == lib.sym(v) then
        return false
      else
        return order.lexicographical(lib.safe_call_sym(u) or '', lib.sym(v))
      end
    elseif uk == 'unit' then
      return false
    elseif vk == 'unit' then
      return true
    else
      return not order.front(v, u)
    end
  end
  error('unreachable')
end

-- Call order.front reversed
function order.reversed(u, v)
  return order.front(v, u)
end

function order.full(u, v)
  local uk, vk = lib.kind(u), lib.kind(v)

  if uk == vk then
    if uk == 'tmp' then
      return order.lexicographical(u, v)
    end
  else

  end

  return order.front(u, v)
end

return order
