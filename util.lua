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
---@param a number|nil
---@param b number|nil
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
---@param fn function (value) => replacement|nil
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

-- Apply function fn on each list element
---@param l table
---@param fn function (index, value) => replacement|nil
---@return any[]
function list.mapi(l, fn, ...)
  local r = {}
  for i, v in ipairs(l) do
    local rv = fn(i, v, ...)
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

function list.prepend(a, b)
  local c = {a}
  for _, v in ipairs(b) do table.insert(c, v) end
  return c
end

local tab = {}

-- Compare two tables
---@param a table       Table a
---@param b table       Table b
---@param fn function?  Predicate function
---@return boolean
function tab.compare(a, b, fn)
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
  if fn then return fn(a, b) else return a == b end
end

-- Compare two lists with an optional range
---@param a     table    Left table
---@param b     table    Right table
---@param start number?  Start index (1)
---@param stop  number?  Stop index
function tab.compare_slice(a, b, start, stop)
  start = start or 1
  stop = stop or #a

  if #a < stop or #b < stop then
    return false
  end

  for i = start, stop do
    if not tab.compare(a[i], b[i]) then
      return false
    end
  end

  return true
end

function tab.clone(a)
  local function clone_rec(x)
    if type(x) == 'table' then
      local t = {}
      for k, v in pairs(x) do t[k] = clone_rec(v) end
      return t
    end
    return x
  end
  return clone_rec(a)
end

function tab.replace_contents(a, b)
  for k in next, a do rawset(a, k, nil) end
  for k, v in next, b do rawset(a, k, v) end
  return a
end

local set = {}

function set.unique(l, cmp)
  local n = {l[1]}
  for i = 2, #l do
    if not set.contains(n, l[i], cmp) then
      table.insert(n, l[i])
    end
  end
  return n
end

function set.contains(l, needle, cmp)
  cmp = cmp or tab.compare
  for _, v in ipairs(l) do
    if cmp(v, needle) then return true end
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
