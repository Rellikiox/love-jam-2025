local Assets = require 'game.assets'
local Physics = require 'game.physics'
local Events = require 'engine.events'
local Agents = require 'game.agents'
local SFX = require 'engine.sfx'

local Treasure = Object:extend()

function Treasure:init(args)
	self.alive = true
	self.position = args.position
	if math.random() > 0.5 then
		self.image = Assets.images.treasure_a
	else
		self.image = Assets.images.treasure_b
	end
	self.rotation = math.random(4) * math.pi / 2
	self.looted = false
end

function Treasure:update(delta)
end

function Treasure:draw()
	self.image:draw(self.position, self.rotation)
	if self.looted then
		Assets.images.looted:draw(self.position)
	end
end

local ExitZone = Object:extend()

function ExitZone:init(args)
	self.alive = true
	self.position = args.position
end

function ExitZone:update(delta)
	local entities = Physics:get_entities_at(self.position, 5)
	for _, entity in ipairs(entities) do
		if entity.is_goblin and level.treasure_obtained >= 1 then
			Events:send('goblin-extracted', entity)
		end
	end
end

function ExitZone:draw()
	Assets.images.exit:draw(self.position)
end

local PressurePlate = Object:extend()

function PressurePlate:init(args)
	self.position = args.position
	self.alive = true

	self:set_device(args.device)
	self.pressed = false
end

function PressurePlate:set_device(device)
	self.device = device
	if device then
		table.insert(self.device.plates, self)
	end
end

function PressurePlate:update(delta)
	local entities = Physics:get_entities_at(self.position, 5)
	self.pressed = false
	for _, entity in ipairs(entities) do
		if entity:is(Agents.Agent) then
			self.pressed = true
			break
		end
	end
end

function PressurePlate:draw()
	if self.pressed then
		Assets.images.pressure_plate_pressed:draw(self.position)
	else
		Assets.images.pressure_plate:draw(self.position)
	end
end

local Door = Object:extend()

function Door:init(args)
	self.position = args.position
	self.alive = true
	self.is_open = false
	self.is_horizontal = args.is_horizontal
	level.pathfinding:add_door(self.position)

	self.body = love.physics.newBody(Physics.world, self.position.x, self.position.y, 'static')
	if self.is_horizontal then
		self.shape = love.physics.newRectangleShape(32, 12)
	else
		self.shape = love.physics.newRectangleShape(12, 32)
	end
	self.fixture = love.physics.newFixture(self.body, self.shape, 1)
	self.plates = {}
end

function Door:update(delta)
	local plate_pressed = false
	for _, plate in ipairs(self.plates) do
		if plate.pressed then
			plate_pressed = true
			break
		end
	end
	if plate_pressed and not self.is_open then
		self:open()
	end
	if not plate_pressed and self.is_open then
		self:close()
	end
end

function Door:draw()
	if not self.is_open then
		if self.is_horizontal then
			Assets.images.door_horizontal:draw(self.position)
		else
			Assets.images.door_vertical:draw(self.position)
		end
	else
		if self.is_horizontal then
			Assets.images.door_horizontal_open:draw(self.position)
		else
			Assets.images.door_vertical_open:draw(self.position)
		end
	end
end

function Door:open()
	self.is_open = true
	self.fixture:setSensor(true)
	level.pathfinding:toggle_node_at_position(self.position)
end

function Door:close()
	self.is_open = false
	self.fixture:setSensor(false)
	level.pathfinding:toggle_node_at_position(self.position)
end

local FirecrackerDust = Object:extend()

function FirecrackerDust:init(args)
	self.position = args.position
	self.alive = true
	self.rotation = math.random() * math.pi * 2
end

function FirecrackerDust:update(delta)
end

function FirecrackerDust:draw()
	Assets.images.firecracker_dust:draw(self.position, self.rotation)
end

local Firecracker = Object:extend()
function Firecracker:init(args)
	self.body = love.physics.newBody(Physics.world, args.position.x, args.position.y, 'dynamic')
	self.shape = love.physics.newCircleShape(5)
	self.fixture = love.physics.newFixture(self.body, self.shape, 1)
	local velocity = (args.target - args.position) * 5
	self.body:setLinearVelocity(velocity.x, velocity.y)
	self.body:setLinearDamping(5)
	local ang = (math.random() - 0.5) * math.pi * 2
	self.body:setAngularVelocity(ang)
	self.body:setAngularDamping(1)
	self.fixture:setRestitution(0.9)
	self.fixture:setGroupIndex(-1)

	self.alive = true
	self.timer = Timer {
		timeout = 3,
		autostart = false,
		callback = function()
			SFX:play('firecracker')
			local position = vec2 { self.body:getPosition() }
			table.insert(level.entities, FirecrackerDust { position = position })
			local neaby = Physics:get_entities_at(position, 100)
			for _, agent in ipairs(neaby) do
				if agent.components.hearing then
					agent.components.hearing:process_noise({ position = position })
				end
			end
			self.alive = false
		end
	}
	self.timer:start()
end

function Firecracker:draw()
	local point = vec2 { self.body:getPosition() }
	Assets.images.firecracker:draw(point, self.body:getAngle())
end

function Firecracker:update(delta)
	if self.alive then
		self.timer:increment(delta)
	end
end

return {
	Firecracker = Firecracker,
	Door = Door,
	PressurePlate = PressurePlate,
	ExitZone = ExitZone,
	Treasure = Treasure,
	FirecrackerDust =
		FirecrackerDust
}
