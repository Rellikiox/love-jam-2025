local Assets = require 'game.assets'
local Physics = require 'game.physics'

local Entity = Object:extend()

function Entity:init(args)
	self.alive = true
	self.name = args.name
	self.position = args.position
	self.current_command = 1
	self.quad = args.quad
	self.radius = args.radius
	self.is_goblin = args.is_goblin
	self.speed = 30
	self.commands = {}
	for _, command in ipairs(args.commands or {}) do
		self:add_command(command)
	end

	-- Add physics for picking and collission detection
	self.body = love.physics.newBody(Physics.world, self.position.x, self.position.y, 'dynamic')
	self.shape = love.physics.newCircleShape(self.radius)
	self.fixture = love.physics.newFixture(self.body, self.shape, 1)
	self.fixture:setUserData(self)
	self.fixture:setSensor(true)
end

function Entity:update(delta)
	if self.current_command > #self.commands then
		return
	end

	local finished = self.commands[self.current_command]:update(delta)
	if finished then
		self.current_command = self.current_command + 1
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

function Entity:draw_commands(is_selected)
	if is_selected then
		Colors.Black:set()
	else
		Colors.Black:with_alpha(0.5):set()
	end
	for _, command in ipairs(self.commands) do
		command:draw_path()
	end

	if is_selected then
		Colors.FullWhite:set()
	else
		Colors.FullWhite:with_alpha(0.5):set()
	end
	for _, command in ipairs(self.commands) do
		command:draw_marker()
	end
	Colors.FullWhite:set()
end

function Entity:add_command(command)
	command.entity = self
	table.insert(self.commands, command)
end

function Entity:next_command_position()
	if #self.commands == 0 then
		return self.position
	end
	return self.commands[#self.commands].destination
end

return Entity
