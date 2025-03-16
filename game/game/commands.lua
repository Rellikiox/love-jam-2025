local Assets = require 'game.assets'

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
	love.graphics.draw(Assets.images.tiles, Assets.images.move_command, self.destination.x - 16, self.destination.y - 16)
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
		love.graphics.draw(Assets.images.tiles, Assets.images.patrol_command, point.x - 16, point.y - 16)
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

return { Move = MoveComand, Patrol = PatrolCommand }
