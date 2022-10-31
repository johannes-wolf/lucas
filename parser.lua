local function parse(tokens, parselets)
  local parser = {
    i = 1
  }

  function parser:eof()
    return self.i > #tokens
  end

  function parser:lookahead(offset)
    offset = (offset or 0) + self.i
    if offset <= #tokens then
      return tokens[offset]
    end
  end

  function parser:match(kind, text)
    if not self:eof() then
      local t = self:lookahead()
      return ((not kind) or t.kind == kind) and ((not text) or t[1] == text)
    end
  end

  function parser:expect(kind, text)
    if not self:match(kind, text) then
      if self:eof() then
        error('Expected ' .. (text or kind) .. ' got EOF')
      end
      local t = self:lookahead()
      error('Expected ' .. (text or kind) .. ' got ' .. (t and (t[1] .. ' (' .. t.kind .. ')') or 'nil'))
    end
    return self:consume()
  end

  function parser:consume()
    local token = self:lookahead()
    self.i = self.i + 1
    return token
  end

  function parser:precedence(token)
    if not token then return 0 end
    local p = self:find_parselet(token)
    if p then
      return p.precedence or 0
    end
    return 0
  end

  function parser:find_parselet(token)
    if token.kind == 'o' or
       token.kind == 's' then
      return parselets[token[1]]
    end
    return parselets[token.kind]
  end

  function parser:parse_infix(left, precedence)
    while precedence < self:precedence(self:lookahead()) do
      local t = self:consume()
      local p = self:find_parselet(t)
      if not p then
        error('No parser for token ' .. (t.kind or 'nil'))
      end
      if not p.infix then
        error('No infix parser for token ' .. (t.kind or 'nil'))
      end

      left = p.infix(self, left, t)
    end

    return left
  end

  function parser:parse_precedence(precedence)
    local t = self:consume()
    local p = self:find_parselet(t)
    if not p then
      error('No parser for token ' .. (t.kind or 'nil'))
    end
    if not p.prefix then
      error('No prefix parser for token ' .. (t.kind or 'nil') .. ' '.. (t[1] or 'nil'))
    end

    local left = p.prefix(self, t)
    return self:parse_infix(left, precedence)
  end

  -- Parser entry point
  function parser:parse()
    return self:parse_precedence(0)
  end

  -- Parse list of expressions
  ---@param delim Token  Delimiter token
  ---@param stop  Token  Stop token
  ---@return <any>       List of exressions
  function parser:parse_list(delim, stop)
    local e = {}

    if self:match(stop.kind, stop[1]) then
      self:consume()
      return e
    end

    while true do
      table.insert(e, self:parse())

      if not self:match(stop.kind, stop[1]) then
        if self:match(delim.kind, delim[1]) then
          self:consume()
        else
          error('Expected ' .. delim[1] .. ' got ' .. (self:lookahead()[1] or 'nil'))
        end
      else
        self:consume()
        break
      end
    end

    return e
  end

  local e = parser:parse()
  if not parser:eof() then
    error('Unparsed input')
  end

  return e
end

return {
  parse = parse
}
