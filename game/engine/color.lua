local function rgba_to_hsla(r, g, b, a)
	-- Ensure r, g, b are in [0,1]
	local max_val = math.max(r, g, b)
	local min_val = math.min(r, g, b)
	local delta = max_val - min_val

	-- Calculate Lightness
	local l = (max_val + min_val) / 2

	-- Calculate Saturation
	local s = 0
	if delta ~= 0 then
		s = delta / (1 - math.abs(2 * l - 1))
	end

	-- Calculate Hue
	local h = 0
	if delta ~= 0 then
		if max_val == r then
			h = (g - b) / delta % 6
		elseif max_val == g then
			h = (b - r) / delta + 2
		elseif max_val == b then
			h = (r - g) / delta + 4
		end
		h = h * 60
		if h < 0 then
			h = h + 360
		end
	end

	return h, s, l, a -- H (0-360), S (0-1), L (0-1), A (unchanged)
end

local function hsla_to_rgba(h, s, l, a)
	-- Normalize Hue to [0,360]
	h = h % 360

	local c = (1 - math.abs(2 * l - 1)) * s
	local x = c * (1 - math.abs((h / 60) % 2 - 1))
	local m = l - c / 2

	local r, g, b = 0, 0, 0

	if h < 60 then
		r, g, b = c, x, 0
	elseif h < 120 then
		r, g, b = x, c, 0
	elseif h < 180 then
		r, g, b = 0, c, x
	elseif h < 240 then
		r, g, b = 0, x, c
	elseif h < 300 then
		r, g, b = x, 0, c
	else
		r, g, b = c, 0, x
	end

	-- Adjust RGB by adding m
	return r + m, g + m, b + m, a
end

local Color = Object:extend()

function Color:init(r, g, b, a)
	self.r = r
	self.g = g
	self.b = b
	self.a = a
end

function Color.from_hex(hex, alpha)
	hex = hex:gsub('#', '')
	return Color(
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
		alpha or 1
	)
end

function Color:set()
	love.graphics.setColor(self.r, self.g, self.b, self.a)
end

function Color:with_alpha(alpha)
	return Color(self.r, self.g, self.b, alpha)
end

function Color:adjust_brightness(factor)
	local h, s, l, a = rgba_to_hsla(self.r, self.g, self.b, self.a)
	l = clamp(l * factor, 0, 1)
	local r, g, b, a = hsla_to_rgba(h, s, l, a)
	return Color(r, g, b, a)
end

function Color:lighten(amount)
	return self:adjust_brightness(1 + (amount or 0.1))
end

function Color:darken(amount)
	return self:adjust_brightness(1 - (amount or 0.1))
end

function Color:to_array()
	return { self.r, self.g, self.b, self.a }
end

return Color
