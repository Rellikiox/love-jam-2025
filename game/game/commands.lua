local Command = Object:extend()


local MoveComand = Command:extend()

function MoveComand:init(args)
	self.source = args.source
	self.destination = args.destination
end

function MoveComand:draw()
	Colors.Black:set()
	love.graphics.setLineWidth(5)
	love.graphics.line(self.source.x, self.source.y, self.destination.x, self.destination.y)
	love.graphics.setLineWidth(1)
	Colors.FullWhite:set()
end

function MoveComand:update(delta)
	local direction = (self.destination - self.entity.position):normalized()
	self.entity.position = self.entity.position + direction * self.entity.speed * delta
	if (self.destination - self.entity.position):length() < 1 then
		return true
	end
end

return { Move = MoveComand }
