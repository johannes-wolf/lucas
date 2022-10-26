local lexer = require 'lexer'
local parser = require 'parser'
local util = require 'util'
local fraction = require 'fraction'
local operator = require 'operator'

local input = {}

function input.read_expression(str)
  local tokens = lexer.lex(str)

  local parselets = {}

  -- Parser for floats
  parselets['f'] = {
    prefix = function(_, token)
      -- TODO: Save floats as mantissa+exponent integers
      return {'real', tonumber(token[1])}
    end,
  }

  -- Parser for integers and fractions ([c:]num:denom)
  parselets['n'] = {
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

      return {'int', n}
    end
  }

  -- Parser for parentheses
  parselets['('] = {
    prefix = function(p, _)
      local e = p:parse()
      p:expect('s', ')')
      return e
    end
  }

  -- Add parsers for registered operators
  for k, v in pairs(operator.table) do
    local parselet = {}
    if v.prefix then
      parselet.prefix = function(p, _)
        return {k, p:parse_precedence(v.prefix.precedence)}
      end
    end
    if v.infix then
      parselet.precedence = v.infix.precedence
      parselet.infix = function(p, left, _)
        return {k, left, p:parse_precedence(v.infix.precedence)}
      end
    end
    if v.suffix then
      parselet.infix = function(p, left, _)
        return p:parse_infix({k, left}, 0)
      end
    end
    parselets[k] = parselet
  end

  -- Parser for variables and functions
  parselets['id'] = {
    prefix = function(p, token)
      if p:match('s', '(') then
        p:consume()
        local args = p:parse_list({',', kind='s'}, {')', kind='s'})
        return util.list.join({'fn', token[1]}, args)
      end

      return {'sym', token[1]}
    end
  }

  -- Parse units (_name)
  parselets['u'] = {
    prefix = function(_, token)
      return {'unit', token[1]}
    end
  }

  -- Implicit multiplication
  local function implicit_multiply_parselet(p, left, t)
    local k = (t.kind == 's' or t.kind == 'o') and t[1] or t.kind
    local right = p:parse_infix(parselets[k].prefix(p, t), parselets['*'].precedence)
    return {'*', left, right}
  end

  local function implicit_multiply(k)
    parselets[k].precedence = parselets['*'].precedence
    parselets[k].infix = implicit_multiply_parselet
  end

  implicit_multiply('id') -- a b   => a*b
  implicit_multiply('u')  -- a _u  => a*_u
  implicit_multiply('n')  -- 2 a   => 2*a
  implicit_multiply('f')  -- 2.0 a => 2*a
  implicit_multiply('(')  -- a (b) => a*(b)

  return parser.parse(tokens, parselets)
end

return input
