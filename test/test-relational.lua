local tests = {}

function tests.eq()
  Expect('1=1',     'true')
  Expect('1=2',     'false')

  Expect('1:2=1:2', 'true')
  Expect('1:2=1:3', 'false')
  Expect('1:2=0.5', 'true')

  Expect('1.1=1.1', 'true')
  Expect('1.1=1.2', 'false')

  -- Same symbol is always equal to itself
  Expect('a=a',     'true')
  Expect('_a=_a',   'true')

  Expect('vec(1)=1',          'false')
  Expect('vec(1)=vec(1)',     'true')
  Expect('vec(2,1)=vec(1,2)', 'false')
  Expect('vec(1,2)=vec(1,2)', 'true')
  Expect('vec(a,2)=vec(b,2)', 'vec(a,2)=vec(b,2)')
  Expect('vec(a,2)=vec(a,2)', 'true')

  Expect('inf=inf', 'true')
end

function tests.lt()
  Expect('1<2', 'true')
  Expect('2<1', 'false')

  Expect('1:2<2:3', 'true')
  Expect('2:3<1:2', 'false')

  Expect('1.1<2.1', 'true')
  Expect('2.1<1.1', 'false')

  -- Same symbol is never < itself
  Expect('a<a',   'false')
  Expect('_a<_a', 'false')

  -- Different symbols compare symbolic
  Expect('a<b', 'a<b')
  Expect('b<a', 'b<a')

  -- Everything but inf is < inf
  Expect('1<inf',    'true')
  Expect('a<inf',    'true')
  Expect('-inf<inf', 'true')
  Expect('inf<inf',  'false')

  -- Everything but ninf is not < ninf
  Expect('1<-inf',   'false')
  Expect('a<-inf',   'false')
  Expect('-inf<-inf','false')
  Expect('inf<-inf', 'true')
end

function tests.gt()
  Expect('1>2', 'false')
  Expect('2>1', 'true')

  Expect('1:2>2:3', 'false')
  Expect('2:3>1:2', 'true')

  Expect('1.1>2.1', 'false')
  Expect('2.1>1.1', 'true')

  -- Same symbol is never > itself
  Expect('a>a',   'false')
  Expect('_a>_a', 'false')

  -- Different symbols compare symbolic
  Expect('a>b', 'a>b')
  Expect('b>a', 'b>a')

  -- Everything but inf is > inf
  Expect('1>inf',    'false')
  Expect('a>inf',    'false')
  Expect('-inf>inf', 'false')
  Expect('inf>inf',  'true')

  -- Everything but ninf is not > ninf
  Expect('1>-inf',   'true')
  Expect('a>-inf',   'true')
  Expect('-inf>-inf','true')
  Expect('inf>-inf', 'false')
end

return tests
