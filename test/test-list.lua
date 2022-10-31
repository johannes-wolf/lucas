local tests = {}

function tests.list()
  Expect('list(1,2,3)', '{1,2,3}')
end

return tests
