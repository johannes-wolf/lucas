local d = {}

function d.dump(o)
  if type(o) == 'table' then
    local s = nil
    for k, v in pairs(o) do
      s = (s and s .. ', ') or '{'
      if type(k) ~= 'number' then s = s..d.dump(k)..'=' end
      s = s .. d.dump(v)
    end
    return (s or '{') .. '}'
  else
    return tostring(o)
  end
end

return d
