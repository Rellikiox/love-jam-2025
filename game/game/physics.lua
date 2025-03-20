local Physics = {
	world = nil
}

function Physics:load()
	if self.world then
		self.world:destroy()
	end
	self.world = love.physics.newWorld(0, 0, true)
	self.world:setCallbacks(
		function(fixture_a, fixture_b, contact)
			local a = fixture_a:getUserData()
			local b = fixture_b:getUserData()
		end,
		nil,
		nil,
		nil
	)
end

function Physics:get_entities_at(position, radius)
	radius = radius or 0
	local entities = {}
	self.world:queryBoundingBox(position.x - radius, position.y - radius, position.x + radius, position.y + radius,
		function(fixture)
			local entity = fixture:getUserData()
			if entity then
				local other_position = vec2 { fixture:getBody():getPosition() }
				local entity_radius = fixture:getShape():getRadius()
				if ((position - other_position):length() - entity_radius) <= radius then
					table.insert(entities, entity)
				end
			end
			return true
		end)
	return entities
end

function Physics:is_line_unobstructed(from, to)
	if from == to then
		return false
	end
	local collides = false
	local collisions = 0
	self.world:rayCast(from.x, from.y, to.x, to.y, function(fixture)
		collisions = collisions + 1
		local object = fixture:getUserData()
		if not object then
			collides = true
		end
		return -1
	end)
	return not collides
end

function Physics:make_wall(position)
	self.body = love.physics.newBody(self.world, position.x + 16, position.y + 16, 'static')
	self.shape = love.physics.newRectangleShape(32, 32)
	self.fixture = love.physics.newFixture(self.body, self.shape, 1)
end

return Physics
