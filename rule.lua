local pattern = require 'pattern'
local dbg = require 'dbg'

local rule = {}
rule.max_iterations = 1000000

---@alias Rule table{pattern: Expression, replacement: Expression}
---@alias RuleSet Rule[]

-- Create rule table
---@param p Expression  Pattern
---@param r Expression  Replacement
---@return Rule
function rule.make(p, r)
  return {pattern = p, replacement = r}
end

-- Apply rule on expression
---@param expr Expression
---@param r    Rule
---@return boolean, Expression
---BUG: DO NOT USE
function rule.apply(expr, r)
  local changed = false
  local ok, matches = pattern.match(expr, r.pattern)
  if ok and matches then
    -- BUG: This does not work as expected, substitution is bogus, because of n-args operators!
    --      pattern.match can return invalid positions!
    for _, match in pairs(matches) do
      if match.pos.parent then
        match.pos.parent[match.pos.index] = pattern.substitute(r.replacement, match)
      else
        expr = pattern.substitute(r.replacement, match)
      end
      changed = true
    end
  end

  local simplify = require 'simplify'
  return changed, simplify.expr(expr) -- FIXME: simplify or eval?
end

-- Apply list of rules on expression until nothing changed
---@param expr Expression  Expression
---@param r    RuleSet     List of rules
---@return Expression
---BUG: DO NOT USE
function rule.apply_set(expr, r)
  for _ = 1, rule.max_iterations do
    local changed = false
    for _, sr in ipairs(r) do
      changed, expr = rule.apply(expr, sr)
      if changed then
        break
      end
    end
    if not changed then
      break
    end
  end
  return expr
end

return rule
