local lexer = require 'lexer'
local parser = require 'parser'

local cmath = require 'cmath'
local fraction = require 'fraction'

local dump_sexp;

local function dump_fraction(f)
  return fraction.to_string(f)
end

local function dump_int(d)
  return string.format('%d', d[2])
end

local function dump_float(f)
  return string.format('%f', f[2])
end

local function dump_id(i)
  local s = i[2] or ''
  if i[4] and not (i[4][1] == 'int' and i[4][2] == 1) then
    s = string.format('(^ %s %s)', s, dump_sexp(i[4]))
  end
  if i[3] and not (i[3][1] == 'int' and i[3][2] == 1) then
    s = string.format('(* %s %s)', dump_sexp(i[3]), s)
  end
  return s
end

local function exp_compare(a, b)
  if a == b then return true end
  if type(a) == 'table' and type(b) == 'table' then
    if #a ~= #b then return false end
    for i = 1, #a do
      if not exp_compare(a[i], b[i]) then
        return false
      end
    end
    return true
  end
end

dump_sexp = function(root)
  if type(root) == 'table' then
    local t = root[1]
    if t == 'float' then return dump_float(root) end
    if t == 'frac' then return dump_fraction(root) end
    if t == 'int' then return dump_int(root) end
    if t == 'id' then return dump_id(root) end

    local s = '(' .. root[1]
    if #root > 1 then
      for sub = 2, #root do
        s = s .. ' ' .. dump_sexp(root[sub])
      end
    end
    return s .. ')'
  else
    return tostring(root)
  end
end

local function num_int(e)
  if not e then return nil end
  if e[1] == 'int' then
    return e[2]
  end
end

local function num_fraction(e)
  return fraction.safe_get(e)
end

local function num_float(e)
  if not e then return nil end
  if e[1] == 'float' then
    return e[2]
  end
end

local function is_sym(e)
  return e and e[1] == 'id'
end

local function get_sym(e)
  if not e then return nil end
  if e[1] == 'id' then
    return {e[2], coef = e[3], exp = e[4]}
  end
end

local function make_int(n)
  return {'int', tonumber(n)}
end

local function make_float(n)
  if type(n) == 'table' then
    if n[1] == 'frac' then
      return make_float(n[2] / n[3])
    end
    if n[1] == 'int' then
      return make_float(n[2])
    end
    if n[1] == 'float' then
      return make_float(n[2])
    end
    assert('Invalid type for make_float!')
  elseif math.floor(n) == n then
    return make_int(n)
  end

  return {'float', n}
end

-- Multiply fraction fs num and denum with integer n
local function scaled_fraction(f, n)
  return {'frac', f[2]*n, f[3]*n}
end

-- Returns a normalize fraction of f
local function normalize_fraction(f)
  return fraction.make(f[2], f[3])
end

-- Build two fractions a and b having an equal denum
local function compat_fractions(a, b)
  return scaled_fraction(a, b[3]), scaled_fraction(b, a[3])
end

local function num_compare(a, b)
  assert(type(a) == 'table')

  if type(b) == 'table' then
    if a[1] == b[1] then
      return exp_compare(a, b)
    end
    return num_compare(make_float(a), make_float(b))
  end

  return num_compare(a, make_float(b))
end

local function make_id(id, coef, expo)
  if num_compare(expo, 0) then
    --return make_float(coef)
  end
  if num_compare(coef, 0) then
    --return make_int(0)
  end
  if not type(coef) == 'table' then
    coef = make_int(1)
  end
  if not type(expo) == 'table' then
    expo = make_int(1)
  end
  return {'id', id, coef, expo}
end

local function is_any(exp, ...)
  for _, k in ipairs(table.pack(...)) do
    if exp[1] == k then return true end
  end
end

local function math_negate(exp)
  if type(exp) == 'table' then
    local t = exp[1]
    if t == 'int' then
      return {'int', -1 * exp[2]}
    elseif t == 'float' then
      return {'float', -1 * exp[2]}
    elseif t == 'frac' then
      return {'frac', -1 * exp[2], exp[3]}
    elseif t == 'id' then
      return {'id', exp[2], math_negate(exp[3]), exp[4]}
    end
  end

  error('Could not negate value of type ~= table')
  return {'neg', exp}
end

local expr_calc;
local math_add;

-- Calculate operator with given arguments
---@param operation string  Operator name
local function math_do(operation, ...)
  return expr_calc({operation, ...})
end

-- Same as math do, but return int result or nil
local function math_do_int(operation, ...)
  return num_int(math_do(operation, ...))
end

-- Expands simplified sum
local function math_desimplify_sum(exp)
  assert(is_any(exp, '+'))

  local n = #exp - 1
  local function append_sum(i)
    if i < n then
      local a, b = exp[i + 1], append_sum(i + 1)
      --if math_do_int('<', b, make_int(0)) ~= 0 then
      --  return {'-', a, math_negate(b)}
      --else
        return {'+', a, b}
      --end
    else
      return exp[i + 1]
    end
  end

  return append_sum(1)
end

local function math_simplify_order_fn(a, b)
  if is_any(a, 'id') then
    if is_any(b, 'id') then
      if a[2] == b[2] then
        return math_do_int('<', a[4], b[4]) ~= 0
      end
      return a[2] < b[2]
    end
    return true
  elseif is_any(b, 'id') then
    return false
  end
  return false
end

local function math_simplify_add(exp)
  local ops = {}

  -- Recursive flatten nested sums/differences to one sum
  local function simplify_add_recurse(e)
    for i = 2, #e do
      local k = e[i][1]
      if k == '+' or k == '-' then
        simplify_add_recurse(e[i])
      else
        table.insert(ops, (e[1] == '-' and i > 2)
                     and math_negate(expr_calc(e[i]))
                     or expr_calc(e[i]))
      end
    end
  end

  simplify_add_recurse(exp)
  table.sort(ops, math_simplify_order_fn)

  local res = {ops[1]}
  while #ops > 1 do
    local r = math_add(res[#res], table.remove(ops, 2))
    if is_any(r, '+') then
      table.insert(res, r[2])
      res[#res] = r[3]
    else
      res[#res] = r
    end
  end

  if #res > 1 then
    return math_desimplify_sum{'+', table.unpack(res)}
  end

  return res[1]
end

local function math_discard_op(exp, op)
  if exp[1] ~= op then
    return exp
  end
end

math_add = function(left, right)
  do
    local l, r = num_int(left), num_int(right)
    if l and r then
      return make_int(l + r)
    end

    local fl, fr = num_fraction(left), num_fraction(right)
    if fl and fr then
      return fraction.add(fl, fr)
    elseif fl and r then
      return fraction.add(fl, r)
    elseif fr and l then
      return fraction.add(l, fr)
    end

    -- EXPERIMENT: Symbolic
    if is_sym(left) and is_sym(right) then
      if left[2] == right[2] then -- Same symbol
        if exp_compare(left[4], right[4]) then -- Same exponent
          return make_id(left[2], math_add(left[3], right[3]), left[4])
        end
      end
    end
  end

  if not is_any(left, '+') then
    if is_any(right, '+') then
      local r = math_discard_op(math_add(left, right[2]), '+')
      if r then
        return math_add(r, right[3])
      end
      r = math_discard_op(math_add(left, right[3]), '+')
      if r then
        return math_add(r, right[2])
      end
    end
  end

  return {'+', left, right}
end

local function math_mul(left, right)
  do
    local l, r = num_int(left), num_int(right)
    if l and r then
      return make_int(l * r)
    end

    local fl, fr = num_fraction(left), num_fraction(right)
    if fl and fr then
      return fraction.mul(fl, fr)
    elseif fl and r then
      return fraction.mul(fl, r)
    elseif fr and l then
      return fraction.mul(l, fr)
    end

    -- EXPERIMENT: Symbolic
    if is_sym(left) and is_sym(right) then
      if left[2] == right[2] then -- Same symbol
        return make_id(left[2], math_mul(left[3], right[3]), math_add(left[4], right[4]))
      end
    elseif is_sym(left) then
      return make_id(left[2], math_mul(left[3], right), left[4])
    elseif is_sym(right) then
      return make_id(right[2], math_mul(right[3], left), right[4])
    end
  end

  -- TODO: Solve nested * (and /)

  return {'*', left, right}
end

local function math_sub(left, right)
  return math_add(left, math_mul(make_int(-1), right))
end

local function math_div(left, right)
  do
    local l, r = num_float(left), num_float(right)
    if l or r then
      return make_float(make_float(left)[1] / make_float(right)[2])
    end
  end

  do
    local l, r = num_int(left), num_int(right)
    if l and r then
      if r == 1 then
        return make_int(l)
      end
      return fraction.make(l, r)
    end

    local fl, fr = num_fraction(left), num_fraction(right)
    if fl and fr then
      return fraction.div(fl, fr)
    elseif fl and r then
      return fraction.div(fl, r)
    elseif fr and l then
      return fraction.div(l, fr)
    end

    -- EXPERIMENT: Symbolic
    if is_sym(left) and is_sym(right) then
      if left[2] == right[2] then -- Same base
        return make_id(left[2], math_div(left[3], right[3]), math_sub(left[4], right[4]))
      end
    elseif is_sym(left) then
      return make_id(left[2], math_div(left[3], right), left[4])
    elseif is_sym(right) then
      return make_id(right[2], math_div(right[3], left), right[4])
    end
  end

  return {'/', left, right}
end

local function math_pow(left, right)
  local il, ir = num_int(left), num_int(right)
  if il and ir then
    return make_int(il ^ ir)
  end

  return {'^', left, right}
end

local function math_equal(left, right)
  if is_sym(left) and is_sym(right) then
    local ls = get_sym(left)
    local rs = get_sym(right)

    return {'int', math_do_int('=', ls.coef, rs.coef) ~= 0 and
                   math_do_int('=', ls.exp, rs.exp) ~= 0 and
                   ls[1] == rs[1] and 1 or 0}
  end

  if is_sym(left) then
    local ls = get_sym(left)
    if (math_do_int('=', ls.coef, make_int(0)) ~= 0) then
      left = make_int(0)
    elseif (math_do_int('=', ls.exp, make_int(0)) ~= 0) then
      left = math_do('*', ls.coef, make_int(1))
    end
  end

  if is_sym(right) then
    local rs = get_sym(right)
    if (math_do_int('=', rs.coef, make_int(0)) ~= 0) then
      right = make_int(0)
    elseif (math_do_int('=', rs.exp, make_int(0)) ~= 0) then
      right = math_do('*', rs.coef, make_int(1))
    end
  end

  local l, r = num_int(left), num_int(right)
  if l and r then
    return {'int', l == r and 1 or 0}
  end

  local lf, rf = num_fraction(left), num_fraction(right)
  if not lf and l then lf = fraction.make(l, 1) end
  if not rf and r then rf = fraction.make(r, 1) end
  if lf and rf then
    lf, rf = compat_fractions(lf, rf)
    return {'int', lf[2] == rf[2] and 1 or 0}
  end

  return {'=', left, right}
end

local function math_less_than(left, right)
  if is_sym(left) and is_sym(right) then
    local ls = get_sym(left)
    local rs = get_sym(right)
    return {'int', math_do_int('<', math_do('^', ls.coef, ls.exp), math_do('^', rs.coef, rs.exp)) ~= 0 and
                   ls[1] == rs[1] and 1 or 0}
  end

  -- TODO: This is wrong! We have to take possible sym value into account (exp=0 or coeff=0 is ok, though)
  if is_sym(left) then
    local ls = get_sym(left)
    left = math_do('^', ls.coef, ls.exp)
  end

  if is_sym(right) then
    local rs = get_sym(right)
    right = math_do('^', rs.coef, rs.exp)
  end

  local l, r = num_int(left), num_int(right)
  if l and r then
    return {'int', l < r and 1 or 0}
  end

  local lf, rf = num_fraction(left), num_fraction(right)
  if not lf and l then lf = fraction.make(l, 1) end
  if not rf and r then rf = fraction.make(r, 1) end
  if lf and rf then
    lf, rf = compat_fractions(lf, rf)
    return {'int', lf[2] < rf[2] and 1 or 0}
  end

  return {'<', left, right}
end

expr_calc = function(e)
  if type(e) == 'table' then
    local o = e[1]
    if o == '+' then
      return math_simplify_add(e)
    elseif o == '-' then
      return math_simplify_add(e) --math_sub(expr_calc(e[2]), expr_calc(e[3]))
    elseif o == 'neg' then
      return math_negate(expr_calc(e[2]))
    elseif o == '*' then
      return math_mul(expr_calc(e[2]), expr_calc(e[3]))
    elseif o == '/' then
      return math_div(expr_calc(e[2]), expr_calc(e[3]))
    elseif o == '^' then
      return math_pow(expr_calc(e[2]), expr_calc(e[3]))
    elseif o == '<' then
      return math_less_than(expr_calc(e[2]), expr_calc(e[3]))
    elseif o == '=' then
      return math_equal(expr_calc(e[2]), expr_calc(e[3]))
    else
      return e
    end
  end
end

while true do
  local line = io.read('l')
  local tokens = lexer.lex(line)

  local parselets = {
    ['id'] = {
      prefix = function(p, token)
        return make_id(token[1], make_int(1), make_int(1))
      end
    },
    ['n'] = {
      prefix = function(p, token)
        local n = token[1]
        if p:match('s', ':') then
          p:consume()
          local n2 = p:expect('n')[1]

          if p:match('s', ':') then
            p:consume()
            local n3 = p:expect('n')[1]

            return fraction.make(n * n3 + n2, n3)
          end

          return fraction.make(n, n2)
        end

        return make_int(n)
      end
    },
    ['('] = {
      prefix = function(p, token)
        local e = p:parse()
        p:expect('s', ')')
        return e
      end
    },
    ['+'] = {
      precedence = 3,
      infix = function(p, left, token)
        return {'+', left, p:parse_precedence(3)}
      end
    },
    ['-'] = {
      precedence = 3,
      prefix = function(p, token)
        return math_negate(p:parse_precedence(4))
      end,
      infix = function(p, left, token)
        return {'-', left, p:parse_precedence(3)}
      end
    },
    ['*'] = {
      precedence = 4,
      infix = function(p, left, token)
        return {'*', left, p:parse_precedence(4)}
      end
    },
    ['/'] = {
      precedence = 4,
      infix = function(p, left, token)
        return {'/', left, p:parse_precedence(4)}
      end
    },
    ['^'] = {
      precedence = 5,
      infix = function(p, left, token)
        return {'^', left, p:parse_precedence(5)}
      end
    },
    ['<'] = {
      precedence = 1,
      infix = function(p, left, token)
        return {'<', left, p:parse_precedence(1)}
      end
    },
    ['='] = {
      precedence = 1,
      infix = function(p, left, token)
        return {'=', left, p:parse_precedence(1)}
      end
    },
  }

  local e = parser.parse(tokens, parselets)
  print(dump_sexp(e))
  print('= ' .. dump_sexp(expr_calc(e)))
end
