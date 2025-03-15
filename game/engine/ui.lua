local Input = require 'engine.input'

local Align = {
	Start = 1,
	Center = 2,
	End = 3
}
local Justify = {
	Start = 1,
	Center = 2,
	End = 3
}
local Anchor = {
	TopLeft = 1,
	TopCenter = 2,
	TopRight = 3,
	CenterLeft = 4,
	CenterCenter = 5,
	CenterRight = 6,
	BottomLeft = 7,
	BottomCenter = 8,
	BottomRight = 9
}

local UI = Object:extend()

function UI:init(args)
	assert(#args == 1, 'UI must have exactly one root widget.')
	self.position = args.position or vec2.zero
	self.root = args[1]
	self.visible = args.visible or true

	self.root:calculate_layout()
end

function UI:update(delta)
	if self.visible then
		local x, y = screen:getMousePosition()
		self.root:update_pointer_state(x, y, love.mouse.isDown(1))
		self.root:update(delta)
	end
end

function UI:draw()
	if self.visible then
		self.root:draw()
	end
end

function UI:show()
	self.visible = true
end

function UI:hide()
	self.visible = false
end

local Node = Object:extend()

function Node:init(args)
	self.x = args.x or 0
	self.y = args.y or 0
	self.width = args.width or 0
	self.height = args.height or 0
	self.max_width = args.max_width or 0
	self.max_height = args.max_height or 0
	self.rotation = args.rotation or 0
	self.scale = args.scale or 1
	self.disabled = args.disabled
	self.visible = args.visible == nil and true or args.visible
	self.active = args.active == nil and true or args.active
	self.print_data = args.print_data or false

	self.is_hovered = false
	self.is_pressed = false

	self.on_hover_enter = args.on_hover_enter
	self.on_hover_exit = args.on_hover_exit
	self.on_pressed = args.on_pressed
	self.on_released = args.on_released

	local style = args.style or {}
	self.style = {
		font = style.font or Fonts.Default,
		text_color = style.text_color or Colors.Peach,
		bg_color = style.bg_color,
		hover_color = style.hover_color,
		pressed_color = style.pressed_color
	}
	self.children = {}

	self.tween = nil
end

function Node:update(delta)
	if self.tween then
		if self.tween:update(delta) then
			self.tween = nil
		end
	end
end

function Node:get_position()
	return self.x, self.y
end

function Node:get_mouse_position()
	return vec2 { screen:getMousePosition() } - vec2 { self.x, self.y }
end

function Node:contains_point(px, py)
	local x, y = self:get_position()
	return px >= x and px <= x + self.width and py >= y and py <= y + self.height
end

function Node:update_pointer_state(x, y, is_pointer_down)
	if not self.active then
		return
	end
	for _, child in ipairs(self.children) do
		if child.visible and child:update_pointer_state(x, y, is_pointer_down) then
			-- If child is hovered then we aren't
			if self.is_hovered then
				self.is_hovered = false
				if self.on_hover_exit then
					self:on_hover_exit()
				end
			end
			if self.is_pressed then
				self.is_pressed = false
			end
			return true
		end
	end

	local was_hovered = self.is_hovered
	local was_pressed = self.is_pressed
	if self:contains_point(x, y) then
		if is_pointer_down and not self.is_pressed then
			self.is_pressed = true
			if self.on_pressed then
				self:on_pressed()
			end
		elseif not is_pointer_down and self.is_pressed then
			self.is_pressed = false
			if self.on_released then
				self:on_released()
			end
		end

		if not was_hovered then
			self.is_hovered = true
			if self.on_hover_enter then
				self:on_hover_enter()
			end
		end

		return true
	else
		if self.is_hovered then
			self.is_hovered = false
			if self.on_hover_exit then
				self:on_hover_exit()
			end
		end
		if was_pressed then
			self.is_pressed = false
		end
	end
	return false
end

local Container = Node:extend()

function Container:init(args)
	Node.init(self, args)
	self.min_width = args.min_width or 0
	self.min_height = args.min_height or 0

	local padding = args.padding or {}
	self.padding = {
		left = padding.left or 0,
		right = padding.right or 0,
		top = padding.top or 0,
		bottom = padding.bottom or 0
	}
	self.separation = args.separation or 0

	self.align = args.align or Align.Start
	self.justify = args.justify or Justify.Start
	self.anchor = args.anchor or Anchor.TopLeft
	self.children = args
end

function Container:get_position()
	local x, y = self.x, self.y
	if
		self.anchor == Anchor.BottomRight or self.anchor == Anchor.CenterRight or
		self.anchor == Anchor.TopRight
	then
		x = x - self.width
	elseif
		self.anchor == Anchor.BottomCenter or self.anchor == Anchor.CenterCenter or
		self.anchor == Anchor.TopCenter
	then
		x = x - self.width / 2
	end
	if
		self.anchor == Anchor.BottomRight or self.anchor == Anchor.BottomCenter or
		self.anchor == Anchor.BottomLeft
	then
		y = y - self.height
	elseif
		self.anchor == Anchor.CenterLeft or self.anchor == Anchor.CenterCenter or
		self.anchor == Anchor.CenterRight
	then
		y = y - self.height / 2
	end
	return x, y
end

function Container:calculate_size()
	for _, child in ipairs(self.children) do
		if child.calculate_size then
			if child.calculate_size then
				child:calculate_size()
				if self.print_data then
					print(vec2 { child.width, child.height })
				end
			end
		end
	end

	if self.height ~= 0 and self.width ~= 0 then
		return
	end

	if self.type == 'row' then
		local total_width = self:get_child_width()
		local max_height = 0

		for _, child in ipairs(self.children) do
			max_height = math.max(max_height, child.height)
		end

		self.width = math.max(self.min_width, total_width + self.padding.left + self.padding.right)
		self.height = math.max(self.min_height, max_height + self.padding.top + self.padding.bottom)
	elseif self.type == 'column' then
		local max_width = 0
		local total_height = self:get_child_height()

		for _, child in ipairs(self.children) do
			max_width = math.max(max_width, child.width)
		end

		self.width = math.max(self.min_width, max_width + self.padding.left + self.padding.right)
		self.height = math.max(self.min_height, total_height + self.padding.top + self.padding.bottom)
	elseif self.type == 'panel' then
		self.width = self.children[1].width + self.padding.left + self.padding.right
		self.height = self.children[1].height + self.padding.top + self.padding.bottom
	end
	if self.print_data then
		print(self.height)
	end
end

function Container:get_child_width()
	local total = 0
	for _, child in ipairs(self.children) do
		total = total + child.width
	end
	total = total + (#self.children - 1) * self.separation
	return total
end

function Container:get_child_height()
	local total = 0
	for _, child in ipairs(self.children) do
		total = total + child.height
	end
	total = total + (#self.children - 1) * self.separation
	return total
end

function Container:calculate_layout()
	self:calculate_size()

	local x, y = self:get_position()

	local content_width = self.width - self.padding.left - self.padding.right
	local content_height = self.height - self.padding.top - self.padding.bottom

	local start_x, start_y
	if self.type == 'row' then
		if self.justify == Justify.Start then
			start_x = x + self.padding.left
		elseif self.justify == Justify.Center then
			start_x = x + self.padding.left + (content_width - self:get_child_width()) / 2
		else -- END
			start_x = x + self.padding.left + (content_width - self:get_child_width())
		end
	elseif self.type == 'column' or self.type == 'panel' then
		if self.justify == Justify.Start then
			start_y = y + self.padding.top
		elseif self.justify == Justify.Center then
			start_y = y + self.padding.top + (content_height - self:get_child_height()) / 2
		else -- END
			start_y = y + self.padding.top + (content_height - self:get_child_height())
		end
	end

	-- Position each child
	for _, child in ipairs(self.children) do
		if self.type == 'row' then
			child.x = start_x
			if self.align == Align.Start then
				child.y = y + self.padding.top
			elseif self.align == Align.Center then
				child.y = y + self.padding.top + (content_height - child.height) / 2
			elseif self.align == Align.End then
				child.y = y + self.padding.top + content_height - child.height
			end
			start_x = start_x + child.width + self.separation
		elseif self.type == 'column' or self.type == 'panel' then
			child.y = start_y
			if self.align == Align.Start then
				child.x = x + self.padding.left
			elseif self.align == Align.Center then
				child.x = x + self.padding.left + (content_width - child.width) / 2
			elseif self.align == Align.End then
				child.x = x + self.padding.left + content_width - child.width
			end
			start_y = start_y + child.height + self.separation
		end

		if child.calculate_layout then
			child:calculate_layout()
		end
	end
end

function Container:draw()
	if not self.visible then
		return
	end
	if Settings.debug.draw_ui_containers then
		if self.is_pressed then
			love.graphics.setColor(1, 1, 0)
		else
			love.graphics.setColor(1, 0, 0)
		end
		local x, y = self:get_position()
		if self.is_hovered then
			love.graphics.rectangle('fill', x, y, self.width, self.height)
		else
			love.graphics.rectangle('line', x, y, self.width, self.height)
		end
		love.graphics.setColor(1, 1, 1)
	end

	for _, child in ipairs(self.children) do
		child:draw()
	end
end

function Container:update(delta)
	Node.update(self, delta)
	for _, child in ipairs(self.children) do
		child:update(delta)
	end
end

function Container:set_children(children)
	self.children = children
	self:calculate_layout()
end

local Row = Container:extend()

function Row:init(args)
	self.type = 'row'
	Container.init(self, args)
end

local Column = Container:extend()

function Column:init(args)
	self.type = 'column'
	Container.init(self, args)
end

local Panel = Container:extend()

function Panel:init(args)
	assert(#args <= 1, 'Panel containers only support a single child')
	self.type = 'panel'
	Container.init(self, args)
	self.text = args.text
	self.line_color = args.line_color
	self.bg_color = args.bg_color
	self.font = args.font

	self.children = args
end

function Panel:draw()
	if not self.visible then
		return
	end
	local x, y = self:get_position()

	if self.bg_color then
		self.bg_color:set()
		love.graphics.rectangle('fill', x, y, self.width, self.height)
	end

	if self.line_color then
		self.line_color:set()
		love.graphics.rectangle('line', x, y, self.width, self.height)
	end

	if self.text then
		local label_x = math.floor(x + 40)
		local label_y = math.floor(y - self.font:getHeight() / 2) - 1
		local label_width = self.font:getWidth(self.text)
		love.graphics.setFont(self.font)
		self.bg_color:set()
		love.graphics.rectangle('fill', label_x - 10, y - 1, label_width + 20, 2)

		self.line_color:set()
		love.graphics.print(self.text, label_x, label_y)
	end

	Container.draw(self)
end

local Label = Node:extend()

function Label:init(args)
	Node.init(self, args)
	self.text = args.text or ''

	self.width = self.style.font:getWidth(self.text)
	self.height = self.style.font:getHeight()
end

function Label:draw()
	if not self.visible then
		return
	end
	self.style.text_color:set()
	love.graphics.setFont(self.style.font)
	love.graphics.print(
		self.text,
		math.floor(self.x + self.width / 2),
		math.floor(self.y + self.height / 2),
		self.rotation,
		self.scale,
		self.scale,
		math.floor(self.width / 2),
		math.floor(self.height / 2)
	)
end

local Paragraph = Node:extend()

function Paragraph:init(args)
	Node.init(self, args)
	self.text = args.text or ''
	self.wrap_width = args.wrap_width

	self.width = math.max(self.style.font:getWidth(self.text), self.wrap_width)
	local _, wrappedLines = self.style.font:getWrap(self.text, self.wrap_width)
	self.height = #wrappedLines * self.style.font:getHeight()
end

function Paragraph:draw()
	if not self.visible then
		return
	end
	self.style.text_color:set()
	love.graphics.setFont(self.style.font)
	love.graphics.printf(
		self.text,
		math.floor(self.x + self.width / 2),
		math.floor(self.y + self.height / 2),
		self.wrap_width,
		'left',
		self.rotation,
		self.scale,
		self.scale,
		math.floor(self.width / 2),
		math.floor(self.height / 2)
	)
end

local Button = Node:extend()

function Button:init(args)
	Node.init(self, args)
	self.sfx = args.sfx or { 'ui_click' }
	self.text = args.text
	if args.on_pressed then
		self.on_pressed = function()
			if self.disabled then
				return
			end
			if args.on_pressed then
				args.on_pressed(self)
			end
		end
	end
	if args.on_released then
		self.on_released = function()
			if self.disabled then
				return
			end
			if args.on_released then
				args.on_released(self)
			end
		end
	end

	if self.width == 0 then
		self.width = math.floor(self.style.font:getWidth(self.text) + 10)
	end
	if self.height == 0 then
		self.height = math.floor(self.style.font:getHeight() + 3)
	end
	self.drawn_height = self.height - 5
end

function Button:get_bg_color()
	if self.disabled then
		return Colors.Tan
	else
		return self.style.bg_color
	end
end

function Button:draw()
	if not self.visible then
		return
	end
	local x, y = self:get_position()
	x = math.floor(x)
	y = math.floor(y)

	local text_width = self.style.font:getWidth(self.text)
	local text_height = self.style.font:getHeight()

	local fill_color = self:get_bg_color()
	fill_color:set()
	love.graphics.rectangle('fill', x + 2, y + 2, self.width - 5, self.height - 5)

	Colors.FullWhite:set()
	love.graphics.rectangle('line', x, y, self.width, self.height)

	Colors.Black:set()
	love.graphics.setFont(self.style.font)
	local label_x = math.floor(x + self.width / 2)
	local label_y = math.floor(y + self.height / 2)
	love.graphics.print(
		self.text,
		label_x,
		label_y,
		0,
		1,
		1,
		math.floor(text_width / 2),
		math.floor(text_height / 2)
	)

	return
end

local Image = Node:extend()

function Image:init(args)
	Node.init(self, args)

	local utils = require 'engine.utils'
	utils.dump_table(args)
	self.texture = args.texture

	self.width = self.texture:getWidth() * self.scale
	self.height = self.texture:getHeight() * self.scale
end

function Image:draw()
	if not self.visible then
		return
	end
	local x, y = self:get_position()
	Colors.FullWhite:set()
	love.graphics.draw(self.texture, x, y, self.rotation, self.scale, self.scale)
end

-- Usefull stuff

local CenteredColumn = Column:extend()

function CenteredColumn:init(args)
	Column.init(
		self,
		{
			x = game_size.x / 2,
			y = game_size.y / 2,
			anchor = Anchor.CenterCenter,
			align = Align.Center,
			separation = 10,
			unpack(args)
		}
	)
end

local function Padding(amount)
	return {
		top = amount,
		bottom = amount,
		left = amount,
		right = amount
	}
end

return {
	Column = Column,
	CenteredColumn = CenteredColumn,
	Container = Container,
	Align = Align,
	Justify = Justify,
	Anchor = Anchor,
	Row = Row,
	UI = UI,
	Label = Label,
	Image = Image,
	Button = Button,
	Panel = Panel,
	Padding = Padding,
	Paragraph = Paragraph
}
