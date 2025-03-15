local SFX = {}

function SFX:load(args)
	self.loops = {}
	self.sources = {}
	for name, filenames in pairs(args.sources) do
		if type(filenames) ~= 'table' then
			filenames = { filenames }
		end
		self.sources[name] = {}
		for _, filename in ipairs(filenames) do
			table.insert(self.sources[name], love.audio.newSource(args.path .. filename, 'static'))
		end
	end
end

function SFX:play(source, base_volume, variance, pitch, pitch_variance)
	assert(self.sources[source] ~= nil, 'Missing SFX ' .. source)
	base_volume = base_volume or 1
	variance = (variance or 0.2) / 2
	pitch = pitch or 1
	pitch_variance = pitch_variance or 0.1
	local sfx = random_choice(self.sources[source]):clone()
	local volume = clamp(random_range(base_volume - variance, base_volume), 0, 1)
	sfx:setVolume(volume)
	sfx:setPitch(random_range(pitch - pitch_variance, pitch + pitch_variance))
	sfx:play()
end

function SFX:get_loop(source)
	assert(self.sources[source] ~= nil, 'Missing SFX ' .. source)
	local sfx = self.sources[source]:clone()
	sfx:setLooping(true)
	return sfx
end

return SFX
