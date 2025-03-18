require 'game.globals'
local Assets = require 'game.assets'
local Physics = require 'game.physics'
local Agents = require 'game.agents'
local ldtk = require 'lib.ldtk'
local Terebi = require 'lib.terebi'
local Commands = require 'game.commands'
local Events = require 'engine.events'

game_size = vec2 { 800, 600 }
local level

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

	self.alive = true
	self.timer = Timer {
		timeout = 3,
		autostart = false,
		callback = function()
			local position = vec2 { self.body:getPosition() }
			table.insert(level.agents, FirecrackerDust { position = position })
			local neaby = Physics:get_entities_at(position, 100)
			for _, ent in ipairs(neaby) do
				local hearing = ent:get_component(Agents.Hearing)
				if hearing then
					hearing:process_noise({ position = position })
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
	selected_agent = nil,
	simulation_running = false,
	mouse_position = function(self)
		return vec2 { screen:getMousePosition() } - self.offset
	end,
	start_simulation = function(self)
		self.simulation_running = true
	end,
}

local CusorMode = {
	Select = 'Select',
	MoveCommand = 'Move',
	DistractCommand = 'Distract',
	DistractTarget = 'Distract Target',
	WaitCommand = 'Wait',
	WaitTimer = 'Wait Time'
}

local Cursor = {
	hand = love.mouse.getSystemCursor("hand"),
	arrow = love.mouse.getSystemCursor("arrow"),
	selected_agent = nil,
	mode = CusorMode.Select,
	set_hand = function(self)
		love.mouse.setCursor(self.hand)
	end,
	set_arrow = function(self)
		love.mouse.setCursor(self.arrow)
	end,
	mouse_1_released = function(self)
		if self.mode == CusorMode.Select then
			local entities = Physics:get_entities_at(level:mouse_position())
			for _, entity in ipairs(entities) do
				if entity.is_goblin then
					self.selected_agent = entities[1]
					self:set_mode(CusorMode.MoveCommand)
					break
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
		end
	end,
	mouse_2_released = function(self)
		self.selected_agent = nil
		self:set_mode(CusorMode.Select)
	end,
	set_mode = function(self, mode)
		if mode ~= CusorMode.Select and not self.selected_agent then
			return
		end

		self.mode = mode
		if mode == CusorMode.Select then
			self.next_command = nil
			return
		end

		local source = self.selected_agent:next_command_position()
		local destination = level:mouse_position()
		if mode == CusorMode.MoveCommand then
			self.next_command = Commands.Move { source = source, destination = destination }
		elseif mode == CusorMode.DistractCommand then
			self.next_command = Commands.ThrowFirecracker { source = source, destination = destination }
		elseif mode == CusorMode.WaitCommand then
			self.next_command = Commands.Wait { source = source, destination = destination }
		end
	end,
	current_command_is_valid = function(self)
		if not self.next_command then
			return true
		end

		local from, to
		if self.mode == CusorMode.MoveCommand then
			from = self.selected_agent:next_command_position()
			to = level:mouse_position()
		elseif self.mode == CusorMode.DistractCommand then
			from = self.selected_agent:next_command_position()
			to = level:mouse_position()
		elseif self.mode == CusorMode.DistractTarget then
			return true
		elseif self.mode == CusorMode.WaitCommand then
			from = self.selected_agent:next_command_position()
			to = level:mouse_position()
		elseif self.mode == CusorMode.WaitTimer then
			local length = (self.next_command.destination - level:mouse_position()):length()
			return length >= 2
		end
		return (to - from):length() > 16 and Physics:is_line_unobstructed(from, to, self.selected_agent.radius)
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
	end,
	update = function(self, delta)
		if self.mode == CusorMode.Select then
		elseif self.mode == CusorMode.MoveCommand then
			self.next_command.destination = level:mouse_position()
		elseif self.mode == CusorMode.DistractCommand then
			self.next_command.destination = level:mouse_position()
		elseif self.mode == CusorMode.DistractTarget then
			self.next_command.target = level:mouse_position()
		elseif self.mode == CusorMode.WaitCommand then
			self.next_command.destination = level:mouse_position()
		elseif self.mode == CusorMode.WaitTimer then
			local wait_time = (self.next_command.destination - level:mouse_position()):length() / 20
			if wait_time >= 0.1 then
				local wait_time = math.min(wait_time, 5.0)
				self.next_command:set_wait_time(wait_time)
			end
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
}

function ldtk.onEntity(ldtk_entity)
	local quad
	local commands = nil
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
		commands = {
			Commands.Patrol { points = points }
		}
	end

	local components = {}
	if ldtk_entity.props.Components then
		for _, component_name in ipairs(ldtk_entity.props.Components) do
			table.insert(components, Agents[component_name] {})
		end
	end

	table.insert(level.agents, Agents.Agent {
		name = ldtk_entity.id,
		position = vec2 { ldtk_entity.x, ldtk_entity.y },
		quad = quad,
		radius = ldtk_entity.width / 2,
		is_goblin = ldtk_entity.id ~= 'Enemy',
		commands = commands,
		components = components
	})
end

function ldtk.onLayer(layer)
	for _, tile in ipairs(layer.tiles) do
		if tile.t == 32 then
			Physics:make_wall(vec2 { tile.px[1], tile.px[2] })
		end
	end
	table.insert(level.layers, layer)
end

function ldtk.onLevelLoaded(ldtk_level)
	level.name = string.gsub(ldtk_level.id, '_', ' ')
	level.offset = vec2 {
		(game_size.x - ldtk_level.width) / 2,
		(game_size.y - ldtk_level.height) / 2,
	}
	level.layers = {}
	level.agents = {}
	level.simulation_running = false
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
		end
	end

	for i = #level.agents, 1, -1 do
		local agent = level.agents[i]
		agent:update(delta)
		if not agent.alive then
			table.remove(level.agents, i)
		end
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

			love.graphics.pop()
		end)
end

function love.keyreleased(key)
	if key == ']' then
		ldtk:next()
	elseif key == '[' then
		ldtk:previous()
	elseif key == 'space' then
		level:start_simulation()
	elseif key == 'm' then
		Cursor:set_mode(CusorMode.MoveCommand)
	elseif key == 'd' then
		Cursor:set_mode(CusorMode.DistractCommand)
	elseif key == 'w' then
		Cursor:set_mode(CusorMode.WaitCommand)
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
