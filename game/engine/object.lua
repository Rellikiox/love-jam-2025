--||--
--This Object implementation was taken from SNKRX (MIT license). Slightly modified, this is a very simple OOP base

Object = {}
Object.__index = Object
function Object:init()
end

function Object:extend()
    local cls = {}
    for k, v in pairs(self) do
        if k:find('__') == 1 then
            cls[k] = v
        end
    end
    cls.__index = cls
    cls.super = self
    setmetatable(cls, self)
    return cls
end

function Object:is(T)
    local metatable = getmetatable(self)
    while metatable do
        if metatable == T then
            return true
        end
        metatable = getmetatable(metatable)
    end
    return false
end

function Object:__call(...)
    local object = setmetatable({}, self)
    object:init(...)
    return object
end
