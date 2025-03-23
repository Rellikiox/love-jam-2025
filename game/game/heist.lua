local Assets = require 'game.assets'
local Physics = require 'game.physics'
local Agents = require 'game.agents'
local ldtk = require 'lib.ldtk'
local Terebi = require 'lib.terebi'
local Commands = require 'game.commands'
local Events = require 'engine.events'
local Pathfinding = require 'game.pathfinding'
local Entities = require 'game.entities'
local Cursor = require 'game.cursor'


local Heist = Object:extend()

function Heist:init(args)
	self.id = ''
	self.name = ''
	self.offset = vec2.zero
	self.layers = {}
	self.agents = {}
	self.entities = {}
	self.spawn_points = {}
	self.pathfinding = Pathfinding {}
	self.simulation_running = false
	self.entity_references = {}
	self.doors = {}
	self.plates = {}
	self.has_started = false
	self.simulation_timer = 0
	self.firecrackers_used = 0
	self.remaining_goblins = 0
	self.starting_goblins = 0
	self.treasure_obtained = 0
	self.total_treasure = 0
end

function Heist:reset_simulation()
	self.simulation_running = false
	self.simulation_timer = 0
	self.firecrackers_used = 0
	self.remaining_goblins = #self.spawn_points
	self.treasure_obtained = 0

	for index = #self.entities, 1, -1 do
		local entity = self.entities[index]
		if entity:is(Entities.FirecrackerDust) then
			table.remove(self.entities, index)
		elseif entity:is(Entities.Firecracker) then
			table.remove(self.entities, index)
		elseif entity:is(Entities.Treasure) then
			entity.looted = false
		elseif entity:is(Entities.Door) then
			entity:close()
		elseif entity:is(Entities.PressurePlate) then
			entity.pressed = false
		end
	end

	for _, agent in ipairs(self.agents) do
		if agent.is_goblin then
			for _, command in ipairs(agent.commands) do
				command:reset()
			end
		else
			for index = #agent.commands, 1, -1 do
				local command = agent.commands[index]
				if command:is(Commands.Patrol) then
					command:reset()
				else
					table.remove(agent.commands, index)
				end
			end
		end
		for component_name, component in pairs(agent.components) do
			component:reset()
		end
		agent.captured = false
		agent.current_command = 1
		agent.direction = vec2.left
		agent.position = agent.spawn_position
		agent.body:setPosition(agent.position.x, agent.position.y)
		agent.body:setLinearVelocity(0, 0)
		agent.body:setAngularVelocity(0, 0)
	end
end

function Heist:mouse_position()
	return vec2 { screen:getMousePosition() } - self.offset
end

function Heist:toggle_simulation()
	if not self.has_started then
		self.simulation_running = true
		self.simulation_timer = 0
		self.has_started = true
	else
		self.simulation_running = not self.simulation_running
	end
end

function Heist:load_entities(entities)
	for _, entity in ipairs(entities) do
		self:load_entity(entity)
	end
end

function Heist:load_layers(layers)
	for _, layer in ipairs(layers) do
		self:load_layer(layer)
	end
end

function Heist:load_entity(ldtk_entity)
	local entity = nil
	if ldtk_entity.id == 'Pressure_plate' then
		entity = Entities.PressurePlate {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
		}
		self.plates[entity] = ldtk_entity.props.Device.entityIid
		table.insert(self.entities, entity)
	elseif ldtk_entity.id == 'Door_H' then
		entity = Entities.Door {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
			is_horizontal = true
		}
		self.doors[ldtk_entity.iid] = entity
		table.insert(self.entities, entity)
	elseif ldtk_entity.id == 'Door_V' then
		entity = Entities.Door {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
			is_horizontal = false
		}
		self.doors[ldtk_entity.iid] = entity
		table.insert(self.entities, entity)
	elseif ldtk_entity.id == 'Treasure' then
		table.insert(self.entities, Entities.Treasure {
			position = vec2 { ldtk_entity.x, ldtk_entity.y }
		})
		self.total_treasure = self.total_treasure + 1
	elseif ldtk_entity.id == 'Exit' then
		table.insert(self.entities, Entities.ExitZone {
			position = vec2 { ldtk_entity.x, ldtk_entity.y }
		})
	elseif ldtk_entity.id == 'Spawn' then
		table.insert(self.spawn_points, vec2 { ldtk_entity.x, ldtk_entity.y })
		self.starting_goblins = self.starting_goblins + 1
	elseif ldtk_entity.id == 'Enemy' then
		local points = {}
		local commands = {}
		for _, point in ipairs(ldtk_entity.props.Patrol) do
			table.insert(points, vec2 { point.cx + 0.5, point.cy + 0.5 } * 32)
		end
		if #points > 0 then
			table.insert(commands, Commands.Patrol { points = points })
		end
		local position
		if #points > 0 then
			position = points[1]
		else
			position = vec2 { ldtk_entity.x, ldtk_entity.y }
		end

		table.insert(self.agents, Agents.Agent {
			name = ldtk_entity.id,
			position = position,
			quad = Assets.images.enemy,
			radius = 20,
			is_goblin = false,
			commands = commands,
			components = {
				Agents.Hearing {},
				Agents.Vision { range = 100, angle = math.pi / 4 },
				Agents.Capture { range = 20 },
				Agents.BeingNosy {},
			},
			speed = 6500
		})
	end
end

function Heist:treasure_at(position)
	for _, entity in ipairs(self.entities) do
		if entity:is(Entities.Treasure) and not entity.looted then
			if entity.position:distance(position) <= 16 then
				return entity
			end
		end
	end
	return nil
end

function Heist:load_layer(layer)
	if layer.id == 'Tiles' then
		self.pathfinding:process_tiles(layer.tiles)
	end

	for _, tile in ipairs(layer.tiles) do
		if tile.t == 32 then
			Physics:make_wall(vec2 { tile.px[1], tile.px[2] })
		end
	end
	table.insert(self.layers, layer)
end

function Heist:load_level(ldtk_level)
	self.entity_references = {}

	self.name = ldtk_level.props.name
	self.offset = vec2 {
		(game_size.x - ldtk_level.width) / 2,
		(game_size.y - ldtk_level.height) / 2,
	}
	self.layers = {}
	self.agents = {}
	self.entities = {}
	self.spawn_points = {}
	self.simulation_running = false
	self.pathfinding = Pathfinding {}
	Cursor:set_mode(Cursor.CursorMode.Select)
	Physics:load()
end

function Heist:create_level(ldtk_level)
	self.id = ldtk_level.id
	for plate, door in pairs(self.plates) do
		plate:set_device(self.doors[door])
	end

	for _, point in ipairs(self.spawn_points) do
		table.insert(self.agents, Agents.Agent {
			name = 'Goblin',
			position = point,
			quad = Assets.images.goblin,
			radius = 10,
			is_goblin = true,
			commands = {},
			components = {},
			speed = 8000
		})
	end
	self.remaining_goblins = self.starting_goblins
end

function love.load()
	Terebi.initializeLoveDefaults()

	screen = Terebi.newScreen(game_size.x, game_size.y, 2)
		:setBackgroundColor(Colors.Purple.r, Colors.Purple.g, Colors.Purple.b)
	love.graphics.setBackgroundColor(unpack(Colors.Purple:to_array()))

	Assets:load()
	Physics:load()

	Events:listen(nil, 'launch-firecracker', function(from, to)
		table.insert(self.entities, Entities.Firecracker { position = from, target = to })
	end)


	ldtk:load('assets/levels.ldtk')
	ldtk:goTo(1)
end

function Heist:update(delta)
	if not self.simulation_running then
		return
	end
	self.simulation_timer = self.simulation_timer + delta

	Physics.world:update(delta)

	for i = #self.entities, 1, -1 do
		local entity = self.entities[i]
		entity:update(delta)
		if not entity.alive then
			table.remove(self.entities, i)
			if entity.body then
				entity.body:destroy()
			end
		end
	end

	for _, agent in ipairs(self.agents) do
		agent:update(delta)
	end
end

function Heist:draw()
	-- Level title
	love.graphics.setFont(FontSmall)
	local text = 'This is how we\'re gonna rob'
	local subtitle_position = vec2 { (game_size.x - FontSmall:getWidth(text)) / 2, 0 }
	draw_shadow_text(text, subtitle_position, 2)
	love.graphics.setFont(FontMedium)
	local title_position = vec2 {
		(game_size.x - FontMedium:getWidth(self.name)) / 2, 10
	}
	draw_shadow_text(self.name, title_position, 3)


	love.graphics.push()
	love.graphics.translate(self.offset.x, self.offset.y)
	for _, layer in ipairs(self.layers) do
		layer:draw()
	end

	for _, entity in ipairs(self.entities) do
		entity:draw()
	end

	for _, agent in ipairs(self.agents) do
		if agent.commands then
			agent:draw_commands(agent == Cursor.selected_agent)
		end
	end
	for _, agent in ipairs(self.agents) do
		agent:draw()
	end

	-- Colors.Red:set()
	-- for _, body in ipairs(Physics.world:getBodies()) do
	-- 	local x, y = body:getPosition()
	-- 	love.graphics.circle("line", x, y, 20)
	-- end


	love.graphics.pop()

	Colors.White:set()
	love.graphics.setFont(FontMedium)
	local y_pos = 25
	draw_shadow_text(seconds_to_time(self.simulation_timer), vec2 { 25, y_pos }, 2)
	y_pos = y_pos + FontMedium:getHeight()
	love.graphics.setFont(FontSmall)
	draw_shadow_text(self.treasure_obtained .. '/' .. self.total_treasure .. ' Treasures', vec2 { 25, y_pos }, 2)
	y_pos = y_pos + FontSmall:getHeight()
	draw_shadow_text(self.remaining_goblins .. '/' .. self.starting_goblins .. ' Goblins', vec2 { 25, y_pos }, 2)
	y_pos = y_pos + FontSmall:getHeight()
	draw_shadow_text(self.firecrackers_used .. ' Firecrackers used', vec2 { 25, y_pos }, 2)

	Colors.FullWhite:set()
end

function Heist:handle_keyreleased(key)
	if key == 'space' then
		level:toggle_simulation()
	elseif key == 'r' then
		level:reset_simulation()
	end
end

return Heist
