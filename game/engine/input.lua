local Events = require 'engine.events'
local utils = require 'engine.utils'

local Input = {
	action_to_key = {},
	key_to_action = {},
	keys_pressed = {},
	keys_just_pressed = {},
	keys_just_released = {},
	on_pressed_handlers = {},
	disabled_actions = {}
}

function Input:load(bindings)
	for action, key in pairs(bindings) do
		self:bind(action, key)
	end
end

function Input:update()
	self.keys_just_pressed = {}
	self.keys_just_released = {}
end

function Input:bind(action, key)
	self.action_to_key[action] = key
	if self.key_to_action[key] == nil then
		self.key_to_action[key] = {}
	end
	table.insert(self.key_to_action[key], action)
end

function Input:is_down(action)
	local key = self.action_to_key[action]
	return self.keys_pressed[key]
end

function Input:is_just_pressed(action)
	local key = self.action_to_key[action]
	return self.keys_just_pressed[key]
end

function Input:is_just_released(action)
	local key = self.action_to_key[action]
	return self.keys_just_released[key]
end

function Input:on_pressed(action, callback)
	self.on_pressed_handlers[action] = callback
end

function Input:set_pressed(key, value)
	self.keys_pressed[key] = value
	if value then
		self.keys_just_pressed[key] = true
	else
		self.keys_just_released[key] = true
	end
	if not value then
		return
	end
	local actions = self.key_to_action[key] or {}
	for _, action in ipairs(actions) do
		if not self.disabled_actions[action] and self.on_pressed_handlers[action] then
			self.on_pressed_handlers[action]()
		end
	end
end

function love.keypressed(key)
	Input:set_pressed(key, true)
end

function love.keyreleased(key)
	Input:set_pressed(key, nil)
end

function love.mousepressed(x, y, button, istouch)
	local key = 'mouse_' .. button
	Input:set_pressed(key, true)
end

function love.mousereleased(x, y, button, istouch)
	local key = 'mouse_' .. button
	Input:set_pressed(key, false)
end

return Input
