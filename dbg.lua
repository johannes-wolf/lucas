local d = {}

d.trace = false

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

function d.print(v, msg)
  print((msg or 'dbg: ')..d.dump(v))
  return v
end

function d.format_trace(msg, ...)
  return 'TRACE '..msg..d.dump({...})
end

function d.call(msg, ...)
  local out = require 'output'
  local util = require 'util'
  msg = msg..': '
  msg = msg..table.concat(util.list.map({...}, out.print_alg), ', ')
  print(msg)
end

return d
