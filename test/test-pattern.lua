local tests = {}

function tests.match_any()
  Expect('match(a,x)',    'true')
  Expect('match(a b,x)',  'true')
  Expect('match(a+b,x)',  'true')
  Expect('match(a-b,x)',  'true')
  Expect('match(a/b,x)',  'true')
  Expect('match(a^b,x)',  'true')
  Expect('match(a!,x)',   'true')
  Expect('match(1,x)',    'true')
end

function tests.match_sum()
  --Expect('match_vars(a+b,x+y)', '{{x,a},{y,b}}')
  --Expect('match_vars(a-b,x+y)', '{{x,a},{y,-1 b}}')
end

return tests
