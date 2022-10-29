local function parse_whitespace(s, i)
  return s:find('^%s*', i)
end

local function parse_syntax(s, i)
  return s:find('^([(){}:;,])', i)
end

local function parse_identifier(s, i)
  return s:find('^([%a][._\'"%w]*[_\'"%w]*)', i)
end

local function parse_unit(s, i)
  if s:sub(i, i) == '_' then
    return parse_identifier(s, i + 1)
  end
end

local function parse_string_literal(s, i)
  if s:sub(i, i) == '"' then
    return s:find('"', i + 1)
  end
end

local function get_sci_suffix(s, i)
  local ii, jj, text = s:find('^[eE]([-]?[%d]+)', i)
  if ii then
    return ii, jj, tonumber(text)
  end
end

local function parse_number(s, i)
  local ii, jj, text = s:find('^(%d+)', i)
  if ii then
    local _, sj, sci = get_sci_suffix(s, jj + 1)
    return ii, sj or jj, tonumber(text) * 10 ^ (sci or 0)
  end
end

local function parse_float(s, i)
  local ii, jj, text = s:find('^(%d+%.%d+)', i)
  if ii then
    local _, sj, sci = get_sci_suffix(s, jj + 1)
    return ii, sj or jj, tonumber(text) * 10 ^ (sci or 0)
  end
end

local function parse_operator(s, i)
  local t = {
    ':=',
    '|',
    'and', 'or', 'not',
    '=', '!=',
    '<=', '<', '>=', '>',
    '+', '-', '*', '/', '^',
    '!',
  }

  for _, text in ipairs(t) do
    if s:sub(i, i + text:len() - 1) == text then
      return i, i + text:len() - 1, text
    end
  end
end

---@param str string  Input string
---@return table<integer, string>  List of tokens
local function lex(str)
  local i, j = 1, str:len()

  local p = {
    {parse_whitespace},
    {parse_operator, 'o'},
    --{parse_string_literal, 'str'},
    {parse_identifier, 'id'},
    {parse_unit, 'u'},
    {parse_syntax, 's'},
    {parse_float, 'f'},
    {parse_number, 'n'},
  }

  local t = {}

  while i <= j do
    local last_i = i
    for _, item in ipairs(p) do
      local parser, meta = table.unpack(item)
      local _, jj, text = parser(str, i)
      if jj then i = jj + 1 end
      if text then table.insert(t, {text, kind = meta}); break end
    end

    if i == last_i then
      error('No parser for symbol at ' .. i)
      return nil
    end
  end

  return t
end

return {
  lex = lex
}
