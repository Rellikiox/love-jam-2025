local Assets = {
	tiles = nil,
	sfx = {}
}

function Assets:load()
	self.tiles = love.graphics.newImage('assets/tiles.png')
end

return Assets
