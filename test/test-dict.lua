local tests = {}

function tests.dict()
  Expect('dict[a_=1, b_=2]', '{{a_,1},{b_,2}}')
end

function tests.get()
  Expect('dict.get[dict[$a=1, $b=2      ],$a]', '1')
  Expect('dict.get[dict[$a=1, $b=2      ],$b]', '2')
  Expect('dict.get[dict[$a=1, $b=2      ],$c]', 'false')
  Expect('dict.get[dict[$a=1, $b=2, $a=3],$a]', '1')
end

function tests.get_all()
  Expect('dict.get_all[dict[$a=1, $b=2      ],$a]', '{1}')
  Expect('dict.get_all[dict[$a=1, $a=2      ],$a]', '{1,2}')
  Expect('dict.get_all[dict[$a=1, $b=2      ],$c]', '{}')
  Expect('dict.get_all[dict[$a=1, $b=2, $a=3],$a]', '{1,3}')
end

return tests
