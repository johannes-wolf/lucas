local fn = require 'functions'
local lib = require 'lib'
local calc = require 'calc'

local function E(expr, env)
  local e = require 'eval'
  return e.eval(expr, env)
end

-- is_true
fn.def_lua('is_true', 1,
function (a, _)
  return calc.make_bool(calc.is_true_p(a[1]))
end)

-- is_false
fn.def_lua('is_false', 1,
function (a, _)
  return calc.make_bool(not calc.is_true_p(a[1]))
end)

-- if
--   if(test, then, else)
fn.def_lua('if', {{name = 'test'},
                  {name = 'if_then'},
                  {name = 'if_else'}},
function (a, env)
  a.test = E(a.test, env)
  if calc.is_true_p(a.test) then
    return E(a.if_then, env)
  else
    return E(a.if_else, env)
  end
end, fn.attribs.hold_all)

-- switch
--   switch(expr, val1, res1, ..., [def])
fn.def_lua('switch', {{name = 'expr'},
                      {var = true}},
function (a, env)
  a.expr = E(a.expr, env)
  for i = 1, #a.var, 2 do
    if calc.is_true_p(E({'=', a.expr, a.var[i]}, env)) then
      return E(a.var[i + 1], env)
    end
  end

  if #a.var % 2 ~= 0 then
    return E(a.var[#a.var], env)
  end
end, fn.attribs.hold_all)

-- do
--   repeat expr n times
fn.def_lua('do', {{name = 'expr'},
                  {name = 'n'}},
function (a, env)
  a.n = calc.to_number(a.n, 'int') or 0

  local r
  for _ = 1, a.n do
    r = E(a.expr, env)
  end
  return r
end, fn.attribs.hold_first)

-- nest
--   apply f to expr n times
fn.def_lua('nest', {{name = 'f'},
                    {name = 'expr'},
                    {name = 'n'}},
function (a, env)
  a.n = calc.to_number(a.n, 'int') or 0

  local r = a.expr
  for _ = 1, a.n do
    r = E({'call', a.f, {'vec', r}}, env)
  end
  return r
end)

-- nest_list
--   apply f starting with expr n times
--   returns all results as list
fn.def_lua('nest_list', {{name = 'f'},
                         {name = 'expr'},
                         {name = 'n'}},
function (a, env)
  a.n = calc.to_number(a.n, 'int') or 0

  local r = a.expr
  local l = {'vec'}
  for _ = 1, a.n do
    r = E({'call', a.f, {'vec', r}}, env)
    table.insert(l, r)
  end
  return l
end)

-- fixed_point
--   start with expr and apply f until the result does not change
fn.def_lua('fixed_point', {{name = 'f'},
                           {name = 'expr'}},
function (a, env)
  local old
  local r = a.expr
  while not lib.compare(r, old) do
    old = r
    r = E({'call', a.f, {'vec', r}}, env)
  end
  return r
end)

-- fixed_point_list
--   start with expr and apply f until the result does not change
--   returns a list of all results
fn.def_lua('fixed_point_list', {{name = 'f'},
                                {name = 'expr'}},
function (a, env)
  local old
  local r = a.expr
  local l = {'vec'}
  while not lib.compare(r, old) do
    old = r
    r = E({'call', a.f, {'vec', r}}, env)
    table.insert(l, r)
  end
  return l
end)
