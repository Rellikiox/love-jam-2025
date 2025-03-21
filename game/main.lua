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

function ldtk.onEntity(ldtk_entity)
	level:load_entity(ldtk_entity)
end

function ldtk.onLayer(layer)
	level:load_layer(layer)
end

function ldtk.onLevelLoaded(ldtk_level)
	level = Heist {}
	level:load_level(ldtk_level)
end

function ldtk.onLevelCreated(ldtk_level)
	level:create_level(ldtk_level)
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

function love.update(delta)
	Cursor:update(delta)

	if not level then
		return
	end

	level:update(delta)
end

function love.draw()
	screen:draw(
		function()
			if not level then
				return
			end

			level:draw()

			Cursor:draw()
		end)
end

function love.keyreleased(key)
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
end

function love.mousemoved(x, y, dx, dy, istouch)
	Cursor:handle_mousemoved(x, y, dx, dy, istouch)
end

function love.mousereleased(x, y, button)
	Cursor:handle_mousereleased(x, y, button)
end

function love.resize(w, h)
	screen:handleResize()
end
