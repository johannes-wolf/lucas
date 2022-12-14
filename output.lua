local operator = require 'operator'
local units = require 'units'
local lib = require 'lib'
local util = require 'util'

local output = {}

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
  return lib.safe_sym(s)
end

local function format_tmp(s)
  s = lib.safe_sym(s)
  if s == '_' or s == '__' then
    return s
  end
  return s..'_'
end

local function format_unit(s)
  return '_'..tostring(s[2])
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
    elseif k == 'sym' then
      return format_sym(v)
    elseif k == 'tmp' then
      return format_tmp(v)
    elseif k == 'unit' then
      return format_unit(v)
    elseif k == 'vec' then
      return '{'..(table.concat(util.list.map(lib.get_args(v) or {}, print_alg_rec), ', ') or 'ERR')..'}'
    elseif k == ';' then
      return table.concat(util.list.map(lib.get_args(v) or {}, print_alg_rec), '; ') or 'ERR'
    elseif k == 'call' then
      return output.print_alg(lib.arg(v, 1))..
        '['..(table.concat(util.list.map(lib.get_args(lib.arg(v, 2)) or {}, print_alg_rec), ', ') or 'ERR')..']'
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
  local k = lib.kind(u)
  if k == 'int' then
    return format_int(u)
  elseif k == 'real' then
    return format_float(u)
  elseif k == 'frac' then
    return format_frac(u)
  elseif k == 'sym' then
    return format_sym(u)
  elseif k == 'tmp' then
    return format_tmp(u)
  elseif k == 'unit' then
    return format_unit(u)
  elseif k == 'call' then
    return output.print_sexp(lib.arg(u, 1))..' '..output.print_sexp(lib.arg(u, 2))
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
