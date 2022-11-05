local tests = {}

function tests.new()
  Expect('mat.new[3,2  ]', '{{0,0},{0,0},{0,0}}')
  Expect('mat.new[3,2,1]', '{{1,1},{1,1},{1,1}}')
end

function tests.transpose()
  Expect('mat.transpose[mat[{1,2,3},{0,-6,7}]]', '{{1,0},{2,-6},{3,7}}')
end

return tests
