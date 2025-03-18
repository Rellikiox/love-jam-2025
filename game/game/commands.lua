local Assets = require 'game.assets'
local Events = require 'engine.events'

local Command = Object:extend()



function Command:draw_path()
	love.graphics.setLineWidth(3)
	love.graphics.line(self.source.x, self.source.y, self.destination.x, self.destination.y)
	love.graphics.setLineWidth(1)
end

local MoveComand = Command:extend()

function MoveComand:init(args)
	self.source = args.source
	self.destination = args.destination
end

function MoveComand:draw_marker()
	Assets.images.move_command:draw(self.destination)
end

function MoveComand:update(delta)
	local direction = (self.destination - self.entity.position):normalized()
	self.entity.position = self.entity.position + direction * self.entity.speed * delta
	self.entity.body:setPosition(self.entity.position.x, self.entity.position.y)
	if (self.destination - self.entity.position):length() < 1 then
		return true
	end
end

local PatrolCommand = Command:extend()

function PatrolCommand:init(args)
	self.points = args.points
	self.target_point = 1
	self.draw_points = {}
	for _, point in ipairs(self.points) do
		table.insert(self.draw_points, point.x)
		table.insert(self.draw_points, point.y)
	end
	table.insert(self.draw_points, self.points[1].x)
	table.insert(self.draw_points, self.points[1].y)
end

function PatrolCommand:draw_path()
	love.graphics.setLineWidth(2)
	love.graphics.line(unpack(self.draw_points))
	love.graphics.setLineWidth(1)
end

function PatrolCommand:draw_marker()
	for _, point in ipairs(self.points) do
		Assets.images.patrol_command:draw(point)
	end
end

function PatrolCommand:update(delta)
	local destination = self.points[self.target_point]
	local direction = (destination - self.entity.position):normalized()
	self.entity.position = self.entity.position + direction * self.entity.speed * delta
	self.entity.body:setPosition(self.entity.position.x, self.entity.position.y)
	if (destination - self.entity.position):length() < 1 then
		local prev = self.target_point
		self.target_point = math.fmod(self.target_point, #self.points) + 1
	end
end

local DistractComand = MoveComand:extend()

function DistractComand:init(args)
	self.source = args.source
	self.destination = args.destination
	self.target = args.target
	self.arrived = false
	self.finished = false
	self.wait_timer = Timer {
		autostart = false,
		timeout = 1.0,
		callback = function()
			Events:send('launch-firecracker', self.destination, self.target)
		end
	}
end

function DistractComand:draw_path()
	Command.draw_path(self)
	if self.target then
		love.graphics.line(self.destination.x, self.destination.y, self.target.x, self.target.y)
	end
end

function DistractComand:draw_marker()
	Assets.images.distract_command:draw(self.destination)
	if self.target then
		Assets.images.distract_target:draw(self.target)
	end
end

function DistractComand:update(delta)
	if not self.arrived then
		self.arrived = MoveComand.update(self, delta)
		if self.arrived then
			self.wait_timer:start()
		end
	else
		self.wait_timer:increment(delta)
		if self.wait_timer.finished then
			return true
		end
	end
end

local WaitComand = MoveComand:extend()

function WaitComand:init(args)
	self.source = args.source
	self.destination = args.destination
	self.finished = false
	self.wait_timer = Timer {
		timeout = 0,
		callback = function()
			self.finished = true
		end
	}
	self:set_wait_time(0.1)
end

function WaitComand:set_wait_time(time)
	self.wait_time = string.format("%.1f", time)
	self.wait_timer.timeout = tonumber(self.wait_time)
end

function WaitComand:draw_marker()
	local offset = (self.arrived and not self.finished) and vec2 { 0, -20 } or vec2.zero

	Colors.FullWhite:set()
	Assets.images.wait_command:draw(self.destination + offset)

	Colors.Black:set()
	love.graphics.setFont(FontTiny)
	local point = (self.destination + offset):floor()
	Colors.White:set()
	love.graphics.print(string.format("%.1f", self.wait_timer.timeout - self.wait_timer.elapsed), point.x - 7,
		point.y - 12)
end

function WaitComand:update(delta)
	if not self.arrived then
		self.arrived = MoveComand.update(self, delta)
	else
		self.wait_timer:increment(delta)
		if self.finished then
			return true
		end
	end
end

-- WaitSignalCommand

-- SendSignalCommand

return { Move = MoveComand, Patrol = PatrolCommand, Distract = DistractComand, Wait = WaitComand }
