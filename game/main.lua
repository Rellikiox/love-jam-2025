require 'game.globals'
local Assets = require 'game.assets'
local Entity = require 'game.entities'
local ldtk = require 'lib.ldtk'

local level = nil

function ldtk.onEntity(entity)
	print('new entity')


	local quad
	if entity.id == 'Sneaky' then
		quad = love.graphics.newQuad(128, 0, 32, 32, Assets.tiles)
	elseif entity.id == 'Brute' then
		quad = love.graphics.newQuad(160, 0, 32, 32, Assets.tiles)
	elseif entity.id == 'Trickster' then
		quad = love.graphics.newQuad(192, 0, 32, 32, Assets.tiles)
	elseif entity.id == 'Enemy' then
		quad = love.graphics.newQuad(224, 0, 32, 32, Assets.tiles)
	end

	table.insert(level.entities, Entity {
		position = vec2 { entity.x, entity.y },
		quad = quad,
		radius = entity.width / 2
	})
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
		layers = {},
		entities = {}
	}
end

function ldtk.onLevelCreated(ldtk_level)
	print('create level')
	print(ldtk_level)
end

function love.load()
	love.graphics.setBackgroundColor(unpack(Colors.Purple:to_array()))

	Assets:load()

	ldtk:load('assets/levels.ldtk')
	ldtk:goTo(1)
end

function love.update()
	if not level then
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

	love.graphics.setFont(FontMedium)
	local h_offset = FontMedium:getWidth(level.name) / 2
	Colors.Black:set()
	love.graphics.print(level.name, love.graphics.getWidth() / 2 - h_offset + 2, 20 + 2)
	Colors.White:set()
	love.graphics.print(level.name, love.graphics.getWidth() / 2 - h_offset, 20)

	love.graphics.push()
	love.graphics.translate(level.offset.x, level.offset.y)
	for _, layer in ipairs(level.layers) do
		layer:draw()
	end

	for _, entity in ipairs(level.entities) do
		entity:draw()
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
