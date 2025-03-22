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
	selected_level = 1,
	buttons = {
		{
			position = vec2 { 50, 250 },
			size = vec2 { 20, 20 },
			text = '<',
			on_click = function()
				level_select:prev_level()
			end
		},
		{
			position = vec2 { 285, 250 },
			size = vec2 { 20, 20 },
			text = '>',
			on_click = function()
				level_select:next_level()
			end
		},
		{
			position = vec2 { 165, 350 },
			size = vec2 { 40, 30 },
			text = 'Enter',
			on_click = function()
				level_select:start_level()
			end
		}
	},
	next_level = function()
		if level_select.selected_level == #all_levels then
			level_select.selected_level = 1
		else
			level_select.selected_level = level_select.selected_level + 1
		end
	end,
	prev_level = function()
		if level_select.selected_level == 1 then
			level_select.selected_level = #all_levels
		else
			level_select.selected_level = level_select.selected_level - 1
		end
	end,
	start_level = function()
		local level_data = all_levels[level_select.selected_level]
		level = Heist {}
		level:load_level(level_data.level)
		level:load_layers(level_data.layers)
		level:load_entities(level_data.entities)
		level:create_level()
		state = 'heist'
	end
}
local pause_menu = {
	buttons = {
		{
			position = vec2 { game_size.x / 2 - 25, 250 },
			size = vec2 { 50, 20 },
			text = 'Resume',
			on_click = function()
				state = 'heist'
			end
		},
		{
			position = vec2 { game_size.x / 2 - 40, 350 },
			size = vec2 { 80, 20 },
			text = 'Back to Menu',
			on_click = function()
				state = 'level_select'
			end
		},
	}
}
function draw_buttons(buttons)
	for _, button in ipairs(buttons) do
		Colors.Black:set()
		love.graphics.rectangle('fill', button.position.x, button.position.y, button.size.x, button.size.y)
		Colors.White:set()
		love.graphics.setFont(FontTiny)
		local offset = vec2 {
			FontTiny:getWidth(button.text),
			FontTiny:getHeight() } / 2
		love.graphics.print(
			button.text,
			math.floor(button.position.x + button.size.x / 2 - offset.x),
			math.floor(button.position.y + button.size.y / 2 - offset.y)
		)
	end
end

function centered_string(text, y_pos)
	offset = love.graphics.getFont():getWidth(text) / 2
	love.graphics.print(text, math.floor(game_size.x / 2 - offset), math.floor(y_pos))
end

state = 'level_select'

function draw_level_preview(level_data, position)
	position = position:floor()
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
		level.firecrackers_used = level.firecrackers_used + 1
		table.insert(level.entities, Entities.Firecracker { position = from, target = to })
	end)

	Events:listen(nil, 'goblin-captured', function(goblin)
		local remaining = 0
		for _, agent in ipairs(level.agents) do
			if agent.is_goblin and not agent.captured then
				remaining = remaining + 1
			end
		end
		level.remaining_goblins = remaining
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
	if delta > 0.5 then
		return
	end
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
				love.graphics.draw(Assets.images.main_menu, 0, 0)
				draw_buttons(level_select.buttons)
				Colors.FullWhite:set()
				local draw_position = vec2 { 100, game_size.y / 2 - 100 }
				local level_data = all_levels[level_select.selected_level]
				draw_level_preview(level_data, draw_position)

				love.graphics.setFont(FontLarge)
				draw_shadow_text(level_data.name, vec2 { 400, 100 }, 3)
			elseif state == 'heist' then
				level:draw()
				Cursor:draw()

				love.graphics.setFont(FontTiny)
				local instructions1 =
				'[M1] Select goblin \t[M] Move\t[F] Firecracker\t[W] Wait\t\t[S] Shout\t[L] Listen\t[E] Loot'
				local instructions2 = '[M1] Select command \t[M1] Place command\t[Del/Backspace] Delete command'
				centered_string(instructions1, game_size.y - 50)
				centered_string(instructions2, game_size.y - 25)
			elseif state == 'pause' then
				level:draw()

				Colors.White:with_alpha(0.9):set()
				love.graphics.rectangle("fill", 300, 100, 200, 400)
				draw_buttons(pause_menu.buttons)
			elseif state == 'win_con' then
				level:draw()
				love.graphics.draw(Assets.images.win_con, 0, 0)
				Colors.Black:set()

				local y_pos = game_size.y / 2
				love.graphics.setFont(FontMedium)
				centered_string('Time spent: ' .. seconds_to_time(level.simulation_timer), y_pos)
				y_pos = y_pos + FontMedium:getHeight()
				centered_string('Treasure reclaimed: ' .. level.treasure_obtained .. '/' .. level.total_treasure, y_pos)
				y_pos = y_pos + FontMedium:getHeight()
				centered_string('Goblins remaining: ' .. level.remaining_goblins .. '/' .. level.starting_goblins, y_pos)
				y_pos = y_pos + FontMedium:getHeight()
				centered_string('Firecrackers used: ' .. level.firecrackers_used, y_pos)
				y_pos = y_pos + FontMedium:getHeight()

				love.graphics.setFont(FontSmall)
				centered_string('[R] Try again        [ESC] Back to menu', y_pos)
			elseif state == 'lose_con' then
				level:draw()
				love.graphics.draw(Assets.images.lose_con, 0, 0)
				Colors.White:set()
				love.graphics.setFont(FontSmall)
				centered_string('[R] Try again        [ESC] Back to menu', game_size.y / 2 + 75)
			end
		end)
end

function love.keyreleased(key)
	if state == 'level_select' then
		if key == 'return' then
			level_select:start_level()
		elseif key == 'left' then
			level_select:prev_level()
		elseif key == 'right' then
			level_select:next_level()
		end
	elseif state == 'heist' then
		if key == 'escape' then
			state = 'pause'
		else
			Cursor:handle_keyreleased(key)
			level:handle_keyreleased(key)
		end
	elseif state == 'lose_con' then
		if key == 'escape' then
			state = 'level_select'
		elseif key == 'r' then
			level:reset_simulation()
			state = 'heist'
		end
	elseif state == 'win_con' then
		if key == 'escape' then
			state = 'level_select'
		elseif key == 'r' then
			level:reset_simulation()
			state = 'heist'
		end
	end
end

function love.mousemoved(x, y, dx, dy, istouch)
	if state == 'heist' then
		Cursor:handle_mousemoved(x, y, dx, dy, istouch)
	end
end

function love.mousereleased(x, y, button)
	if state == 'level_select' then
		local mouse = vec2 { screen:getMousePosition() }
		for _, button in ipairs(level_select.buttons) do
			if point_in_rect(mouse, button.position, button.size) then
				button:on_click()
			end
		end
	elseif state == 'heist' then
		Cursor:handle_mousereleased(x, y, button)
	elseif state == 'pause' then
		local mouse = vec2 { screen:getMousePosition() }
		for _, button in ipairs(pause_menu.buttons) do
			if point_in_rect(mouse, button.position, button.size) then
				button:on_click()
			end
		end
	end
end

function love.resize(w, h)
	screen:handleResize()
end
