function _G.Class(name, base)
  local classdef = {}

  setmetatable(classdef, {
    __index = base,
    __call = function(_, ...)
      local inst = {
        class = classdef,
        class_name = name or '',
        super = base or nil,
      }
      setmetatable(inst, {__index = classdef})
      if inst.init then
        inst:init(...)
      end
      return inst
    end,
    __tostring = function(self)
      return self.class_name
    end,

    isa = function(self, mt)
      return getmetatable(self) == mt
    end,
  })

  return classdef
end
