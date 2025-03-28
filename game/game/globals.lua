require 'engine.object'
require 'engine.vec2'
require 'engine.utils'
require 'game.settings'

local Color = require 'engine.color'

Colors = {
	Black = Color.from_hex('#28282e'),
	Purple = Color.from_hex('#6c5671'),
	Tan = Color.from_hex('#d9c8bf'),
	Red = Color.from_hex('#f98284'),
	Violet = Color.from_hex('#b0a9e4'),
	Blue = Color.from_hex('#accce4'),
	Teal = Color.from_hex('#b3e3da'),
	Pink = Color.from_hex('#feaae4'),
	Forest = Color.from_hex('#87a889'),
	Grass = Color.from_hex('#b0eb93'),
	Olive = Color.from_hex('#e9f59d'),
	Peach = Color.from_hex('#ffe6c6'),
	Brown = Color.from_hex('#dea38b'),
	Orange = Color.from_hex('#ffc384'),
	Yellow = Color.from_hex('#fff7a0'),
	White = Color.from_hex('#fff7e4'),
	FullWhite = Color.from_hex('#ffffff')
}


FontTiny = love.graphics.newFont('assets/m3x6.ttf', 16)
FontSmall = love.graphics.newFont('assets/m6x11plus.ttf', 18)
FontMedium = love.graphics.newFont('assets/m6x11plus.ttf', 36)
FontLarge = love.graphics.newFont('assets/m6x11plus.ttf', 54)
love.graphics.setFont(FontSmall)
