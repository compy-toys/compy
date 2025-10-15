--- @alias Id string
--- @class Object
--- @field id Id

return {
  --- Simple factory, to spare boilerplate
  --- @param constructor function?
  --- @param lateinit function?
  create = function(constructor, lateinit)
    local ret = {}
    ret.__index = ret
    local function new(...)
      if constructor then
        return constructor(...)
      end
      return {}
    end

    setmetatable(ret, {
      __call = function(cls, ...)
        if type(cls.new) == "function" then
          return cls.new(...)
        else
          local instance = setmetatable(new(...), cls)
          if type(lateinit) == "function" then
            lateinit(instance)
          end
          return instance
        end
      end,
    })

    return ret
  end,

  --- Class factory from lua-users wiki, archived here:
  --- https://archive.vn/muhJx#selection-569.0-569.23
  --- Should be able to do (multiple) inheritance
  --- @return table
  newclass = function(...)
    --- "cls" is the new class
    local cls, bases = {}, { ... }
    --- copy base class contents into the new class
    for _, base in ipairs(bases) do
      for k, v in pairs(base) do
        cls[k] = v
      end
    end
    --- set the class's __index, and start filling an "is_a" table that contains
    --- this class and all of its bases
    --- so you can do an "instance of" check using my_instance.is_a[MyClass]
    cls.__index, cls.is_a = cls, { [cls] = true }
    for _, base in ipairs(bases) do
      for c in pairs(base.is_a or {}) do
        cls.is_a[c] = true
      end
      cls.is_a[base] = true
    end

    --- the class's __call metamethod
    setmetatable(cls, {
      __call = function(c, ...)
        local instance = setmetatable({}, c)
        --- TODO how to automate this
        --- run the init method if it's there
        -- local init = instance._init
        -- if init then init(instance, ...) end
        -- return instance
        return c.new(...)
      end
    })
    -- return the new class table, that's ready to fill with methods
    return cls
  end,

}
