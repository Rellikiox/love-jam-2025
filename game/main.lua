require 'game.globals'
local Assets = require 'game.assets'
local Physics = require 'game.physics'
local Entity = require 'game.entities'
local ldtk = require 'lib.ldtk'

local level = {
	name = '',
	offset = vec2.zero,
	layers = {},
	entities = {},
	selected_entity = nil,
	simulation_running = false,
	mouse_position = function(self)
		return vec2 { love.mouse.getPosition() } - self.offset
	end,
}

local Cursor = {
	hand = love.mouse.getSystemCursor("hand"),
	arrow = love.mouse.getSystemCursor("arrow"),
	mode = 'Select',
	set_hand = function(self)
		love.mouse.setCursor(self.hand)
	end,
	set_arrow = function(self)
		love.mouse.setCursor(self.arrow)
	end,
	mouse_1_released = function(self)
		local entities = Physics:get_entities_at(level:mouse_position())
		for _, entity in ipairs(entities) do
			if entity.is_goblin then
				level.selected_entity = entities[1]
				self:set_mode('Move')
				break
			end
		end
	end,
	mouse_2_released = function(self)

	end,
	set_mode = function(self, mode)
		self.mode = mode
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
	table.insert(level.layers, layer)
end

function ldtk.onLevelLoaded(ldtk_level)
	level.name = string.gsub(ldtk_level.id, '_', ' ')
	level.offset = vec2 {
		(love.graphics.getWidth() - ldtk_level.width) / 2,
		(love.graphics.getHeight() - ldtk_level.height) / 2,
	}
	level.layers = {}
	level.entities = {}
	level.selected_entity = nil
	level.simulation_running = false
	Cursor:set_mode('Select')
end

function ldtk.onLevelCreated(ldtk_level)
end

function love.load()
	love.graphics.setBackgroundColor(unpack(Colors.Purple:to_array()))

	Assets:load()
	Physics:load()

	ldtk:load('assets/levels.ldtk')
	ldtk:goTo(1)
end

function love.update()
	if not level or not level.simulation_running then
		return
	end

	for _, entity in ipairs(level.entities) do
		entity:draw()
	end
end

function love.draw()
	if not level then
		return
	end

	-- Level title
	love.graphics.setFont(FontLarge)
	local title_position = vec2 {
		(love.graphics.getWidth() - FontLarge:getWidth(level.name)) / 2, 10
	}
	draw_shadow_text(level.name, title_position, 3)

	-- Current mouse mode
	love.graphics.setFont(FontMedium)
	draw_shadow_text('Current mode: ' .. Cursor.mode, vec2 { 25, love.graphics.getHeight() - 50 }, 2)


	love.graphics.push()
	love.graphics.translate(level.offset.x, level.offset.y)
	for _, layer in ipairs(level.layers) do
		layer:draw()
	end

	for _, entity in ipairs(level.entities) do
		entity:draw()
	end

	-- Colors.Red:set()
	-- for _, body in ipairs(Physics.world:getBodies()) do
	-- 	local x, y = body:getPosition()
	-- 	love.graphics.circle("line", x, y, body:getFixtures()[1]:getShape():getRadius())
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
end

function love.keyreleased(key)
	if key == ']' then
		ldtk:next()
	elseif key == '[' then
		ldtk:previous()
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
