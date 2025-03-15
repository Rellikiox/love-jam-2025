vec2 = Object:extend()

function vec2.new(x, y)
	local v = { x = x or 0, y = y or 0 }
	setmetatable(v, vec2)
	return v
end

function vec2:init(args)
	self.x = args[1]
	self.y = args[2]
end

function vec2.from_angle(a)
	return vec2 { math.cos(a), math.sin(a) }
end

function vec2.__add(a, b)
	return vec2.new(a.x + b.x, a.y + b.y)
end

function vec2.__sub(a, b)
	return vec2.new(a.x - b.x, a.y - b.y)
end

function vec2.__mul(a, b)
	if type(a) == 'number' then
		return vec2.new(b.x * a, b.y * a)
	elseif type(b) == 'number' then
		return vec2.new(a.x * b, a.y * b)
	else
		error('Can only multiply vector by scalar.')
	end
end

function vec2.__div(a, b)
	if type(b) == 'number' then
		return vec2.new(a.x / b, a.y / b)
	else
		error('Invalid argument types for vector division.')
	end
end

function vec2.__eq(a, b)
	return a.x == b.x and a.y == b.y
end

function vec2.__ne(a, b)
	return not vec2.__eq(a, b)
end

function vec2.__unm(a)
	return vec2.new(-a.x, -a.y)
end

function vec2.__lt(a, b)
	return a.x < b.x and a.y < b.y
end

function vec2.__le(a, b)
	return a.x <= b.x and a.y <= b.y
end

function vec2.__tostring(v)
	return '(' .. v.x .. ', ' .. v.y .. ')'
end

function vec2:distance(b)
	return math.sqrt((self.x - b.x) ^ 2 + (self.y - b.y) ^ 2)
end

function vec2:angle()
	return math.atan2(self.y, self.x)
end

function vec2:normalized()
	local length = math.sqrt(self.x * self.x + self.y * self.y)
	if length > 0 then
		return vec2 { self.x / length, self.y / length }
	end
	return self
end

function vec2:length()
	return math.sqrt(self.x ^ 2 + self.y ^ 2)
end

function vec2:length_squared()
	return self.x ^ 2 + self.y ^ 2
end

function vec2:floor()
	return vec2 { math.floor(self.x), math.floor(self.y) }
end

vec2.zero = vec2 { 0, 0 }
vec2.one = vec2 { 1, 1 }
