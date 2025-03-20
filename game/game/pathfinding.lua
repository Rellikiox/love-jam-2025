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

function Pathfinding:get_node_id(position)
	local cell = (position / 32):floor()
	return cell.x .. '.' .. cell.y
end

function Pathfinding:node_for_position(position)
	local node_id = self:get_node_id(position)
	return self.nodes[node_id]
end

function Pathfinding:get_path(from, to)
	local from_node = self:node_for_position(from)
	local to_node = self:node_for_position(to)
	if not from_node or not to_node then
		return nil
	end

	local seen = {}
	local frontier = { { node = from_node, path = { from, from_node.position + vec2 { 16, 16 } } } }
	while #frontier > 0 do
		local node = table.remove(frontier, 1)

		if node.node == to_node then
			table.insert(node.path, to)
			return node.path
		end
		if seen[node.node] then
			goto continue
		end
		seen[node.node] = true

		for _, offset in ipairs({ vec2 { -1, 0 }, vec2 { 0, -1 }, vec2 { 1, 0 }, vec2 { 0, 1 } }) do
			local other_node_id = node.node.cell.x + offset.x .. '.' .. node.node.cell.y + offset.y
			local other_node = self.nodes[other_node_id]
			if other_node and other_node.passable then
				local other_path = table.shallow_copy(node.path)
				table.insert(other_path, other_node.position + vec2 { 16, 16 })
				table.insert(frontier, { node = other_node, path = other_path })
			end
		end

		::continue::
	end

	return nil
end

return Pathfinding
