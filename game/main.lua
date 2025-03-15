require 'game.globals'

local ldtk = require 'lib.ldtk'

local layers = {}
local level_offset = vec2.zero
local level = nil

function ldtk.onEntity(entity)
	print('new entity')
	print(entity)
end

function ldtk.onLayer(layer)
	print('new layer')
	table.insert(level.layers, layer)
end

function ldtk.onLevelLoaded(ldtk_level)
	print('loaded level')
	level = {
		name = string.gsub(ldtk_level.id, '_', ' '),
		offset = vec2 {
			(love.graphics.getWidth() - ldtk_level.width) / 2,
			(love.graphics.getHeight() - ldtk_level.height) / 2,
		},
		layers = {}
	}
end

function ldtk.onLevelCreated(ldtk_level)
	print('create level')
	print(ldtk_level)
end

function love.load()
	love.graphics.setBackgroundColor(unpack(Colors.Purple:to_array()))

	ldtk:load('assets/levels.ldtk')
	ldtk:goTo(1)
end

function love.update()

end

function love.draw()
	if level then
		love.graphics.setFont(FontMedium)
		local h_offset = FontMedium:getWidth(level.name) / 2
		love.graphics.print(level.name, love.graphics.getWidth() / 2 - h_offset, 20)
	end
	love.graphics.push()
	love.graphics.translate(level.offset.x, level.offset.y)
	for _, layer in ipairs(level.layers) do
		layer:draw()
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
