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
	self.images.goblin = Drawable(love.graphics.newQuad(128, 0, 32, 32, self.images.tiles))
	self.images.captured = Drawable(love.graphics.newQuad(160, 0, 32, 32, self.images.tiles))
	-- self.images.trickster = Drawable(love.graphics.newQuad(192, 0, 32, 32, self.images.tiles))
	self.images.enemy = Drawable(love.graphics.newQuad(224, 0, 32, 32, self.images.tiles))
	self.images.selected_marker = Drawable(love.graphics.newQuad(128, 32, 32, 32, self.images.tiles))
	self.images.move_command = Drawable(love.graphics.newQuad(160, 32, 32, 32, self.images.tiles))
	self.images.patrol_command = Drawable(love.graphics.newQuad(192, 32, 32, 32, self.images.tiles))
	self.images.distract_command = Drawable(love.graphics.newQuad(224, 32, 32, 32, self.images.tiles))
	self.images.distract_target = Drawable(love.graphics.newQuad(224, 64, 32, 32, self.images.tiles))
	self.images.wait_command = Drawable(love.graphics.newQuad(128, 64, 32, 32, self.images.tiles))
	self.images.firecracker = Drawable(love.graphics.newQuad(160, 64, 32, 32, self.images.tiles))
	self.images.firecracker_dust = Drawable(love.graphics.newQuad(192, 64, 32, 32, self.images.tiles))
	self.images.investigate_command = Drawable(love.graphics.newQuad(128, 96, 32, 32, self.images.tiles))
	self.images.listen_command = Drawable(love.graphics.newQuad(160, 96, 32, 32, self.images.tiles))
	self.images.shout_command = Drawable(love.graphics.newQuad(192, 96, 32, 32, self.images.tiles))
	self.images.interact_command = Drawable(love.graphics.newQuad(224, 96, 32, 32, self.images.tiles))
	self.images.pressure_plate = Drawable(love.graphics.newQuad(128, 128, 32, 32, self.images.tiles))
	self.images.pressure_plate_pressed = Drawable(love.graphics.newQuad(160, 128, 32, 32, self.images.tiles))
	self.images.door_horizontal = Drawable(love.graphics.newQuad(192, 128, 32, 32, self.images.tiles))
	self.images.door_horizontal_open = Drawable(love.graphics.newQuad(192, 160, 32, 32, self.images.tiles))
	self.images.door_vertical = Drawable(love.graphics.newQuad(224, 128, 32, 32, self.images.tiles))
	self.images.door_vertical_open = Drawable(love.graphics.newQuad(224, 160, 32, 32, self.images.tiles))
	self.images.treasure_a = Drawable(love.graphics.newQuad(128, 160, 32, 32, self.images.tiles))
	self.images.treasure_b = Drawable(love.graphics.newQuad(160, 160, 32, 32, self.images.tiles))
	self.images.looted = Drawable(love.graphics.newQuad(96, 160, 32, 32, self.images.tiles))
	self.images.exit = Drawable(love.graphics.newQuad(96, 128, 32, 32, self.images.tiles))
	self.images.win_con = love.graphics.newImage('assets/victory.png')
	self.images.lose_con = love.graphics.newImage('assets/captured.png')
	self.images.main_menu = love.graphics.newImage('assets/main-menu.png')
end

return Assets
