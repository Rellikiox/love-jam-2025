require 'game.globals'
local Assets = require 'game.assets'
local Physics = require 'game.physics'
local Entity = require 'game.entities'
local ldtk = require 'lib.ldtk'
local Terebi = require 'lib.terebi'
local Commands = require 'game.commands'

game_size = vec2 { 800, 600 }


local level = {
	name = '',
	offset = vec2.zero,
	layers = {},
	entities = {},
	selected_entity = nil,
	simulation_running = false,
	mouse_position = function(self)
		return vec2 { screen:getMousePosition() } - self.offset
	end,
	start_simulation = function(self)
		self.simulation_running = true
		print('start')
	end
}

local CusorMode = {
	Select = 'Select',
	IssueMoveCommand = 'Move'
}
local Cursor = {
	hand = love.mouse.getSystemCursor("hand"),
	arrow = love.mouse.getSystemCursor("arrow"),
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
					level.selected_entity = entities[1]
					self:set_mode(CusorMode.IssueMoveCommand)
					break
				end
			end
		elseif self.mode == CusorMode.IssueMoveCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			level.selected_entity:add_command(Commands.Move { source = level.selected_entity:next_command_position(), destination = level:mouse_position() })
		end
	end,
	mouse_2_released = function(self)
		level.selected_entity = nil
		self:set_mode(CusorMode.Select)
	end,
	set_mode = function(self, mode)
		self.mode = mode
	end,
	current_command_is_valid = function(self)
		if self.mode == CusorMode.IssueMoveCommand then
			local from = level.selected_entity:next_command_position()
			local to = level:mouse_position()
			return Physics:is_line_unobstructed(from, to, level.selected_entity.radius)
		end
	end
}

function ldtk.onEntity(ldtk_entity)
	local quad
	if ldtk_entity.id == 'Sneaky' then
		quad = Assets.images.sneaky
	elseif ldtk_entity.id == 'Brute' then
		quad = Assets.images.brute
	elseif ldtk_entity.id == 'Trickster' then
		quad = Assets.images.trickster
	elseif ldtk_entity.id == 'Enemy' then
		quad = Assets.images.enemy
	end

	table.insert(level.entities, Entity {
		position = vec2 { ldtk_entity.x, ldtk_entity.y },
		quad = quad,
		radius = ldtk_entity.width / 2,
		is_goblin = ldtk_entity.id ~= 'Enemy'
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
	level.entities = {}
	level.selected_entity = nil
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

	ldtk:load('assets/levels.ldtk')
	ldtk:goTo(1)
end

function love.update(delta)
	if not level or not level.simulation_running then
		return
	end

	for _, entity in ipairs(level.entities) do
		entity:update(delta)
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
			love.graphics.setFont(FontMedium)
			draw_shadow_text('Current mode: ' .. Cursor.mode, vec2 { 25, game_size.y - 50 }, 2)


			love.graphics.push()
			love.graphics.translate(level.offset.x, level.offset.y)
			for _, layer in ipairs(level.layers) do
				layer:draw()
			end

			if Cursor.mode == CusorMode.IssueMoveCommand then
				if Cursor:current_command_is_valid() then
					Colors.Black:set()
				else
					Colors.Red:set()
				end
				love.graphics.setLineWidth(5)
				local from = level.selected_entity:next_command_position()
				local to = level:mouse_position()
				love.graphics.line(from.x, from.y, to.x, to.y)
				love.graphics.setLineWidth(1)
				Colors.FullWhite:set()
			end

			for _, entity in ipairs(level.entities) do
				for _, command in ipairs(entity.commands) do
					command:draw()
				end
			end
			for _, entity in ipairs(level.entities) do
				entity:draw()
			end

			-- Colors.Red:set()
			-- for _, body in ipairs(Physics.world:getBodies()) do
			-- 	local x, y = body:getPosition()
			-- 	love.graphics.circle("line", x, y, 20)
			-- end

			Colors.FullWhite:set()
			if level.selected_entity then
				love.graphics.draw(
					Assets.images.tiles,
					Assets.images.selected_marker,
					level.selected_entity.position.x - 16,
					level.selected_entity.position.y)
			end

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
