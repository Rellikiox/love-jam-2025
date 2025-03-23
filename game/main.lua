require 'game.globals'
local Assets = require 'game.assets'
local Physics = require 'game.physics'
local ldtk = require 'lib.ldtk'
local Terebi = require 'lib.terebi'
local Entities = require 'game.entities'
local Events = require 'engine.events'
local Heist = require 'game.heist'
local Cursor = require 'game.cursor'
local SFX = require 'engine.sfx'

game_size = vec2 { 800, 600 }

level = {}
all_levels = {}
loading_level = {}

level_select = {
	selected_level = 1,
	buttons = {
		{
			position = vec2 { 300, 350 },
			size = vec2 { 20, 30 },
			text = '<',
			on_click = function()
				level_select:prev_level()
			end
		},
		{
			position = vec2 { 485, 350 },
			size = vec2 { 20, 30 },
			text = '>',
			on_click = function()
				level_select:next_level()
			end
		},
		{
			position = vec2 { 377, 350 },
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
		SFX:play('turn_page')
	end,
	prev_level = function()
		if level_select.selected_level == 1 then
			level_select.selected_level = #all_levels
		else
			level_select.selected_level = level_select.selected_level - 1
		end
		SFX:play('turn_page')
	end,
	start_level = function()
		local level_data = all_levels[level_select.selected_level]
		level = Heist {}
		level:load_level(level_data.level)
		level:load_layers(level_data.layers)
		level:load_entities(level_data.entities)
		level:create_level(level_data.level)
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
	local offset = love.graphics.getFont():getWidth(text) / 2
	love.graphics.print(text, math.floor(game_size.x / 2 - offset), math.floor(y_pos))
end

function centered_shadow_string(text, y_pos, shadow)
	local offset = love.graphics.getFont():getWidth(text) / 2
	draw_shadow_text(text, math.floor(game_size.x / 2 - offset), math.floor(y_pos), shadow)
end

local level_stats = {}

function load_level_stats()
	local file = love.filesystem.newFile('level-scores.txt')
	local stats = {}
	if file:open('r') then
		for line in file:lines() do
			local level_id, time, treasure, t_treasure, goblins, t_goblins, firecrackers = line:match(
				"([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
			if level_id and time and treasure and t_treasure and goblins and t_goblins and firecrackers then
				stats[level_id] = {
					time = tonumber(time / 1000),
					treasure = tonumber(treasure),
					total_treasure = tonumber(t_treasure),
					goblins = tonumber(goblins),
					total_goblins = tonumber(t_goblins),
					firecrackers =
						tonumber(firecrackers)
				}
			end
		end
		file:close()
	end
	return stats
end

function save_level_stats(stats)
	local file = love.filesystem.newFile('level-scores.txt')
	if file:open('w') then
		for level_id, data in pairs(stats) do
			local line = string.format(
				"%s,%d,%d,%d,%d,%d,%d\n",
				level_id,
				data.time or 0,
				data.treasure or 0,
				data.total_treasure or 0,
				data.goblins or 0,
				data.total_goblins or 0,
				data.firecrackers or 0
			)
			file:write(line)
		end
		file:close()
	end
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

	for _, entity in ipairs(level_data.entities) do
		local point = position + (vec2 { entity.x, entity.y } / 4):floor()
		if entity.id == 'Pressure_plate' then
		elseif entity.id == 'Door_H' then
			Colors.Brown:set()
		elseif entity.id == 'Door_V' then
			Colors.Brown:set()
		elseif entity.id == 'Treasure' then
			Colors.Orange:set()
		elseif entity.id == 'Exit' then
			Colors.Grass:set()
		elseif entity.id == 'Spawn' then
			Colors.Forest:set()
		elseif entity.id == 'Enemy' then
			Colors.Red:set()
		end
		love.graphics.circle("fill", point.x, point.y, 3)
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
	SFX:load(Settings.sfx)

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
		if not level_stats[level.id] or level.simulation_timer * 1000 < level_stats[level.id].time then
			level_stats[level.id] = {
				time = level.simulation_timer * 1000,
				treasure = level.treasure_obtained,
				total_treasure = level.total_treasure,
				goblins = level.remaining_goblins,
				total_goblins = level.starting_goblins,
				firecrackers = level.firecrackers_used
			}
			save_level_stats(level_stats)
		end
	end)

	ldtk:load('assets/levels.ldtk')
	for level_name, _ in pairs(ldtk.levels) do
		ldtk:level(level_name)
	end

	level_stats = load_level_stats()
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
				local draw_position = vec2 { 300, game_size.y / 2 - 100 }
				local level_data = all_levels[level_select.selected_level]
				draw_level_preview(level_data, draw_position)

				Colors.Black:set()
				love.graphics.setFont(FontMedium)
				centered_string(level_data.name, game_size.y / 2 - 150)

				love.graphics.setFont(FontLarge)

				draw_shadow_text("What's the plan boss?", vec2 { 200, 20 }, 3)

				love.graphics.setFont(FontSmall)
				local text = "~ Barely created by Martin Candela ~"
				local offset = FontSmall:getWidth(text) / 2
				draw_shadow_text(text, vec2 { game_size.x / 2 - offset, game_size.y - 30 }, 2)

				Colors.White:set()
				love.graphics.setFont(FontSmall)
				local current_level_stats = level_stats[level_data.id]
				local y_pos = 25
				if current_level_stats then
					draw_shadow_text(seconds_to_time(current_level_stats.time), vec2 { 25, y_pos }, 2)
					y_pos = y_pos + FontSmall:getHeight()
					draw_shadow_text(
						current_level_stats.treasure ..
						'/' .. current_level_stats.total_treasure .. ' Treasures',
						vec2 { 25, y_pos },
						2)
					y_pos = y_pos + FontSmall:getHeight()
					draw_shadow_text(
						current_level_stats.goblins ..
						'/' .. current_level_stats.total_goblins .. ' Goblins',
						vec2 { 25, y_pos },
						2)
					y_pos = y_pos + FontSmall:getHeight()
					draw_shadow_text(current_level_stats.firecrackers .. ' Firecrackers used', vec2 { 25, y_pos }, 2)
				else
					draw_shadow_text('~ no data for this level ~', vec2 { 25, y_pos }, 2)
				end
			elseif state == 'heist' then
				level:draw()
				Cursor:draw()

				love.graphics.setFont(FontTiny)
				local instructions = {
					'[M1] Select goblin \t[M] Move\t[F] Firecracker\t[W] Wait\t\t[S] Shout\t[L] Listen\t[E] Loot',
					'[M1] Select command \t[M1] Place command\t[Del/Backspace] Delete command',
					'[ESC] Menu\t[R] Restart level'
				}
				centered_string(instructions[1], game_size.y - 50)
				centered_string(instructions[2], game_size.y - 35)
				centered_string(instructions[3], game_size.y - 20)
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
