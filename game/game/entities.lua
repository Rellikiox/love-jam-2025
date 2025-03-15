local Assets = require 'game.assets'
local Physics = require 'game.physics'

local Entity = Object:extend()

function Entity:init(args)
	self.position = args.position
	self.commands = {}
	self.quad = args.quad
	self.radius = args.radius
	self.is_goblin = args.is_goblin

	-- Add physics for picking and collission detection
	self.body = love.physics.newBody(Physics.world, self.position.x, self.position.y, 'dynamic')
	self.shape = love.physics.newCircleShape(self.radius)
	self.fixture = love.physics.newFixture(self.body, self.shape, 1)
	self.fixture:setUserData(self)
end

function Entity:update()
	if #self.commands == 0 then
		return
	end
end

function Entity:draw()
	love.graphics.draw(
		Assets.images.tiles,
		self.quad,
		self.position.x - 16,
		self.position.y - 16
	)
end

return Entity
