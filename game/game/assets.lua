local Assets = {
	images = {},
	sfx = {}
}

local Drawable = Object:extend()

function Drawable:init(quad)
	self.quad = quad
end

function Drawable:draw(position, rotation)
	rotation = rotation or 0
	love.graphics.draw(Assets.images.tiles, self.quad, position.x, position.y, rotation, 1, 1, 16, 16)
end

function Assets:load()
	self.images.tiles = love.graphics.newImage('assets/tiles.png')
	self.images.sneaky = love.graphics.newQuad(128, 0, 32, 32, self.images.tiles)
	self.images.brute = love.graphics.newQuad(160, 0, 32, 32, self.images.tiles)
	self.images.trickster = love.graphics.newQuad(192, 0, 32, 32, self.images.tiles)
	self.images.enemy = love.graphics.newQuad(224, 0, 32, 32, self.images.tiles)
	self.images.selected_marker = Drawable(love.graphics.newQuad(128, 32, 32, 32, self.images.tiles))
	self.images.move_command = Drawable(love.graphics.newQuad(160, 32, 32, 32, self.images.tiles))
	self.images.patrol_command = Drawable(love.graphics.newQuad(192, 32, 32, 32, self.images.tiles))
	self.images.distract_command = Drawable(love.graphics.newQuad(224, 32, 32, 32, self.images.tiles))
	self.images.distract_target = Drawable(love.graphics.newQuad(224, 64, 32, 32, self.images.tiles))
	self.images.wait_command = Drawable(love.graphics.newQuad(128, 64, 32, 32, self.images.tiles))
	self.images.firecracker = Drawable(love.graphics.newQuad(160, 64, 32, 32, self.images.tiles))
	self.images.firecracker_dust = Drawable(love.graphics.newQuad(192, 64, 32, 32, self.images.tiles))
	self.images.investigate_command = Drawable(love.graphics.newQuad(128, 96, 32, 32, self.images.tiles))
end

return Assets
