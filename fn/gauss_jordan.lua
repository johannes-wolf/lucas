local fn = require 'functions'
local lib = require 'lib'
local calc = require 'calc'
local poly = require 'poly'
local dbg = require 'dbg'
local matrix = require 'fn.matrix'

local gauss_jordan = {}

local function S(expr, env)
  local simplify = require 'simplify'
  return simplify.expr(expr, env)
end

local function print_m(ce)
  local output = require 'output'
  for m = 1, lib.num_args(ce) do
    for n = 1, lib.num_args(lib.arg(ce, m)) do
      io.stdout:write(string.format(' %4s ', output.print_alg(lib.arg(lib.arg(ce, m), n))))
    end
    io.stdout:write('\n')
  end
end

local function find_nonzero_column(ce, cm)
  for m = cm, lib.num_args(ce) do
    for n = 1, lib.num_args(lib.arg(ce, m)) do
      local v = lib.arg(lib.arg(ce, m), n)
      if not calc.is_zero_p(v) then
        return m, n
      end
    end
  end
  return cm
end

local function is_zero_at(ce, m, n)
  return calc.is_zero_p(lib.arg(lib.arg(ce, m), n))
end

local function swap_rows(ce, m1, m2)
  m1 = lib.arg(ce, m1)
  m2 = lib.arg(ce, m2)
  for i = lib.arg_offset(m1), lib.num_args(m1) do
    m1[i], m2[i] = m2[i], m1[i]
  end
end

local function swap_if_zero(ce, zm, n)
  if is_zero_at(ce, 1, n) then
    for m = 1, lib.num_args(ce) do
      if m ~= zm then
        if not is_zero_at(ce, m, n) then
          return swap_rows(ce, 1, m)
        end
      end
    end
  end
end

local function divide_row(mat, m, n, env)
  local factor = lib.arg(lib.arg(mat, m), n)

  lib.transform(lib.arg(mat, m), function(v)
    return S({'/', v, factor}, env)
  end)
end

local function substract_other_rows(mat, m, n, dir, env)
  dir = (dir == 'down' and 1) or -1
  local stop = (dir > 0 and lib.num_args(mat)) or 1

  for i = m + dir, stop, dir do
    local factor = lib.arg(lib.arg(mat, i), n)

    lib.transformi(lib.arg(mat, i), function(c, v)
      return S({ '-', v, { '*', factor, lib.arg(lib.arg(mat, m), c) } }, env)
    end)
  end
end


function gauss_jordan.solve(mat, env)
  mat = lib.expect_kind(mat, 'vec')

  local mat_m = lib.num_args(mat)
  if mat_m < 1 then
    return mat
  end

  local mat_n = lib.num_args(lib.arg(mat, 1))
  if mat_n ~= mat_m + 1 then
    return mat
  end

  for m = 1, mat_m do
    -- Find leftmost column which is not 0
    local n
    m, n = find_nonzero_column(mat, m)
    if n then
      -- Swap row, if coeff at m[1] = 0
      swap_if_zero(mat, m, n)

      -- Divide first row by column n
      divide_row(mat, m, n, env)

      -- Substract multiple of m[1] from m[1+n]
      substract_other_rows(mat, m, n, 'down', env)
    end
  end

  -- Matrix is now in in form
  -- 1 n n|n
  -- 0 1 n|n
  -- 0 0 1|n

  for c = mat_m, 2, -1 do
    substract_other_rows(mat, c, c, 'up', env)
  end

  return mat
end


fn.def_lua('gauss_jordan', {{name = 'matrix'}},
function (a, env)
  return gauss_jordan.solve(a.matrix, env)
end)

return gauss_jordan
