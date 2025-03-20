local Assets = require 'game.assets'
local Events = require 'engine.events'

local CommandState = {
	Running = 'running',
	Finished = 'finished',
	Destroy = 'destroy'
}


local Command = Object:extend()

function Command:draw_path()
	love.graphics.setLineWidth(3)
	love.graphics.line(self.source.position.x, self.source.position.y, self.position.x, self.position.y)
	love.graphics.setLineWidth(1)
end

local MoveCommand = Command:extend()

function MoveCommand:init(args)
	Command.init(self, args)
	self.source = args.source
	self.position = args.position
end

function MoveCommand:draw_marker()
	Assets.images.move_command:draw(self.position)
end

function MoveCommand:update(delta)
	local direction = (self.position - self.agent.position):normalized()
	local force = direction * self.agent.speed * delta
	self.agent.body:applyForce(force.x, force.y)
	if (self.position - self.agent.position):length() < 1 then
		return CommandState.Finished
	end
	return CommandState.Running
end

local PatrolCommand = Command:extend()

function PatrolCommand:init(args)
	Command.init(self, args)
	self.points = args.points
	self.target_point = 1
	self.draw_points = {}
	for _, point in ipairs(self.points) do
		table.insert(self.draw_points, point.x)
		table.insert(self.draw_points, point.y)
	end
	table.insert(self.draw_points, self.points[1].x)
	table.insert(self.draw_points, self.points[1].y)
end

function PatrolCommand:draw_path()
	love.graphics.setLineWidth(2)
	love.graphics.line(unpack(self.draw_points))
	love.graphics.setLineWidth(1)
end

function PatrolCommand:draw_marker()
	for _, point in ipairs(self.points) do
		Assets.images.patrol_command:draw(point)
	end
end

function PatrolCommand:update(delta)
	local position = self.points[self.target_point]
	local direction = (position - self.agent.position):normalized()
	local force = direction * self.agent.speed * delta
	self.agent.body:applyForce(force.x, force.y)

	if (position - self.agent.position):length() < 1 then
		local prev = self.target_point
		self.target_point = math.fmod(self.target_point, #self.points) + 1
	end
	return CommandState.Running
end

local ThrowFirecrackerComand = MoveCommand:extend()

function ThrowFirecrackerComand:init(args)
	MoveCommand.init(self, args)

	self.target = args.target
	self.arrived = false
	self.finished = false
	self.wait_timer = Timer {
		autostart = false,
		timeout = 1.0,
		callback = function()
			Events:send('launch-firecracker', self.position, self.target)
		end
	}
end

function ThrowFirecrackerComand:draw_path()
	Command.draw_path(self)
	if self.target then
		love.graphics.line(self.position.x, self.position.y, self.target.x, self.target.y)
	end
end

function ThrowFirecrackerComand:draw_marker()
	Assets.images.distract_command:draw(self.position)
	if self.target then
		Assets.images.distract_target:draw(self.target)
		love.graphics.circle('line', self.target.x, self.target.y, 100)
	end
end

function ThrowFirecrackerComand:update(delta)
	if not self.arrived then
		local move_state = MoveCommand.update(self, delta)
		self.arrived = move_state == CommandState.Finished
		if self.arrived then
			self.wait_timer:start()
		end
	else
		self.wait_timer:increment(delta)
		if self.wait_timer.finished then
			return CommandState.Finished
		end
	end
	return CommandState.Running
end

local WaitComand = MoveCommand:extend()

function WaitComand:init(args)
	MoveCommand.init(self, args)

	self.finished = false
	self.wait_timer = Timer {
		timeout = 0,
		callback = function()
			self.finished = true
		end
	}
	self:set_wait_time(0.1)
end

function WaitComand:set_wait_time(time)
	self.wait_time = string.format("%.1f", time)
	self.wait_timer.timeout = tonumber(self.wait_time)
end

function WaitComand:draw_marker()
	local offset = (self.arrived and not self.finished) and vec2 { 0, -20 } or vec2.zero

	Colors.FullWhite:set()
	Assets.images.wait_command:draw(self.position + offset)

	Colors.Black:set()
	love.graphics.setFont(FontTiny)
	local point = (self.position + offset):floor()
	Colors.White:set()
	love.graphics.print(string.format("%.1f", self.wait_timer.timeout - self.wait_timer.elapsed), point.x - 7,
		point.y - 12)
end

function WaitComand:update(delta)
	if not self.arrived then
		local move_state = MoveCommand.update(self, delta)
		self.arrived = move_state == CommandState.Finished
	else
		self.wait_timer:increment(delta)
		if self.finished then
			return CommandState.Finished
		end
	end
	return CommandState.Running
end

local ListenComand = MoveCommand:extend()

function ListenComand:init(args)
	MoveCommand.init(self, args)

	self.arrived = false
	self.heard = false
	Events:listen(self, 'shout', function()
		self.heard = true
	end)
end

function ListenComand:draw_marker()
	Assets.images.listen_command:draw(self.position)
end

function ListenComand:update(delta)
	if not self.arrived then
		local move_state = MoveCommand.update(self, delta)
		self.arrived = move_state == CommandState.Finished
	else
		if self.heard then
			return CommandState.Finished
		end
	end
	return CommandState.Running
end

local ShoutComand = MoveCommand:extend()

function ShoutComand:init(args)
	MoveCommand.init(self, args)

	self.arrived = false
end

function ShoutComand:draw_marker()
	Assets.images.shout_command:draw(self.position)
end

function ShoutComand:update(delta)
	if not self.arrived then
		local move_state = MoveCommand.update(self, delta)
		self.arrived = move_state == CommandState.Finished
	else
		Events:send('shout')
		return CommandState.Finished
	end
	return CommandState.Running
end

local InvestigateCommand = MoveCommand:extend()

function InvestigateCommand:init(args)
	Command.init(self, args)

	self.path = args.path
	self.path_index = 1

	self.draw_points = {}
	for _, point in ipairs(self.path) do
		table.insert(self.draw_points, point.x)
		table.insert(self.draw_points, point.y)
	end
	self.wait_timer = Timer { autostart = false, timeout = 3 }
end

function InvestigateCommand:draw_path()
	love.graphics.setLineWidth(1)
	love.graphics.line(unpack(self.draw_points))
end

function InvestigateCommand:draw_marker()
	Assets.images.investigate_command:draw(self.path[#self.path])
end

function InvestigateCommand:update(delta)
	if self.path_index <= #self.path then
		local target = self.path[self.path_index]
		local direction = (target - self.agent.position):normalized()
		self.agent.position = self.agent.position + direction * self.agent.speed * delta
		self.agent.body:setPosition(self.agent.position.x, self.agent.position.y)
		if (target - self.agent.position):length() < 1 then
			self.path_index = self.path_index + 1
			if self.path_index > #self.path then
				self.wait_timer:start()
			end
		end
	else
		self.wait_timer:increment(delta)
		if self.wait_timer.finished then
			return CommandState.Destroy
		end
	end
	return CommandState.Running
end

local InteractCommand = MoveCommand:extend()

function InteractCommand:init(args)
	MoveCommand.init(self, args)
	self.object = args.object
end

function InteractCommand:draw_marker()
	Assets.images.interact_command:draw(self.position)
end

return {
	Move = MoveCommand,
	Patrol = PatrolCommand,
	ThrowFirecracker = ThrowFirecrackerComand,
	Wait = WaitComand,
	Investigate = InvestigateCommand,
	State = CommandState,
	Shout = ShoutComand,
	Listen = ListenComand,
	Interact = InteractCommand
}
