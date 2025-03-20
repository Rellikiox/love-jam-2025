local Pathfinding = Object:extend()

function Pathfinding:init(tiles)
	self.nodes = {}
	self.doors = {}
end

function Pathfinding:add_door(position)
	local cell = (position / 32):floor()
	local cell_id = cell.x .. '.' .. cell.y
	if self.nodes[cell_id] then
		self.nodes[cell_id].passable = false
	end
	self.doors[cell_id] = true
end

function Pathfinding:process_tiles(tiles)
	for _, tile in ipairs(tiles) do
		if tile.t ~= 32 then
			local position = vec2 { tile.px[1], tile.px[2] }
			local cell = (position / 32):floor()
			local cell_id = cell.x .. '.' .. cell.y
			local is_door = self.doors[cell_id]
			self.nodes[cell_id] = { position = position, cell = cell, passable = not is_door }
		end
	end
end

function Pathfinding:toggle_node_at_position(position)
	local cell = (position / 32):floor()
	local cell_id = cell.x .. '.' .. cell.y
	self.nodes[cell_id].passable = not self.nodes[cell_id].passable
	print(self.nodes[cell_id].passable)
end

function Pathfinding:draw()
	for _, node in pairs(self.nodes) do
		if node.passable then
			Colors.Forest:set()
		else
			Colors.Red:set()
		end
		love.graphics.circle('fill', node.position.x + 16, node.position.y + 16, 3)
	end
end

return Pathfinding
