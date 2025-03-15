local Assets = require 'game.assets'
local Entity = Object:extend()

function Entity:init(args)
	self.position = args.position
	self.commands = {}
	self.quad = args.quad
	self.radius = args.radius
end

function Entity:update()
	if #self.commands == 0 then
		return
	end
end

function Entity:draw()
	love.graphics.draw(
		Assets.tiles,
		self.quad,
		self.position.x - 16,
		self.position.y - 16
	)
end

return Entity
