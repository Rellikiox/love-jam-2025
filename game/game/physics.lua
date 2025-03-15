local Physics = {
	world = nil
}

function Physics:load()
	self.world = love.physics.newWorld(0, 0, true)
	self.world:setCallbacks(
		function(fixture_a, fixture_b, contact)
			local a = fixture_a:getUserData()
			local b = fixture_b:getUserData()
			print('collission')
		end,
		nil,
		nil,
		nil
	)
end

function Physics:get_entities_at(position)
	local entities = {}
	self.world:queryBoundingBox(position.x - 2, position.y - 2, position.x + 2, position.y + 2, function(fixture)
		local entity = fixture:getUserData()
		if entity then
			table.insert(entities, entity)
		end
	end)
	return entities
end

return Physics
