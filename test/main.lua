package.path = package.path .. ';../?.lua'

_G.test = require 'testlib'

require 'test-simplify'
require 'test-algo'
