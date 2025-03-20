require 'game.globals'
local Assets = require 'game.assets'
local Physics = require 'game.physics'
local Agents = require 'game.agents'
local ldtk = require 'lib.ldtk'
local Terebi = require 'lib.terebi'
local Commands = require 'game.commands'
local Events = require 'engine.events'
local Pathfinding = require 'game.pathfinding'

game_size = vec2 { 800, 600 }
level = nil

local PressurePlate = Object:extend()

function PressurePlate:init(args)
	self.position = args.position
	self.alive = true
	self.device = args.device
	self.pressed = false
end

function PressurePlate:update(delta)
	local entities = Physics:get_entities_at(self.position, 5)
	local was_pressed = self.pressed
	self.pressed = false
	for _, entity in ipairs(entities) do
		if entity.is_goblin then
			self.pressed = true
			break
		end
	end

	if was_pressed and not self.pressed then
		self.device:close()
	end
	if not was_pressed and self.pressed then
		self.device:open()
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
end

function Door:update(delta)
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
			local position = vec2 { self.body:getPosition() }
			table.insert(level.agents, FirecrackerDust { position = position })
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

level = {
	name = '',
	offset = vec2.zero,
	layers = {},
	agents = {},
	entities = {},
	pathfinding = nil,
	simulation_running = false,
	mouse_position = function(self)
		return vec2 { screen:getMousePosition() } - self.offset
	end,
	toggle_simulation = function(self)
		self.simulation_running = not self.simulation_running
	end,
}

local CusorMode = {
	Select = 'Select',
	MoveCommand = 'Move',
	DistractCommand = 'Firecracker From',
	DistractTarget = 'Firecracker To',
	WaitCommand = 'Wait',
	WaitTimer = 'Wait Time',
	EditCommandPosition = 'Edit position',
	EditCommandValue = 'Edit Value',
	ListenCommand = 'Listen',
	ShoutCommand = 'Shout',
	InteractCommand = 'Interact',
}

local Cursor = {
	hand = love.mouse.getSystemCursor("hand"),
	arrow = love.mouse.getSystemCursor("arrow"),
	selected_agent = nil,
	selected_command = nil,
	mode = CusorMode.Select,
	set_hand = function(self)
		love.mouse.setCursor(self.hand)
	end,
	set_arrow = function(self)
		love.mouse.setCursor(self.arrow)
	end,
	mouse_1_released = function(self)
		if self.mode == CusorMode.Select then
			-- Look for an agent first
			for _, agent in ipairs(level.agents) do
				if agent.position:distance(level:mouse_position()) <= agent.radius then
					self.selected_agent = agent
					self:set_mode(CusorMode.MoveCommand)
					return
				end
			end

			-- Otherwise look for a command

			for _, agent in ipairs(level.agents) do
				if agent.is_goblin then
					for _, command in ipairs(agent.commands) do
						if command.position:distance(level:mouse_position()) <= 10 then
							self.selected_command = command
							self:set_mode(CusorMode.EditCommandPosition)
							return
						end
					end
				end
			end
		elseif self.mode == CusorMode.MoveCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.MoveCommand)
		elseif self.mode == CusorMode.DistractCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end

			self:set_mode(CusorMode.DistractTarget)
		elseif self.mode == CusorMode.DistractTarget then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.DistractCommand)
		elseif self.mode == CusorMode.WaitCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end

			self:set_mode(CusorMode.WaitTimer)
		elseif self.mode == CusorMode.WaitTimer then
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.WaitCommand)
		elseif self.mode == CusorMode.EditCommandPosition then
			if self.selected_command:is(Commands.ThrowFirecracker) or self.selected_command:is(Commands.Wait) then
				self:set_mode(CusorMode.EditCommandValue)
			else
				self:set_mode(CusorMode.Select)
			end
		elseif self.mode == CusorMode.EditCommandValue then
			self:set_mode(CusorMode.Select)
		elseif self.mode == CusorMode.ListenCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.ListenCommand)
		elseif self.mode == CusorMode.ShoutCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.ShoutCommand)
		elseif self.mode == CusorMode.InteractCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.InteractCommand)
		end
	end,
	mouse_2_released = function(self)
		self.selected_agent = nil
		self:set_mode(CusorMode.Select)
	end,
	set_mode = function(self, mode)
		if mode == CusorMode.Select then
			self.mode = mode
			self.next_command = nil
			self.selected_agent = nil
			self.selected_command = nil
			return
		elseif mode == CusorMode.EditCommandPosition then
			self.mode = mode
			return
		elseif mode == CusorMode.EditCommandValue then
			self.mode = mode
			return
		end

		if not self.selected_agent then
			return
		end

		self.mode = mode
		local source = self.selected_agent:next_command_source()
		local position = level:mouse_position()
		if mode == CusorMode.MoveCommand then
			self.next_command = Commands.Move { source = source, position = position }
		elseif mode == CusorMode.DistractCommand then
			self.next_command = Commands.ThrowFirecracker { source = source, position = position }
		elseif mode == CusorMode.WaitCommand then
			self.next_command = Commands.Wait { source = source, position = position }
		elseif mode == CusorMode.ListenCommand then
			self.next_command = Commands.Listen { source = source, position = position }
		elseif mode == CusorMode.ShoutCommand then
			self.next_command = Commands.Shout { source = source, position = position }
		elseif mode == CusorMode.InteractCommand then
			self.next_command = Commands.Interact { source = source, position = position }
		end
	end,
	current_command_is_valid = function(self)
		if not self.next_command then
			return true
		end

		local from, to
		if self.mode == CusorMode.MoveCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.DistractCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.DistractTarget then
			return true
		elseif self.mode == CusorMode.WaitCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.WaitTimer then
			local length = (self.next_command.position - level:mouse_position()):length()
			return length >= 2
		elseif self.mode == CusorMode.EditCommandPosition then
			-- TODO check that we don't overlap any walls with before and after commands
			return true
		elseif self.mode == CusorMode.EditCommandValue then
			return true
		elseif self.mode == CusorMode.ListenCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.ShoutCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.InteractCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		end
		return level.pathfinding:get_path(from, to) ~= nil
	end,
	draw = function(self)
		if self.next_command then
			if self:current_command_is_valid() then
				Colors.Black:set()
			else
				Colors.Red:set()
			end
			self.next_command:draw_path()
			self.next_command:draw_marker()
		end
		if self.selected_agent then
			Assets.images.selected_marker:draw(self.selected_agent.position)
		end
		if self.selected_command then
			Assets.images.selected_marker:draw(self.selected_command.position + vec2 { 0, 10 })
		end

		local position = level:mouse_position():floor()
		love.graphics.setFont(FontTiny)
		Colors.Black:set()
		love.graphics.rectangle("fill", position.x + 12, position.y - 3, FontTiny:getWidth(self.mode) + 5, 13)
		Colors.White:set()
		love.graphics.print(self.mode, position.x + 15, position.y - 5
		)
	end,
	update = function(self, delta)
		if not self:current_command_is_valid() then
			return
		end
		if self.mode == CusorMode.Select then
		elseif self.mode == CusorMode.MoveCommand then
			self.next_command.position = level:mouse_position()
			self.next_command:set_path(level.pathfinding:get_path(self.next_command.source.position,
				level:mouse_position()))
		elseif self.mode == CusorMode.DistractCommand then
			self.next_command.position = level:mouse_position()
			self.next_command:set_path(level.pathfinding:get_path(self.next_command.source.position,
				level:mouse_position()))
		elseif self.mode == CusorMode.DistractTarget then
			self.next_command.target = level:mouse_position()
		elseif self.mode == CusorMode.WaitCommand then
			self.next_command.position = level:mouse_position()
			self.next_command:set_path(level.pathfinding:get_path(self.next_command.source.position,
				level:mouse_position()))
		elseif self.mode == CusorMode.WaitTimer then
			local wait_time = (self.next_command.position - level:mouse_position()):length() / 20
			if wait_time >= 0.1 then
				local wait_time = math.min(wait_time, 5.0)
				self.next_command:set_wait_time(wait_time)
			end
		elseif self.mode == CusorMode.EditCommandPosition then
			self.selected_command.position = level:mouse_position()
			self.selected_command:set_path(level.pathfinding:get_path(self.selected_command.source.position,
				level:mouse_position()))
		elseif self.mode == CusorMode.EditCommandValue then
			if self.selected_command:is(Commands.ThrowFirecracker) then
				self.selected_command.target = level:mouse_position()
			elseif self.selected_command:is(Commands.Wait) then
				local wait_time = (self.selected_command.position - level:mouse_position()):length() / 20
				if wait_time >= 0.1 then
					local wait_time = math.min(wait_time, 5.0)
					self.selected_command:set_wait_time(wait_time)
				end
			end
		elseif self.mode == CusorMode.ListenCommand then
			self.next_command.position = level:mouse_position()
			self.next_command:set_path(level.pathfinding:get_path(self.next_command.source.position,
				level:mouse_position()))
		elseif self.mode == CusorMode.ShoutCommand then
			self.next_command:set_path(level.pathfinding:get_path(self.next_command.source.position,
				level:mouse_position()))
			self.next_command.position = level:mouse_position()
		elseif self.mode == CusorMode.InteractCommand then
			self.next_command:set_path(level.pathfinding:get_path(self.next_command.source.position,
				level:mouse_position()))
			self.next_command.position = level:mouse_position()
		end
	end,
	delete_current_command = function(self)
		if self.selected_command then
			local agent = self.selected_command.agent
			-- source is entity owning commands
			for index = 1, #agent.commands do
				if agent.commands[index] == self.selected_command then
					if index ~= #agent.commands then
						local previous = self.selected_command.source
						local next = agent.commands[index + 1]
						next.source = previous
					end
					table.remove(agent.commands, index)
				end
			end
			self.selected_command = nil
			self:set_mode(CusorMode.Select)
		end
	end
}

local cursor_mode_text = {
	[CusorMode.Select] = function() return 'Now, who did I send next? ...' end,
	[CusorMode.MoveCommand] = function() return Cursor.selected_agent.name .. ' should go here' end,
	[CusorMode.DistractCommand] = function() return Cursor.selected_agent.name .. ' should walk here and then...' end,
	[CusorMode.DistractTarget] = function() return 'throw a firecracker over here.' end,
	[CusorMode.WaitCommand] = function() return Cursor.selected_agent.name .. ' should walk here and...' end,
	[CusorMode.WaitTimer] = function() return 'wait for ' .. Cursor.next_command.wait_time .. ' seconds.' end,
	[CusorMode.EditCommandPosition] = function() return 'Actually, I changed my mind about this...' end,
	[CusorMode.EditCommandValue] = function() return 'It should actually be...' end,
	[CusorMode.ListenCommand] = function()
		return Cursor.selected_agent.name ..
			' should wait to hear from the others.'
	end,
	[CusorMode.ShoutCommand] = function()
		return Cursor.selected_agent.name ..
			' should let the other know they\'re ready.'
	end,
	[CusorMode.InteractCommand] = function()
		return Cursor.selected_agent.name .. ' should interact with this item'
	end,
}

entity_references = {}

function ldtk.onEntity(ldtk_entity)
	local entity = nil
	if ldtk_entity.id == 'Pressure_plate' then
		entity = PressurePlate {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
		}
		if entity_references[ldtk_entity.props.Device.entityIid] then
			entity.device = entity_references[ldtk_entity.props.Device.entityIid]
		else
			entity_references[ldtk_entity.props.Device.entityIid] = entity
		end
	elseif ldtk_entity.id == 'Door_H' then
		entity = Door {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
			is_horizontal = true
		}
	elseif ldtk_entity.id == 'Door_V' then
		entity = Door {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
			is_horizontal = false
		}
	end

	if entity then
		if entity_references[ldtk_entity.iid] then
			entity_references[ldtk_entity.iid].device = entity
		else
			entity_references[ldtk_entity.iid] = entity
		end
		table.insert(level.entities, entity)
		return
	end

	-- Is an agent


	local quad
	local commands = {}
	local components = {}
	local speed = 6000
	if ldtk_entity.id == 'Sneaky' then
		quad = Assets.images.sneaky
	elseif ldtk_entity.id == 'Brute' then
		quad = Assets.images.brute
	elseif ldtk_entity.id == 'Trickster' then
		quad = Assets.images.trickster
	elseif ldtk_entity.id == 'Enemy' then
		quad = Assets.images.enemy
		local points = {}
		for _, point in ipairs(ldtk_entity.props.Patrol) do
			table.insert(points, vec2 { point.cx + 0.5, point.cy + 0.5 } * 32)
		end
		if #points > 0 then
			table.insert(commands, Commands.Patrol { points = points })
		end

		table.insert(components, Agents.Hearing {})
		table.insert(components, Agents.Vision { range = 100, angle = math.pi / 4 })
		table.insert(components, Agents.Capture { range = 20 })
		table.insert(components, Agents.BeingNosy {})
		speed = 5000
	end

	table.insert(level.agents, Agents.Agent {
		name = ldtk_entity.id,
		position = vec2 { ldtk_entity.x, ldtk_entity.y },
		quad = quad,
		radius = ldtk_entity.width / 2,
		is_goblin = ldtk_entity.id ~= 'Enemy',
		commands = commands,
		components = components,
		speed = speed
	})
end

function ldtk.onLayer(layer)
	if layer.id == 'Tiles' then
		level.pathfinding:process_tiles(layer.tiles)
	end

	for _, tile in ipairs(layer.tiles) do
		if tile.t == 32 then
			Physics:make_wall(vec2 { tile.px[1], tile.px[2] })
		end
	end
	table.insert(level.layers, layer)
end

function ldtk.onLevelLoaded(ldtk_level)
	entity_references = {}

	level.name = string.gsub(ldtk_level.id, '_', ' ')
	level.offset = vec2 {
		(game_size.x - ldtk_level.width) / 2,
		(game_size.y - ldtk_level.height) / 2,
	}
	level.layers = {}
	level.agents = {}
	level.entities = {}
	level.simulation_running = false
	level.pathfinding = Pathfinding {}
	Cursor:set_mode(CusorMode.Select)
	Physics:load()
end

function ldtk.onLevelCreated(ldtk_level)
end

function love.load()
	Terebi.initializeLoveDefaults()

	screen = Terebi.newScreen(game_size.x, game_size.y, 2)
		:setBackgroundColor(Colors.Purple.r, Colors.Purple.g, Colors.Purple.b)
	love.graphics.setBackgroundColor(unpack(Colors.Purple:to_array()))

	Assets:load()
	Physics:load()

	Events:listen(nil, 'launch-firecracker', function(from, to)
		table.insert(level.entities, Firecracker { position = from, target = to })
	end)


	ldtk:load('assets/levels.ldtk')
	ldtk:goTo(1)
end

function love.update(delta)
	Cursor:update(delta)

	if not level or not level.simulation_running then
		return
	end

	Physics.world:update(delta)

	for i = #level.entities, 1, -1 do
		local entity = level.entities[i]
		entity:update(delta)
		if not entity.alive then
			table.remove(level.entities, i)
			if entity.body then
				entity.body:destroy()
			end
		end
	end

	for _, agent in ipairs(level.agents) do
		agent:update(delta)
	end
end

function love.draw()
	screen:draw(
		function()
			if not level then
				return
			end

			-- Level title
			love.graphics.setFont(FontSmall)
			local text = 'This is how we\'re gonna rob'
			local subtitle_position = vec2 { (game_size.x - FontSmall:getWidth(text)) / 2, 0 }
			draw_shadow_text(text, subtitle_position, 2)
			love.graphics.setFont(FontMedium)
			local title_position = vec2 {
				(game_size.x - FontMedium:getWidth(level.name)) / 2, 10
			}
			draw_shadow_text(level.name, title_position, 3)

			-- Current mouse mode
			love.graphics.setFont(FontSmall)
			draw_shadow_text(cursor_mode_text[Cursor.mode](), vec2 { 25, game_size.y - 50 }, 2)


			love.graphics.push()
			love.graphics.translate(level.offset.x, level.offset.y)
			for _, layer in ipairs(level.layers) do
				layer:draw()
			end

			Cursor:draw()

			for _, entity in ipairs(level.entities) do
				entity:draw()
			end

			for _, agent in ipairs(level.agents) do
				if agent.commands then
					agent:draw_commands(agent == Cursor.selected_agent)
				end
			end
			for _, agent in ipairs(level.agents) do
				agent:draw()
			end

			-- Colors.Red:set()
			-- for _, body in ipairs(Physics.world:getBodies()) do
			-- 	local x, y = body:getPosition()
			-- 	love.graphics.circle("line", x, y, 20)
			-- end

			Colors.FullWhite:set()

			level.pathfinding:draw()

			love.graphics.pop()
		end)
end

function love.keyreleased(key)
	if key == ']' then
		ldtk:next()
	elseif key == '[' then
		ldtk:previous()
	elseif key == 'space' then
		level:toggle_simulation()
	elseif key == 'm' then
		Cursor:set_mode(CusorMode.MoveCommand)
	elseif key == 'd' then
		Cursor:set_mode(CusorMode.DistractCommand)
	elseif key == 'w' then
		Cursor:set_mode(CusorMode.WaitCommand)
	elseif key == 'h' then
		Cursor:set_mode(CusorMode.ListenCommand)
	elseif key == 's' then
		Cursor:set_mode(CusorMode.ShoutCommand)
	elseif key == 'e' then
		Cursor:set_mode(CusorMode.InteractCommand)
	elseif key == 'r' then
		ldtk:reload()
	elseif key == 'delete' or key == 'backspace' then
		Cursor:delete_current_command()
	end
end

function love.mousemoved(x, y, dx, dy, istouch)
	local entities = Physics:get_entities_at(level:mouse_position())
	if #entities > 0 then
		Cursor:set_hand()
	else
		Cursor:set_arrow()
	end
end

function love.mousereleased(x, y, button)
	if button == 1 then
		Cursor:mouse_1_released()
	elseif button == 2 then
		Cursor:mouse_2_released()
	end
end

function love.resize(w, h)
	screen:handleResize()
end
