local Commands = require 'game.commands'
local Physics = require 'game.physics'
local Assets = require 'game.assets'
local Entities = require 'game.entities'

local CusorMode = {
	Select = 'Select',
	MoveCommand = 'Move',
	DistractCommand = 'Firecracker From',
	DistractTarget = 'Firecracker To',
	WaitCommand = 'Wait',
	WaitTimer = 'Wait Time',
	EditCommandPosition = 'Edit position',
	EditCommandValue = 'Edit Value',
	ListenCommand = 'Listen',
	ShoutCommand = 'Shout',
	InteractCommand = 'Interact',
}

local Cursor = {
	CursorMode = CusorMode,
	hand = love.mouse.getSystemCursor("hand"),
	arrow = love.mouse.getSystemCursor("arrow"),
	selected_agent = nil,
	selected_command = nil,
	mode = CusorMode.Select,
	set_hand = function(self)
		love.mouse.setCursor(self.hand)
	end,
	set_arrow = function(self)
		love.mouse.setCursor(self.arrow)
	end,
	mouse_1_released = function(self)
		if self.mode == CusorMode.Select then
			-- Look for an agent first
			for _, agent in ipairs(level.agents) do
				if agent.position:distance(level:mouse_position()) <= agent.radius then
					self.selected_agent = agent
					self:set_mode(CusorMode.MoveCommand)
					return
				end
			end

			-- Otherwise look for a command

			for _, agent in ipairs(level.agents) do
				if agent.is_goblin then
					for _, command in ipairs(agent.commands) do
						if command.position:distance(level:mouse_position()) <= 10 then
							self.selected_command = command
							self:set_mode(CusorMode.EditCommandPosition)
							return
						end
					end
				end
			end
		elseif self.mode == CusorMode.MoveCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.MoveCommand)
		elseif self.mode == CusorMode.DistractCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end

			self:set_mode(CusorMode.DistractTarget)
		elseif self.mode == CusorMode.DistractTarget then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.DistractCommand)
		elseif self.mode == CusorMode.WaitCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end

			self:set_mode(CusorMode.WaitTimer)
		elseif self.mode == CusorMode.WaitTimer then
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.WaitCommand)
		elseif self.mode == CusorMode.EditCommandPosition then
			if self.selected_command:is(Commands.ThrowFirecracker) or self.selected_command:is(Commands.Wait) then
				self:set_mode(CusorMode.EditCommandValue)
			else
				self:set_mode(CusorMode.Select)
			end
		elseif self.mode == CusorMode.EditCommandValue then
			self:set_mode(CusorMode.Select)
		elseif self.mode == CusorMode.ListenCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.ListenCommand)
		elseif self.mode == CusorMode.ShoutCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.ShoutCommand)
		elseif self.mode == CusorMode.InteractCommand then
			if not self:current_command_is_valid() then
				-- Play sfx
				return
			end
			self.selected_agent:add_command(self.next_command)
			self:set_mode(CusorMode.InteractCommand)
		end
	end,
	mouse_2_released = function(self)
		self.selected_agent = nil
		self:set_mode(CusorMode.Select)
	end,
	set_mode = function(self, mode)
		if mode == CusorMode.Select then
			self.mode = mode
			self.next_command = nil
			self.selected_agent = nil
			self.selected_command = nil
			return
		elseif mode == CusorMode.EditCommandPosition then
			self.mode = mode
			return
		elseif mode == CusorMode.EditCommandValue then
			self.mode = mode
			return
		end

		if not self.selected_agent then
			return
		end

		self.mode = mode
		local source = self.selected_agent:next_command_source()
		local position = level:mouse_position()
		if mode == CusorMode.MoveCommand then
			self.next_command = Commands.Move { source = source, position = position }
		elseif mode == CusorMode.DistractCommand then
			self.next_command = Commands.ThrowFirecracker { source = source, position = position }
		elseif mode == CusorMode.WaitCommand then
			self.next_command = Commands.Wait { source = source, position = position }
		elseif mode == CusorMode.ListenCommand then
			self.next_command = Commands.Listen { source = source, position = position }
		elseif mode == CusorMode.ShoutCommand then
			self.next_command = Commands.Shout { source = source, position = position }
		elseif mode == CusorMode.InteractCommand then
			self.next_command = Commands.Interact { source = source, position = position }
		end
	end,
	current_command_is_valid = function(self)
		if not self.next_command then
			return true
		end

		local from, to
		if self.mode == CusorMode.MoveCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.DistractCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.DistractTarget then
			return true
		elseif self.mode == CusorMode.WaitCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.WaitTimer then
			local length = (self.next_command.position - level:mouse_position()):length()
			return length >= 2
		elseif self.mode == CusorMode.EditCommandPosition then
			local command_to_mouse = level.pathfinding:get_path(self.selected_command.source.position,
				level:mouse_position())

			if not command_to_mouse then
				return false
			end

			-- if it's the last command no more checkes needed
			if self.selected_command == self.selected_command.agent.commands[#self.selected_command.agent.commands] then
				return true
			end

			local mouse_to_command = nil
			for index = 1, #self.selected_command.agent.commands - 1 do
				local command = self.selected_command.agent.commands[index]
				if command == self.selected_command then
					local next_command = self.selected_command.agent.commands[index + 1]
					mouse_to_command = level.pathfinding:get_path(
						command.position, next_command.position
					)
				end
			end

			return mouse_to_command ~= nil
		elseif self.mode == CusorMode.EditCommandValue then
			return true
		elseif self.mode == CusorMode.ListenCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.ShoutCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
		elseif self.mode == CusorMode.InteractCommand then
			from = self.selected_agent:next_command_source().position
			to = level:mouse_position()
			local treasure_in_range = false
			for _, entity in ipairs(level.entities) do
				if entity:is(Entities.Treasure) then
					if entity.position:distance(to) <= 16 then
						treasure_in_range = true
					end
				end
			end
			if not treasure_in_range then
				return false
			end
		end
		return level.pathfinding:get_path(from, to) ~= nil
	end,
	draw = function(self)
		love.graphics.push()
		love.graphics.translate(level.offset.x, level.offset.y)

		if self.next_command then
			if self:current_command_is_valid() then
				Colors.Black:set()
			else
				Colors.Red:set()
			end
			self.next_command:draw_path()
			self.next_command:draw_marker()
		end
		if self.selected_agent then
			Assets.images.selected_marker:draw(self.selected_agent.position)
		end
		if self.selected_command then
			Assets.images.selected_marker:draw(self.selected_command.position + vec2 { 0, 10 })
		end

		local position = level:mouse_position():floor()
		love.graphics.setFont(FontTiny)
		Colors.Black:set()
		love.graphics.rectangle("fill", position.x + 12, position.y - 3, FontTiny:getWidth(self.mode) + 5, 13)
		Colors.White:set()
		love.graphics.print(self.mode, position.x + 15, position.y - 5
		)

		-- Current mouse mode
		love.graphics.setFont(FontSmall)
		draw_shadow_text(self:get_mode_text(), vec2 { 25, game_size.y - 50 }, 2)
		love.graphics.pop()
	end,
	update = function(self, delta)
		if self.mode == CusorMode.Select then
			return
		end
		local path_to_mouse
		if self.next_command then
			path_to_mouse = level.pathfinding:get_path(self.next_command.source.position, level:mouse_position())
		else
			path_to_mouse = level.pathfinding:get_path(self.selected_command.source.position, level:mouse_position())
		end
		if self.mode == CusorMode.MoveCommand then
			self.next_command.position = level:mouse_position()
			if path_to_mouse then
				self.next_command:set_path(path_to_mouse)
			end
		elseif self.mode == CusorMode.DistractCommand then
			self.next_command.position = level:mouse_position()

			if path_to_mouse then
				self.next_command:set_path(path_to_mouse)
			end
		elseif self.mode == CusorMode.DistractTarget then
			self.next_command.target = level:mouse_position()
		elseif self.mode == CusorMode.WaitCommand then
			self.next_command.position = level:mouse_position()

			if path_to_mouse then
				self.next_command:set_path(path_to_mouse)
			end
		elseif self.mode == CusorMode.WaitTimer then
			local wait_time = (self.next_command.position - level:mouse_position()):length() / 20
			if wait_time >= 0.1 then
				local wait_time = math.min(wait_time, 5.0)
				self.next_command:set_wait_time(wait_time)
			end
		elseif self.mode == CusorMode.EditCommandPosition then
			self.selected_command.position = level:mouse_position()
			local command_to_mouse = level.pathfinding:get_path(self.selected_command.source.position,
				level:mouse_position())
			if command_to_mouse then
				self.selected_command:set_path(command_to_mouse)
			end

			-- update the next command in line too
			for index = 1, #self.selected_command.agent.commands - 1 do
				local command = self.selected_command.agent.commands[index]
				if command == self.selected_command then
					local next_command = self.selected_command.agent.commands[index + 1]
					local path = level.pathfinding:get_path(
						command.position, next_command.position
					)
					if path then
						next_command:set_path(path)
					end
				end
			end
		elseif self.mode == CusorMode.EditCommandValue then
			if self.selected_command:is(Commands.ThrowFirecracker) then
				self.selected_command.target = level:mouse_position()
			elseif self.selected_command:is(Commands.Wait) then
				local wait_time = (self.selected_command.position - level:mouse_position()):length() / 20
				if wait_time >= 0.1 then
					local wait_time = math.min(wait_time, 5.0)
					self.selected_command:set_wait_time(wait_time)
				end
			end
		elseif self.mode == CusorMode.ListenCommand then
			self.next_command.position = level:mouse_position()
			if path_to_mouse then
				self.next_command:set_path(path_to_mouse)
			end
		elseif self.mode == CusorMode.ShoutCommand then
			if path_to_mouse then
				self.next_command:set_path(path_to_mouse)
			end
			self.next_command.position = level:mouse_position()
		elseif self.mode == CusorMode.InteractCommand then
			if path_to_mouse then
				self.next_command:set_path(path_to_mouse)
			end
			self.next_command.position = level:mouse_position()
		end
	end,
	delete_current_command = function(self)
		if self.selected_command then
			local agent = self.selected_command.agent
			-- source is entity owning commands
			for index = 1, #agent.commands do
				if agent.commands[index] == self.selected_command then
					if index ~= #agent.commands then
						local previous = self.selected_command.source
						local next = agent.commands[index + 1]
						next.source = previous
					end
					table.remove(agent.commands, index)
				end
			end
			self.selected_command = nil
			self:set_mode(CusorMode.Select)
		end
	end,
	get_mode_text = function(self)
		if self.mode == CusorMode.Select then
			return 'Now, who did I send next? ...'
		elseif self.mode == CusorMode.MoveCommand then
			return self.selected_agent.name .. ' should go here'
		elseif self.mode == CusorMode.DistractCommand then
			return self.selected_agent.name .. ' should walk here and then...'
		elseif self.mode == CusorMode.DistractTarget then
			return 'throw a firecracker over here.'
		elseif self.mode == CusorMode.WaitCommand then
			return self.selected_agent.name .. ' should walk here and...'
		elseif self.mode == CusorMode.WaitTimer then
			return 'wait for ' .. self.next_command.wait_time .. ' seconds.'
		elseif self.mode == CusorMode.EditCommandPosition then
			return 'Actually, I changed my mind about this...'
		elseif self.mode == CusorMode.EditCommandValue then
			return 'It should actually be...'
		elseif self.mode == CusorMode.ListenCommand then
			return self.selected_agent.name ..
				' should wait to hear from the others.'
		elseif self.mode == CusorMode.ShoutCommand then
			return self.selected_agent.name ..
				' should let the other know they\'re ready.'
		elseif self.mode == CusorMode.InteractCommand then
			return self.selected_agent.name .. ' should interact with this item'
		end
	end
}


function Cursor:handle_keyreleased(key)
	if key == 'm' then
		Cursor:set_mode(CusorMode.MoveCommand)
	elseif key == 'd' then
		Cursor:set_mode(CusorMode.DistractCommand)
	elseif key == 'w' then
		Cursor:set_mode(CusorMode.WaitCommand)
	elseif key == 'h' then
		Cursor:set_mode(CusorMode.ListenCommand)
	elseif key == 's' then
		Cursor:set_mode(CusorMode.ShoutCommand)
	elseif key == 'e' then
		Cursor:set_mode(CusorMode.InteractCommand)
	elseif key == 'delete' or key == 'backspace' then
		Cursor:delete_current_command()
	end
end

function Cursor:handle_mousemoved(x, y, dx, dy, istouch)
	local entities = Physics:get_entities_at(level:mouse_position())
	if #entities > 0 then
		Cursor:set_hand()
	else
		Cursor:set_arrow()
	end
end

function Cursor:handle_mousereleased(x, y, button)
	if button == 1 then
		Cursor:mouse_1_released()
	elseif button == 2 then
		Cursor:mouse_2_released()
	end
end

return Cursor
