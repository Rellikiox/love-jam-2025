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

return { Move = MoveComand }
