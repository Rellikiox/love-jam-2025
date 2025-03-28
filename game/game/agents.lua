local Assets = require 'game.assets'
local Physics = require 'game.physics'
local Commands = require 'game.commands'
local Events = require 'engine.events'

local Agent = Object:extend()

function Agent:init(args)
	self.alive = true
	self.name = args.name
	self.position = args.position
	self.spawn_position = args.position
	self.direction = vec2.left
	self.current_command = 1
	self.quad = args.quad
	self.radius = args.radius
	self.is_goblin = args.is_goblin
	self.speed = args.speed
	self.components = {}
	for _, component in ipairs(args.components) do
		component.parent = self
		self.components[component.name] = component
	end
	self.commands = {}
	for _, command in ipairs(args.commands or {}) do
		self:add_command(command)
	end

	-- Add physics for picking and collission detection
	self.body = love.physics.newBody(Physics.world, self.position.x, self.position.y, 'dynamic')
	self.shape = love.physics.newCircleShape(10)
	self.fixture = love.physics.newFixture(self.body, self.shape, 1)
	self.fixture:setUserData(self)
	self.fixture:setGroupIndex(-1)
	self.body:setLinearDamping(10)
end

function Agent:update(delta)
	if self.captured then
		return
	end

	self.position = vec2 { self.body:getPosition() }
	local new_direction = vec2 { self.body:getLinearVelocity() }:normalized()
	if new_direction ~= vec2.zero then
		self.direction = new_direction
	end

	for _, component in pairs(self.components) do
		component:update(delta)
	end

	if self.current_command > #self.commands then
		return
	end

	local command_state = self.commands[self.current_command]:update(delta)
	if command_state == Commands.State.Finished then
		self.current_command = self.current_command + 1
	elseif command_state == Commands.State.Destroy then
		table.remove(self.commands, self.current_command)
	end
end

function Agent:draw()
	for _, component in pairs(self.components) do
		component:draw()
	end
	if self.captured then
		Assets.images.captured:draw(self.position)
	else
		self.quad:draw(self.position)
	end
end

function Agent:draw_commands(is_selected)
	if is_selected then
		Colors.Black:set()
	else
		Colors.Black:with_alpha(0.3):set()
	end
	for _, command in ipairs(self.commands) do
		command:draw_path()
	end

	if is_selected then
		Colors.FullWhite:set()
	else
		Colors.FullWhite:with_alpha(0.3):set()
	end
	for _, command in ipairs(self.commands) do
		command:draw_marker()
	end
	Colors.FullWhite:set()
end

function Agent:add_command(command, position)
	position = position or #self.commands + 1
	command.agent = self
	table.insert(self.commands, position, command)
end

function Agent:next_command_source()
	if #self.commands == 0 then
		return { position = self.position }
	end
	return self.commands[#self.commands]
end

function Agent:capture()
	self.captured = true
	self.body:setLinearVelocity(0, 0)
end

local Component = Object:extend()

function Component:init(args)
	self.name = 'component'
end

function Component:update(delta)
end

function Component:draw()
end

local BeingNosyComponent = Component:extend()

function BeingNosyComponent:init(args)
	self.name = 'nosy'
	self.investigation_command = nil
end

function BeingNosyComponent:reset()
	self.investigation_command = nil
end

function BeingNosyComponent:update(delta)
	local target = nil
	if #self.parent.components.vision.entities_in_vision > 0 then
		target = self.parent.components.vision.entities_in_vision[1].position
	elseif #self.parent.components.hearing.noises > 0 then
		local noise = table.remove(self.parent.components.hearing.noises, 1)
		target = noise.position
	end

	if target then
		if self.investigation_command and self.investigation_command.path[#self.investigation_command.path] ~= target then
			self.investigation_command = nil
			table.remove(self.parent.commands, 1)
		end
		if not self.investigation_command then
			local path = level.pathfinding:get_path(self.parent.position, target)
			if not path then
				return
			end
			self.investigation_command = Commands.Investigate { path = path }
			self.parent:add_command(self.investigation_command, 1)
		end
	end
end

local HearingComponent = Component:extend()

function HearingComponent:init(args)
	self.name = 'hearing'
	self.parent = nil
	self.noises = {}
end

function HearingComponent:reset()
	self.noises = {}
end

function HearingComponent:process_noise(noise)
	table.insert(self.noises, noise)
end

local VisionComponent = Component:extend()

function VisionComponent:init(args)
	self.name = 'vision'
	self.range = args.range
	self.angle = args.angle
	self.entities_in_vision = {}
	self.parent = nil
end

function VisionComponent:reset()
	self.entities_in_vision = {}
end

function VisionComponent:update(delta)
	self.entities_in_vision = {}
	local entities = Physics:get_entities_at(self.parent.position, self.range)
	for _, entity in ipairs(entities) do
		if entity.is_goblin and not entity.captured then
			local to_entity = entity.position - self.parent.position
			local angle_to_entity = to_entity:angle_between(self.parent.direction)
			if math.abs(angle_to_entity) <= self.angle / 2 then
				if Physics:is_line_unobstructed(self.parent.position, entity.position) then
					table.insert(self.entities_in_vision, entity)
				end
			end
		end
	end
end

function VisionComponent:draw()
	Colors.Red:with_alpha(0.3):set()
	local angle = self.parent.direction:angle()
	love.graphics.arc("fill", self.parent.position.x, self.parent.position.y, self.range,
		angle - self.angle / 2,
		angle + self.angle / 2)

	Colors.FullWhite:set()
end

local CaptureComponent = Component:extend()

function CaptureComponent:init(args)
	self.name = 'capture'
	self.range = args.range
	self.parent = nil
end

function CaptureComponent:reset()
end

function CaptureComponent:update(delta)
	local entities = Physics:get_entities_at(self.parent.position, self.range)
	for _, entity in ipairs(entities) do
		if entity.is_goblin then
			entity:capture()
			Events:send('goblin-captured', entity)
		end
	end
end

function CaptureComponent:draw()
	Colors.Red:with_alpha(0.6):set()
	love.graphics.circle("line", self.parent.position.x, self.parent.position.y, self.range)
	Colors.Red:with_alpha(0.3):set()
	love.graphics.circle("fill", self.parent.position.x, self.parent.position.y, self.range)
	Colors.FullWhite:set()
end

return {
	Agent = Agent,
	Hearing = HearingComponent,
	Vision = VisionComponent,
	Capture = CaptureComponent,
	BeingNosy = BeingNosyComponent
}
