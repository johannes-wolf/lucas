local tests = {}

function tests.dict()
  Expect('dict(a_=1, b_=2)', '{{a_,1},{b_,2}}')
end

function tests.get()
  Expect('dict.get(dict(a_=1, b_=2),a_)', '1')
  Expect('dict.get(dict(a_=1, b_=2),b_)', '2')
  Expect('dict.get(dict(a_=1, b_=2),c_)', 'false')
  Expect('dict.get(dict(a_=1, b_=2,a_=3),a_)', '1')
end

function tests.get_all()
  Expect('dict.get_all(dict(a_=1, b_=2),a_)',      '{1}')
  Expect('dict.get_all(dict(a_=1, a_=2),a_)',      '{1,2}')
  Expect('dict.get_all(dict(a_=1, b_=2),c_)',      '{}')
  Expect('dict.get_all(dict(a_=1, b_=2,a_=3),a_)', '{1,3}')
end

return tests
