function table.shuffle(tab)
	local len = #tab
	local r, tmp
	for i = 1, len do
		r = math.random(i, len)
		tmp = tab[i]
		tab[i] = tab[r]
		tab[r] = tmp
	end
end

function lerp(a, b, t)
	return a * (1 - t) + b * t
end

function exp_smoothing(a, b, speed, delta)
	return a + (b - a) * (1 - math.exp(-speed * delta))
end

function random_choice(list)
	return list[math.random(#list)]
end

function Timer(args)
	local autostart = true
	if args.autostart ~= nil then
		autostart = args.autostart
	end
	return {
		elapsed = 0,
		total_elapsed = 0,
		timeout = args.timeout,
		autostart = autostart,
		paused = not autostart,
		callback = args.callback,
		finished = false,
		finished_count = 0,
		increment = function(self, delta)
			if self.paused then
				return
			end
			self.elapsed = self.elapsed + delta
			self.total_elapsed = self.total_elapsed + delta
			while self.elapsed > self.timeout do
				self.finished_count = self.finished_count + 1
				if self.autostart then
					self.elapsed = self.elapsed - self.timeout
				else
					self.finished = true
					self.elapsed = 0
					self.paused = true
				end
				if self.callback then
					self.callback(self)
				end
			end
		end,
		start = function(self)
			self.paused = false
			self.finished = false
		end,
		restart = function(self)
			self.elapsed = 0
			self.total_elapsed = 0
			self.paused = false
			self.finished = false
			self.finished_count = 0
		end,
		stop = function(self)
			self.paused = true
			self.finished = false
		end
	}
end

function table.dump(t)
	local function serializeValue(val)
		if type(val) == 'table' then
			local items = {}
			for k, v in pairs(val) do
				if type(k) == 'number' then
					table.insert(items, serializeValue(v))
				else
					table.insert(items, string.format('"%s":%s', k, serializeValue(v)))
				end
			end
			-- Check if the table is an array (consecutive numeric keys from 1)
			local isArray = #val > 0
			for k, _ in pairs(val) do
				if type(k) ~= 'number' or k > #val then
					isArray = false
					break
				end
			end
			if isArray then
				return '[' .. table.concat(items, ',') .. ']'
			else
				return '{' .. table.concat(items, ',') .. '}'
			end
		elseif type(val) == 'string' then
			return string.format('"%s"', val)
		else
			return tostring(val)
		end
	end

	print(serializeValue(t))
end

function random_range(from, to)
	return from + math.random() * (to - from)
end

function hex_to_rgb(hex)
	hex = hex:gsub('#', '')
	local r = tonumber(hex:sub(1, 2), 16) / 255
	local g = tonumber(hex:sub(3, 4), 16) / 255
	local b = tonumber(hex:sub(5, 6), 16) / 255

	return { r, g, b }
end

function choose_n(list, n)
	if not list or #list == 0 then
		return {}
	end

	n = math.min(n, #list)
	local temp_list = {}
	for i = 1, #list do
		temp_list[i] = list[i]
	end

	local result = {}
	for i = 1, n do
		local index = math.random(1, #temp_list)
		table.insert(result, temp_list[index])
		table.remove(temp_list, index)
	end

	return result
end

function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

function len(table)
	local count = 0
	for _ in pairs(table) do
		count = count + 1
	end
	for _ in ipairs(table) do
		count = count + 1
	end
	return count
end

function table.shallow_copy(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

function table.copy_from(to, from)
	for k, v in pairs(from) do
		to[k] = v
	end
end

function noop()
end

function point_in_rect(point, position, size)
	local relative = point - position
	return relative.x >= 0 and relative.x <= size.x and relative.y >= 0 and relative.y <= size.y
end

function yield_and_wait(time)
	local start = love.timer.getTime()
	while (love.timer.getTime() - start) < time do
		coroutine.yield()
	end
end

function coroutine.resume_with_traceback(co, ...)
	local success, result = coroutine.resume(co, ...)
	if not success then
		error(debug.traceback(co, result), 2)
	end
	return success, result
end

function str_join(list, joiner, attribute)
	local value = ''
	for i, item in ipairs(list) do
		if attribute then
			value = value .. item[attribute]
		else
			value = value .. item
		end
		if i < #list then
			value = value .. joiner
		end
	end
	return value
end

function table.contains(t, value)
	for _, v in ipairs(t) do
		if v == value then
			return true
		end
	end
	return false
end

function draw_shadow_text(text, position, offset)
	position = position:floor()
	Colors.Black:set()
	love.graphics.print(text, position.x + offset, position.y + offset)
	Colors.White:set()
	love.graphics.print(text, position.x, position.y)
end
