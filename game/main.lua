require 'game.globals'
local Assets = require 'game.assets'
local Physics = require 'game.physics'
local ldtk = require 'lib.ldtk'
local Terebi = require 'lib.terebi'
local Entities = require 'game.entities'
local Events = require 'engine.events'
local Heist = require 'game.heist'
local Cursor = require 'game.cursor'

game_size = vec2 { 800, 600 }

level = {}
all_levels = {}
loading_level = {}

level_select = {
	selected_level = 1
}

state = 'level_select'

function draw_level_preview(level_data, position)
	position = position:floor()

	love.graphics.setFont(FontSmall)
	love.graphics.print(level_data.name, position.x, position.y - FontSmall:getHeight())

	for _, layer in ipairs(level_data.layers) do
		for _, tile in ipairs(layer.tiles) do
			local point = position + (vec2 { tile.px[1], tile.px[2] } / 4):floor()
			local color = Colors.Peach
			if tile.t == 32 then
				color = Colors.Black
			end
			color:set()
			love.graphics.rectangle("fill", point.x, point.y, 8, 8)
		end
	end
end

function ldtk.onEntity(ldtk_entity)
	table.insert(loading_level.entities, ldtk_entity)
end

function ldtk.onLayer(layer)
	table.insert(loading_level.layers, layer)
end

function ldtk.onLevelLoaded(ldtk_level)
	loading_level = {
		id = ldtk_level.id,
		name = ldtk_level.props.name,
		level = ldtk_level,
		entities = {},
		layers = {}
	}
end

function ldtk.onLevelCreated(ldtk_level)
	all_levels[ldtk.levels[ldtk_level.id]] = loading_level
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

	Events:listen(nil, 'goblin-captured', function(goblin)
		local remaining = 0
		for _, agent in ipairs(level.agents) do
			if agent.is_goblin and not agent.captured then
				remaining = remaining + 1
			end
		end
		if remaining == 0 then
			state = 'lose_con'
		end
	end)

	Events:listen(nil, 'goblin-extracted', function(goblin)
		state = 'win_con'
	end)

	ldtk:load('assets/levels.ldtk')
	for level_name, _ in pairs(ldtk.levels) do
		ldtk:level(level_name)
	end
end

function love.update(delta)
	if state == 'level_select' then

	elseif state == 'heist' then
		Cursor:update(delta)
		level:update(delta)
	elseif state == 'win_con' then
	elseif state == 'lose_con' then
	end
end

function love.draw()
	screen:draw(
		function()
			if state == 'level_select' then
				local draw_position = vec2 { 100, game_size.y / 2 - 100 }
				draw_level_preview(all_levels[level_select.selected_level], draw_position)
			elseif state == 'heist' then
				level:draw()
				Cursor:draw()
			elseif state == 'win_con' then
				level:draw()
				love.graphics.draw(Assets.images.win_con, 0, 0)
				Colors.Black:set()
				local text = 'Press any key to continue'
				local offset = FontSmall:getWidth(text) / 2
				love.graphics.setFont(FontSmall)
				love.graphics.print(text, math.floor(game_size.x / 2 - offset), math.floor(game_size.y / 2 + 100))
			elseif state == 'lose_con' then
				level:draw()
				love.graphics.draw(Assets.images.lose_con, 0, 0)
				Colors.White:set()
				local text = 'Press any key to continue'
				local offset = FontSmall:getWidth(text) / 2
				love.graphics.setFont(FontSmall)
				love.graphics.print(text, math.floor(game_size.x / 2 - offset), math.floor(game_size.y / 2 + 100))
			end
		end)
end

function love.keyreleased(key)
	if state == 'level_select' then
		if key == 'return' then
			local level_data = all_levels[level_select.selected_level]
			level = Heist {}
			level:load_level(level_data.level)
			level:load_layers(level_data.layers)
			level:load_entities(level_data.entities)
			level:create_level()
			state = 'heist'
		elseif key == 'left' then
			if level_select.selected_level == 1 then
				level_select.selected_level = #all_levels
			else
				level_select.selected_level = level_select.selected_level - 1
			end
		elseif key == 'right' then
			if level_select.selected_level == #all_levels then
				level_select.selected_level = 1
			else
				level_select.selected_level = level_select.selected_level + 1
			end
		end
	elseif state == 'heist' then
		if key == ']' then
			ldtk:next()
		elseif key == '[' then
			ldtk:previous()
		elseif key == 'r' then
			ldtk:reload()
		else
			Cursor:handle_keyreleased(key)
			if level then
				level:handle_keyreleased(key)
			end
		end
	elseif state == 'lose_con' then
		state = 'level_select'
	elseif state == 'win_con' then
		state = 'level_select'
	end
end

function love.mousemoved(x, y, dx, dy, istouch)
	if state ~= 'heist' then
		return
	end
	Cursor:handle_mousemoved(x, y, dx, dy, istouch)
end

function love.mousereleased(x, y, button)
	if state ~= 'heist' then
		return
	end
	Cursor:handle_mousereleased(x, y, button)
end

function love.resize(w, h)
	screen:handleResize()
end
