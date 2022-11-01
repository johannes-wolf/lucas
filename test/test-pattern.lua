local tests = {}

function tests.pattern_var_order()
  Expect('x_',    'x_')
  Expect('y_+x_', 'y_+x_')
  Expect('y_ x_', 'y_ x_')
  Expect('y_ 3 x_', 'y_ 3 x_')
  Expect('y_ x_ 3', 'y_ x_ 3')
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

function tests.match_fn()
  Expect('match(f(x,y),f(x_,y_))',   'true')
  Expect('match(f(x),f(x_,y_))',     'false')
  Expect('match(f(x,y,z),f(x_,y_))', 'false')

  Expect('match(f(2,1),cond(f(x_,y_),y_=x_-1))', 'true')
  Expect('match(f(3,1),cond(f(x_,y_),y_=x_-1))', 'false')
  Expect('match(f(2,3),cond(f(x_,y_),y_=x_-1))', 'false')
end

function tests.match_nary_sum()
  Expect('dict.sort(match_vars(a+b,x_+y_))', '{{x_,a},{y_,b}}')
  --Expect('dict.sort(match_vars(a+b+c,x_+y_))', '{{x_,a},{y_,b}}')
  --Expect('dict.sort(match_vars(a+b+c+d,x_+y_))', '{{x_,a},{y_,b}}')
end

function tests.match_nary_product()
  Expect('dict.sort(match_vars(a b,x_ y_))', '{{x_,a},{y_,b}}')
  --Expect('dict.sort(match_vars(a b c,x_ y_))', '{{x_,a},{y_,b}}')
  --Expect('dict.sort(match_vars(a b c d,x_ y_))', '{{x_,a},{y_,b}}')
end

function tests.match_sum()
  Expect('dict.get(d,x_)=a and dict.get(d,y_)=b|d=match_vars(a+b,x_+y_)', 'true')
  Expect('dict.get(d,y_)=a and dict.get(d,x_)=b|d=match_vars(a+b,y_+x_)', 'true')
end

return tests
