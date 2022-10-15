local list = {}

-- Get first list item
---@param l table
---@return any
function list.head(l)
  if l and #l > 0 then return l[1] end
end

-- Get list tail
---@param l table
---@param mode nil|'unpack'
---@return any[]
function list.rest(l, mode)
  return list.slice(l, 2, nil, mode)
end

-- Copy list range a:b
---@param l table
---@param a number
---@param b number
---@param mode nil|'unpack'
---@return table
function list.slice(l, a, b, mode)
  local r = {}
  if l then
    for i = (a or 1), (b or #l) do table.insert(r, l[i]) end
    if mode == 'unpack' then return table.unpack(r) end
  end
  return r
end

-- Apply function fn on each list element
---@param l table
---@param fn function
---@return any[]
function list.map(l, fn, ...)
  local r = {}
  for _, v in ipairs(l) do
    local rv = fn(v, ...)
    if rv then
      table.insert(r, rv)
    end
  end
  return r
end

-- Shallow copy list
---@param l table
---@return any[]
function list.copy(l)
  local r = {}
  for _, v in ipairs(l) do table.insert(r, v) end
  return r
end

-- Join two lists or values
---@param a any
---@param b any
---@return table
function list.join(a, b)
  local c = {}
  if type(a) == 'table' then
    for _, v in ipairs(a) do table.insert(c, v) end
  else
    table.insert(c, a)
  end
  if type(b) == 'table' then
    for _, v in ipairs(b) do table.insert(c, v) end
  else
    table.insert(c, b)
  end
  return c
end

local tab = {}

function tab.compare(a, b)
  if type(a) == type(b) and type(a) == 'table' then
    if #a ~= #b then return false end
    for k, v in pairs(a) do
      if not tab.compare(v, b[k]) then return false end
    end
    for k, _ in pairs(b) do
      if not a[k] then return false end
    end
    return true
  end
  return a == b
end

local set = {}

function set.contains(l, needle)
  for _, v in ipairs(l) do
    if tab.compare(v, needle) then return true end
  end
end

function set.union(a, b)
  local c = {}
  for _, v in ipairs(a) do table.insert(c, v) end
  for _, v in ipairs(b) do table.insert(c, v) end
  return c
end

return {
  set = set,
  list = list,
  table = tab,
}
