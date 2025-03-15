local Assets = {
	images = {},
	sfx = {}
}

function Assets:load()
	self.images.tiles = love.graphics.newImage('assets/tiles.png')
	self.images.sneaky = love.graphics.newQuad(128, 0, 32, 32, self.images.tiles)
	self.images.brute = love.graphics.newQuad(160, 0, 32, 32, self.images.tiles)
	self.images.trickster = love.graphics.newQuad(192, 0, 32, 32, self.images.tiles)
	self.images.enemy = love.graphics.newQuad(224, 0, 32, 32, self.images.tiles)
	self.images.selected_marker = love.graphics.newQuad(128, 32, 32, 32, self.images.tiles)
end

return Assets
