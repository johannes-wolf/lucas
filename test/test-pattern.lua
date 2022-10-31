local tests = {}

function tests.pattern_var_order()
  Expect('x_',    'x_')
  Expect('y_+x_', 'y_+x_')
  Expect('y_ x_', 'y_ x_')
  Expect('y_ 3 x_', '3 y_ x_')
  Expect('y_ a x_ 3', '3 a y_ x_')
end

function tests.match_any()
  Expect('match(a,x_)',    'true')
  Expect('match(a b,x_)',  'true')
  Expect('match(a+b,x_)',  'true')
  Expect('match(a-b,x_)',  'true')
  Expect('match(a/b,x_)',  'true')
  Expect('match(a^b,x_)',  'true')
  Expect('match(a!,x_)',   'true')
  Expect('match(1,x_)',    'true')
end

function tests.match_sum()
  Expect('dict.get(d,x_)=a and dict.get(d,y_)=b|d=match_vars(a+b,x_+y_)', 'true')
  Expect('dict.get(d,y_)=a and dict.get(d,x_)=b|d=match_vars(a+b,y_+x_)', 'true')
end

return tests
