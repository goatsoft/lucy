--!strict
--[[
	IconStack: several icons drawn as one, overlapping. One icon repeated (a cluster of hearts
	that grows with a reward), or different icons placed by hand (a badge on a shield).

		IconStack.new({
			icon = "lucide:heart",    -- the icon every layer draws unless it names its own
			count = 3,                -- how many to arrange
			arrange = "fan",          -- fan | row | pile
			size = "lg",              -- the biggest icon: sm | md | lg | xl, or pixels; larger on TV
			variant = "destructive",  -- as Icon's, for every layer that names none
			cutout = true,            -- a ring round each icon, in the colour under the stack,
			                          -- so icons that overlap stay apart
			Parent = card,
		})

	The arrangements:
	- fan: the biggest in the middle and on top, each further out smaller, lower and tilted
	  away, like a hand of cards.
	- row: the same size in a line, each a little over the one before.
	- pile: rows that get shorter going up, the bottom row in front.

	Or place each layer yourself, and `count` and `arrange` are not used:

		layers = {
			{ icon = "lucide:shield" },
			{ icon = "lucide:star", x = 0.3, y = 0.3, size = 0.5, rotation = 15, variant = "warning" },
		}

	A layer's x and y are how far it sits from the middle, in icons (0.5 is half an icon
	right or down), size is a share of the stack's size (1 is the biggest), rotation is in
	degrees, and z puts it in front (higher) or behind; layers that give no z go in the
	order listed, the last on top. The stack is as big as its icons, so a layout gives
	all of them room.

	The cutout ring takes $Card. A stack on another colour sets its own rule, such as
	`.my-card >> .ui-icon-stack-cutout` with `ImageColor3 = "$Primary"`.

	State keys: icon, count, arrange, layers, size, variant, cutout, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Icon = require(script.Parent.Icon)

local IconStack = {}

IconStack.arrangements = { "fan", "row", "pile" }
-- How thick the cutout ring is, as a share of the stack's size, on each side
IconStack.cutout = 0.1

local rules: { Component.Rule } = {
	{
		selector = ".ui-icon-stack-cutout",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0, ImageColor3 = "$Card" },
	},
}
IconStack.rules = rules

export type Layer = {
	icon: any?,
	x: number?,
	y: number?,
	size: number?,
	rotation: number?,
	variant: string?,
	z: number?,
}

-- One placed layer: everything filled in, and its place in front to back order
type Placed = {
	icon: any,
	x: number,
	y: number,
	size: number,
	rotation: number,
	variant: string,
	cutout: boolean,
	order: number,
}

-- The arrangements, as layers for `count` icons
local ARRANGE: { [string]: (count: number) -> { Layer } } = {
	fan = function(count)
		local layers = {}
		local middle = (count + 1) / 2
		for i = 1, count do
			local out = i - middle
			local far = math.abs(out)
			table.insert(layers, {
				x = out * 0.5,
				y = far * 0.1,
				size = math.max(0.5, 1 - 0.12 * far),
				rotation = out * 12,
				z = -far,
			})
		end
		return layers
	end,
	row = function(count)
		local layers = {}
		local middle = (count + 1) / 2
		for i = 1, count do
			table.insert(layers, { x = (i - middle) * 0.6 })
		end
		return layers
	end,
	pile = function(count)
		-- The fewest rows that hold them all, the bottom row the longest
		local rows = 1
		while rows * (rows + 1) / 2 < count do
			rows += 1
		end
		local layers = {}
		local left = count
		for row = 0, rows - 1 do
			local across = math.min(rows - row, left)
			left -= across
			for i = 1, across do
				table.insert(layers, {
					x = (i - (across + 1) / 2) * 0.62,
					y = -row * 0.5,
					size = 1 - 0.1 * row,
					z = -row,
				})
			end
			if left <= 0 then
				break
			end
		end
		return layers
	end,
}

local function checkArrange(arrange: string)
	if ARRANGE[arrange] == nil then
		error(
			`[Lucy] unknown IconStack arrange "{arrange}" (expected {table.concat(
				IconStack.arrangements,
				", "
			)})`,
			0
		)
	end
end

local function pixels(size: any): number
	if type(size) == "number" then
		return size
	end
	local px = Icon.sizes[size]
	if px == nil then
		error(`[Lucy] unknown IconStack size "{tostring(size)}" (expected sm, md, lg, xl or pixels)`, 0)
	end
	return px
end

-- The layers to draw, filled in, with each one's place from back (1) to front
local function place(state: { [string]: any }): { Placed }
	local given: { Layer } | false = state.layers
	local layers: { Layer }
	if given and #given > 0 then
		layers = given
	else
		checkArrange(state.arrange)
		layers = ARRANGE[state.arrange](math.max(1, math.floor(state.count)))
	end
	local placed: { Placed } = {}
	local z: { number } = {}
	for i, layer in layers do
		placed[i] = {
			icon = if layer.icon ~= nil then layer.icon else state.icon,
			x = layer.x or 0,
			y = layer.y or 0,
			size = layer.size or 1,
			rotation = layer.rotation or 0,
			variant = layer.variant or state.variant,
			cutout = state.cutout == true,
			order = 0,
		}
		z[i] = layer.z or 0
	end
	local byDepth = table.create(#placed)
	for i = 1, #placed do
		byDepth[i] = i
	end
	-- Lowest z at the back; the same z in the order listed
	table.sort(byDepth, function(a, b)
		if z[a] ~= z[b] then
			return z[a] < z[b]
		end
		return a < b
	end)
	for rank, i in byDepth do
		placed[i].order = rank
	end
	return placed
end

-- How far a square of side `side` reaches from its middle once turned by `rotation`
local function reach(side: number, rotation: number): number
	local turn = math.rad(rotation)
	return side / 2 * (math.abs(math.cos(turn)) + math.abs(math.sin(turn)))
end

-- The box round every layer (and its ring), in icons: its middle and its size
local function bounds(placed: { Placed }, ring: number): (number, number, number, number)
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	for _, layer in placed do
		local half = reach(layer.size + ring * 2, layer.rotation)
		minX = math.min(minX, layer.x - half)
		maxX = math.max(maxX, layer.x + half)
		minY = math.min(minY, layer.y - half)
		maxY = math.max(maxY, layer.y + half)
	end
	return (minX + maxX) / 2, (minY + maxY) / 2, maxX - minX, maxY - minY
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "icon-stack",
	defaults = {
		icon = "",
		count = 1,
		arrange = "fan",
		layers = false,
		size = "md",
		variant = "default",
		cutout = false,
		visible = true,
	},
	rules = IconStack.rules,
	render = function(h)
		-- A bad size or arrangement fails the mount; later writes report like any effect.
		pixels(h:get("size"))
		if not h:get("layers") then
			checkArrange(h:get("arrange"))
		end
		local icon, count, arrange, layers = h:ref("icon"), h:ref("count"), h:ref("arrange"), h:ref("layers")
		local size, variant, cutout = h:ref("size"), h:ref("variant"), h:ref("cutout")
		local density = Composables.useDensity(h.app)

		local placed = Reactive.computed(function(): { Placed }
			return place({
				icon = icon(),
				count = count(),
				arrange = arrange(),
				layers = layers(),
				variant = variant(),
				cutout = cutout(),
			})
		end)
		-- The stack's size in pixels as drawn: the biggest icon, grown on TV like an Icon
		local unit = Reactive.computed(function(): number
			return pixels(size()) * (Icon.scale[density()] or 1)
		end)
		local box = Reactive.computed(function(): { number }
			local cx, cy, w, hgt = bounds(placed(), if cutout() then IconStack.cutout else 0)
			return { cx, cy, w, hgt }
		end)
		local function position(layer: Placed): UDim2
			local b, u = box(), unit()
			return UDim2.new(0.5, math.round((layer.x - b[1]) * u), 0.5, math.round((layer.y - b[2]) * u))
		end

		return Element.new("Frame", {
			BackgroundTransparency = 1,
			Size = function()
				local b, u = box(), unit()
				return UDim2.fromOffset(math.ceil(b[3] * u), math.ceil(b[4] * u))
			end,
			Visible = h:ref("visible"),
			Tags = { "ui-icon-stack" },
			Element.each(placed, function(layer: Placed)
				-- The icon, an Icon of the layer's share of the size (Icon grows it on TV)
				local drawn = Icon.new({
					app = h.app,
					icon = layer.icon,
					variant = layer.variant,
					size = Reactive.computed(function(): number
						return math.max(1, math.round(pixels(size()) * layer.size))
					end),
				})
				Element.hydrate(drawn.Instance, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = function()
						return position(layer)
					end,
					Rotation = layer.rotation,
					ZIndex = layer.order * 2,
				})
				if not layer.cutout then
					return drawn
				end
				-- Its ring: the same picture a little bigger, just behind it and in front of every
				-- icon further back (a change of cutout lays the layers out again)
				local resolved = Icon.resolve(layer.icon)
				local ring = Element.new("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					ScaleType = Enum.ScaleType.Fit,
					Image = if resolved then resolved.image else "",
					ImageRectOffset = if resolved then resolved.offset else Vector2.zero,
					ImageRectSize = if resolved then resolved.size else Vector2.zero,
					Size = function()
						local px = math.round(unit() * (layer.size + IconStack.cutout * 2))
						return UDim2.fromOffset(px, px)
					end,
					Position = function()
						return position(layer)
					end,
					Rotation = layer.rotation,
					ZIndex = layer.order * 2 - 1,
					Tags = { "ui-icon-stack-cutout" },
				})
				return { drawn, ring }
			end),
		})
	end,
}

function IconStack.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

Component.define(spec)

return IconStack
