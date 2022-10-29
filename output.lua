local operator = require 'operator'
local units = require 'units'
local lib = require 'lib'
local util = require 'util'

local output = {
  fancy_units = true,
}

local function format_int(i)
  return string.format("%d", i[2])
end

local function format_float(i)
  return string.format("%f", i[2])
end

local function format_frac(f)
  return string.format("%d:%d", f[2], f[3])
end

local function format_sym(s)
  s = lib.safe_sym(s)
  if s == 'ninf' then return '-inf' end
  return s
end

local function format_unit(s)
  if output.fancy_units then
    local sym = units.table[s[2]].fancy
    if sym then
      return sym
    end
  end
  return '_'..tostring(s[2])
end

local function format_bool(s)
  return s[2] and 'true' or 'false'
end

function output.print_alg(u)
  local function print_alg_rec(v, prec)
    if type(v) == 'string' then
      return v
    end

    local k = lib.kind(v)
    if k == 'int' then
      return format_int(v)
    elseif k == 'real' then
      return format_float(v)
    elseif k == 'frac' then
      return format_frac(v)
    elseif k == 'bool' then
      return format_bool(v)
    elseif k == 'sym' then
      return format_sym(v)
    elseif k == 'unit' then
      return format_unit(v)
    elseif k == 'vec' then
      return '{'..table.concat(util.list.map(lib.get_args(v), print_alg_rec), ',')..'}'
    elseif k == 'fn' then
      local a = lib.map(v, print_alg_rec, 0)
      return v[2]..'('..table.concat(a, ', ', 3)..')'
    elseif k == '-' and lib.num_args(v) == 1 then
      return '-'..print_alg_rec(lib.arg(v, 1))
    elseif k == '^' then
      local exp
      if not lib.is_const(lib.arg(v, 2)) then
        exp = '('..print_alg_rec(lib.arg(v, 2), 0)..')'
      else
        exp = print_alg_rec(lib.arg(v, 2))
      end
      return print_alg_rec(lib.arg(v, 1), operator.table['^'].infix.precedence)..'^'..exp
    end

    local o = operator.table[k]
    if not o then
      return 'ERR:'..(k or 'nil')
    end
    local d = o and ((o.infix and 'infix') or (o.prefix and 'prefix') or (o.suffix and 'suffix'))
    local p = (o and o[d].precedence) or 0
    local w = lib.map(v, print_alg_rec, p)
    local s = k == '*' and ' ' or k -- Print ' ' as multiplication
    local r = ''

    if d == 'prefix' then
      r = s
    end
    for i = 2, #w do
      if i > 2 and d == 'infix' then
        if s ~= ' 'then
          r = r..' '..s..' '
        else
          r = r..' '
        end
      end
      r = r..w[i]
    end
    if d == 'suffix' then
      r = r..s
    end

    if p <= (prec or 0) then
      return '('..r..')'
    end
    return r
  end

  return print_alg_rec(u)
end

function output.print_sexp(u)
  local function format_fn(s)
    local r = nil
    for i = 1 + lib.arg_offset(s), #s do
      r = (r and r..' ' or '')..output.print_sexp(s[i])
    end
    return '('..lib.fn(s)..' '..(r or '')..')'
  end

  local k = lib.kind(u)
  if k == 'int' then
    return format_int(u)
  elseif k == 'real' then
    return format_float(u)
  elseif k == 'frac' then
    return format_frac(u)
  elseif k == 'bool' then
    return format_bool(u)
  elseif k == 'sym' then
    return format_sym(u)
  elseif k == 'unit' then
    return format_unit(u)
  elseif k == 'fn' then
    return format_fn(u)
  end

  if k then
    local r = k
    for i = 1 + lib.arg_offset(u), #u do
      r = (r and r..' ' or '') .. output.print_sexp(u[i])
    end
    return '(' .. r .. ')'
  end
  return 'ERR'
end

return output
