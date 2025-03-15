require 'game.globals'

local ldtk = require 'lib.ldtk'

local layers = {}
local level_offset = vec2.zero

function ldtk.onEntity(entity)
	print('new entity')
	print(entity)
end

function ldtk.onLayer(layer)
	print('new layer')
	print(layer)
	table.insert(layers, layer)
end

function ldtk.onLevelLoaded(level)
	print('loaded level')
	table.dump(level)
	level_offset = vec2 {
		(love.graphics.getWidth() - level.width) / 2,
		(love.graphics.getHeight() - level.height) / 2,
	}
	layers = {}
end

function ldtk.onLevelCreated(level)
	print('create level')
	print(level)
end

function love.load()
	love.graphics.setBackgroundColor(unpack(Colors.Purple:to_array()))

	ldtk:load('assets/levels.ldtk')
	ldtk:level('Level_0')
end

function love.update()

end

function love.draw()
	love.graphics.push()
	love.graphics.translate(level_offset.x, level_offset.y)
	for _, layer in ipairs(layers) do
		layer:draw()
	end
	love.graphics.pop()
end
