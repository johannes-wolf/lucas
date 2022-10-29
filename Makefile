##
# LuCAS
#
# @file
# @version 0.1

LUA=lua
LUACHECK=luacheck

all: test check

.PHONY: test
test:
	cd test; $(LUA) main.lua

check: *.lua
	$(LUACHECK) lucas.lua

# end
