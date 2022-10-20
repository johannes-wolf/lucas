local lib = require 'lib'
local eval = require 'eval'
local util = require 'util'
local output = require 'output'

local rewrite = {}

-- Find subexrpression w in exrpession v
---@param v table                Source expression
---@param w table                Search expression
---@param mode 'root'|'recurse'  Recursion mode. Defaults to 'root'
---@return table
function rewrite.match_subexpr(v, w, mode)
  mode = mode or 'root'

  local function compare_head(a, b)
    if lib.kind(a) ~= lib.kind(b) then
      return false
    end

    if lib.is_const(a) and lib.is_const(b) then
      return eval.eq(a, b)
    end

    local x, y = lib.arg_offset(a), lib.arg_offset(b)
    if x ~= y then
      return false
    end

    for i = 2, x do
      if a[i] ~= b[i] then
        return false
      end
    end

    return true
  end

  local function find_subexpr_rec(a, b, metavars, options)
    assert(a and b)

    if not options.quote then
      -- Metavar
      if lib.kind(b, 'sym') then
        metavars[lib.sym(b)] = a
        return true
      end

      -- Capture functions
      if lib.kind(b, 'fn') then
        if lib.fn(b, 'quote') then
          -- Do not apply capture functions/metavars
          return find_subexpr_rec(a, lib.arg(b, 1), metavars, {quote = true})
        elseif lib.fn(b, 'capture') then
          -- Capture subexpression
          -- Example:
          --   capture(a, quote(a + b)) => a := a + b
          local r = find_subexpr_rec(a, lib.arg(b, 2), metavars, options)
          if r then
            metavars[lib.sym(lib.arg(b, 1))] = a
          end
          return r
        elseif lib.fn(b, 'por') then
          -- Logical or
          return find_subexpr_rec(a, lib.arg(b, 1), metavars, options) or
                 find_subexpr_rec(a, lib.arg(b, 1), metavars, options)
        elseif lib.fn('pand') then
          -- Logical and
          return find_subexpr_rec(a, lib.arg(b, 1), metavars, options) and
                 find_subexpr_rec(a, lib.arg(b, 1), metavars, options)
        end
        -- TODO: Add functions for matching vectors
      end
    end

    -- Match
    if compare_head(a, b) then
      local x, y = lib.num_args(a), lib.num_args(b)
      if x ~= y then
        return false
      end

      for i = 1, x do
        if not find_subexpr_rec(lib.arg(a, i), lib.arg(b, i), metavars, options) then
          return false
        end
      end

      return true
    end
  end

  local matches = {}

  local function match_subexpr_rec(a, b)
    local vars = {}
    local r = find_subexpr_rec(a, b, vars, {})
    if r then
      table.insert(matches, {expression = a, metavars = vars})
    end

    if mode == 'recurse' then
      for i = 1, lib.num_args(a) do
        match_subexpr_rec(lib.arg(a, i), b)
      end
    end
  end

  match_subexpr_rec(v, w)
  if matches and #matches > 0 then
    return matches
  end
end

function rewrite.substitute_vars(t, vars)
  local function substitute_vars_rec(a, options)
    print('sub vars rec '..output.print_alg(a))
    if not options.quote then
      if lib.kind(a, 'sym') then
        if not vars[lib.sym(a)] then return a end -- Ignore missing metavar error
        return util.table.clone(vars[lib.sym(a)])
      end

      if lib.kind(a, 'fn') then
        if lib.fn(a, 'quote') then
          return lib.map(lib.arg(a, 1), substitute_vars_rec, {quote = true})
        end
      end
    end

    return lib.map(a, substitute_vars_rec, options)
  end

  return lib.map(t, substitute_vars_rec, {})
end

function rewrite.rewrite(v, w, r, mode)
  mode = mode or 'root'

  v = util.table.clone(v)

  local matches = rewrite.match_subexpr(v, w, mode)
  for _, m in ipairs(matches or {}) do
    util.table.replace_contents(m.expression, rewrite.substitute_vars(r, m.metavars))
  end

  return v
end

return rewrite
