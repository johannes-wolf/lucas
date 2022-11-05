local lexer = require 'lexer'
local parser = require 'parser'
local util = require 'util'
local fraction = require 'fraction'
local operator = require 'operator'
local calc = require 'calc'

local input = {}

local function parse_real(_, token)
  return calc.make_real(tonumber(token[1]) or 0)
end

local function parse_integer_fraction(p, token)
  local num = tonumber(token[1])
  local denom = 1

  if p:match('s', ':') then
    p:consume()
    local tmp = tonumber(p:expect('n')[1]) or 1

    if p:match('s', ':') then
      p:consume()
      denom = tonumber(p:expect('n')[1]) or 1

      num = num * denom + tmp
    else
      denom = tmp
    end
  end

  return calc.make_fraction(num, denom)
end

local function parse_parentheses(p, token)
  local expr = p:parse()
  p:expect('s', ')')
  return expr
end

local function parse_list(p, token)
  local args = p:parse_list({ ',', kind = 's' }, { '}', kind = 's' })
  return util.list.prepend('vec', args)
end

local function parse_call(p, left, token)
  local args = p:parse_list({ ',', kind = 's' }, { ']', kind = 's' })
  return util.list.join({'call', left}, {util.list.prepend('vec', args)})
end

local function parse_id(_, token)
  local name = token[1]
  if name == '_' or name == '__' then
    return {'tmp', name} -- Special templates _, __ (same as $_ and $__)
  elseif name:find('^.*_$') then
    return {'tmp', name:sub(1, -2)}
  elseif name:find('^$.*$') then
    return {'tmp', name:sub(2)}
  elseif name:find('^_.*$') then
    return {'unit', name:sub(2)}
  end

  return {'sym', name}
end

local function parse_statements(p, left, _)
  local l = {';', left}
  while not p:eof() do
    table.insert(l, p:parse())
    if not p:match('s', ';') then
      break
    end
  end
  return l
end

local function make_parselets()
  local parselets = {
    ['f'] = { prefix = parse_real },
    ['n'] = { prefix = parse_integer_fraction },
    ['('] = { prefix = parse_parentheses },
    ['{'] = { prefix = parse_list },
    ['id']= { prefix = parse_id },
    ['['] = { infix  = parse_call, precedence = 100 },
    [';'] = { infix  = parse_statements, precedence = 1 },
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
      parselet.precedence = v.suffix.precedence
      parselet.infix = function(p, left, _)
        return p:parse_infix({k, left}, 0)
      end
    end
    parselets[k] = parselet
  end

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
  implicit_multiply('n')  -- 2 a   => 2*a
  implicit_multiply('f')  -- 2.0 a => 2*a
  implicit_multiply('(')  -- a (b) => a*(b)
  implicit_multiply('{')  -- a (b) => a*(b)

  return parselets
end

-- Expression parsing entry point
---@param str string
---@return    Expression|nil
function input.read_expression(str)
  local tokens = lexer.lex(str)
  local parselets = make_parselets()

  return parser.parse(tokens, parselets)
end

return input
