local tests = {}

function tests.new()
  Expect('vec.new(3)',   '{0,0,0}')
  Expect('vec.new(3,1)', '{1,1,1}')
end

return tests
