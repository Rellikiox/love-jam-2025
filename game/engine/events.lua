local Events = {
	listeners = {}
}

function Events:listen(object, events, callback)
	if type(events) ~= 'table' then
		events = { events }
	end
	for _, event in ipairs(events) do
		if not self.listeners[event] then
			self.listeners[event] = {}
		end
		table.insert(self.listeners[event], { object = object, callback = callback })
	end
end

function Events:send(event, ...)
	if Settings.debug.log_events then
		print('> ' .. event)
	end

	if not self.listeners[event] then
		return
	end
	for _, listener in ipairs(self.listeners[event]) do
		listener.callback(...)
	end
end

function Events:deregister(object)
	for event, listeners in pairs(self.listeners) do
		for index = #listeners, 1, -1 do
			if listeners[index].object == object then
				table.remove(listeners, index)
			end
		end
	end
end

return Events
