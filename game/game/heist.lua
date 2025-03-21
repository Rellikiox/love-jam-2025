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
	self.name = ''
	self.offset = vec2.zero
	self.layers = {}
	self.agents = {}
	self.entities = {}
	self.spawn_points = {}
	self.pathfinding = nil
	self.simulation_running = false
	self.entity_references = {}
end

function Heist:mouse_position()
	return vec2 { screen:getMousePosition() } - self.offset
end

function Heist:toggle_simulation()
	self.simulation_running = not self.simulation_running
end

function Heist:load_entity(ldtk_entity)
	print('entity')

	local entity = nil
	if ldtk_entity.id == 'Pressure_plate' then
		entity = Entities.PressurePlate {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
		}
		if self.entity_references[ldtk_entity.props.Device.entityIid] then
			entity.device = self.entity_references[ldtk_entity.props.Device.entityIid]
		else
			self.entity_references[ldtk_entity.props.Device.entityIid] = entity
		end
	elseif ldtk_entity.id == 'Door_H' then
		entity = Entities.Door {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
			is_horizontal = true
		}
	elseif ldtk_entity.id == 'Door_V' then
		entity = Entities.Door {
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
			is_horizontal = false
		}
	end

	if entity then
		if self.entity_references[ldtk_entity.iid] then
			self.entity_references[ldtk_entity.iid].device = entity
		else
			self.entity_references[ldtk_entity.iid] = entity
		end
		table.insert(level.entities, entity)
		return
	end

	-- Is an agent
	if ldtk_entity.id == 'Treasure' then
		table.insert(level.entities, Entities.Treasure {
			position = vec2 { ldtk_entity.x, ldtk_entity.y }
		})
	elseif ldtk_entity.id == 'Exit' then
		table.insert(level.entities, Entities.ExitZone {
			position = vec2 { ldtk_entity.x, ldtk_entity.y }
		})
	elseif ldtk_entity.id == 'Spawn' then
		table.insert(level.spawn_points, vec2 { ldtk_entity.x, ldtk_entity.y })
	elseif ldtk_entity.id == 'Enemy' then
		local points = {}
		local commands = {}
		for _, point in ipairs(ldtk_entity.props.Patrol) do
			table.insert(points, vec2 { point.cx + 0.5, point.cy + 0.5 } * 32)
		end
		if #points > 0 then
			table.insert(commands, Commands.Patrol { points = points })
		end

		table.insert(level.agents, Agents.Agent {
			name = ldtk_entity.id,
			position = vec2 { ldtk_entity.x, ldtk_entity.y },
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
	print('layer')
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

function Heist:load_level(ldtk_level)
	print('loaded')

	self.entity_references = {}

	self.name = string.gsub(ldtk_level.id, '_', ' ')
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
	print('created')
	for _, point in ipairs(level.spawn_points) do
		table.insert(level.agents, Agents.Agent {
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
end

function love.load()
	Terebi.initializeLoveDefaults()

	screen = Terebi.newScreen(game_size.x, game_size.y, 2)
		:setBackgroundColor(Colors.Purple.r, Colors.Purple.g, Colors.Purple.b)
	love.graphics.setBackgroundColor(unpack(Colors.Purple:to_array()))

	Assets:load()
	Physics:load()

	Events:listen(nil, 'launch-firecracker', function(from, to)
		table.insert(level.entities, Entities.Firecracker { position = from, target = to })
	end)


	ldtk:load('assets/levels.ldtk')
	ldtk:goTo(1)
end

function Heist:update(delta)
	if not self.simulation_running then
		return
	end

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

	Colors.FullWhite:set()

	love.graphics.pop()
end

function Heist:handle_keyreleased(key)
	if key == 'space' then
		level:toggle_simulation()
	end
end

return Heist
