--!strict
--[[
	Progress

		local bar = Progress.new({ id = "reload", value = 30, max = 100 })
		app.state:set("ui.reload.value", 75)

		variant = "default"   -- default | success | warning | destructive (the bar's colour)

	State keys: value, max, variant, visible. The value is clamped to 0..max.

	Stepped: with `steps = n` the bar becomes a rail of n numbered markers (a battle pass's tiers,
	a quest's stages). `value` is then in steps: the fill reaches marker i's centre at value i, and
	a marker is lit once the value reaches it. `max` is not used. `stepSize` is a marker's size in
	pixels (28). Markers are evenly spaced, marker i centred at (i - 0.5) / n of the width, so a
	row of n equal columns above or below lines up with them.

		Progress.new({ steps = 100, value = function() return tier() + xp() / perTier end, height = 10 })
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Slot = require(script.Parent.Slot)

local Progress = {}

Progress.shapes = { "bar", "circle", "stars" }
Progress.sizes = { sm = 28, md = 34, lg = 40 }
Progress.starSizes = { sm = 16, md = 22, lg = 28 }
Progress.defaultCircleSize = 34
Progress.defaultStarSize = 22

-- Hard transparency cut at 0.5 so rotating UIGradient sweeps each half-ring cleanly.
local RING_CUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local rules: { Component.Rule } = {
	{
		selector = ".ui-progress",
		priority = 0,
		properties = { BackgroundColor3 = "$Secondary", BorderSizePixel = 0 },
	},
	{ selector = ".ui-progress::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-progress-indicator",
		priority = 0,
		properties = { BackgroundColor3 = "$Color", BorderSizePixel = 0 },
	},
	{
		selector = ".ui-progress-indicator::UICorner",
		priority = 0,
		properties = { CornerRadius = "$RadiusFull" },
	},
	-- Circular ring rules
	{
		selector = ".ui-progress-circle",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-progress-ring-circle",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-progress-ring-circle::UICorner",
		priority = 0,
		properties = { CornerRadius = "$RadiusFull" },
	},
	{
		selector = ".ui-progress-ring-track",
		priority = 0,
		properties = {
			Color = "$Secondary",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-progress-ring-track.ui-progress-ring-default-thickness",
		priority = 0,
		properties = { Thickness = "$StrokeThick" },
	},
	{
		selector = ".ui-progress-ring-stroke",
		priority = 0,
		properties = {
			Color = "$Color",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-progress-ring-stroke.ui-progress-ring-default-thickness",
		priority = 0,
		properties = { Thickness = "$StrokeThick" },
	},
}
Progress.variants = { "default", "success", "warning", "destructive" }
local COLOURS = { success = "$Success", warning = "$Warning", destructive = "$Destructive" }
for variant, colour in COLOURS do
	table.insert(rules, {
		selector = `.ui-progress-variant-{variant} > .ui-progress-indicator`,
		priority = 10,
		properties = { BackgroundColor3 = colour },
	})
	table.insert(rules, {
		selector = `.ui-progress-variant-{variant} >> .ui-progress-ring-stroke`,
		priority = 10,
		properties = { Color = colour },
	})
	table.insert(rules, {
		selector = `.ui-progress-variant-{variant} >> .ui-progress-star-fill`,
		priority = 10,
		properties = { TextColor3 = colour },
	})
end
-- Star meter (shape = "stars"): a row of n stars that fill smoothly left-to-right
table.insert(rules, {
	selector = ".ui-progress-star-track",
	priority = 0,
	properties = {
		BackgroundTransparency = 1,
		TextColor3 = "$MutedForeground",
		TextTransparency = 0.65,
		FontFace = "$FontDisplay",
	},
})
table.insert(rules, {
	selector = ".ui-progress-star-fill",
	priority = 0,
	properties = {
		BackgroundTransparency = 1,
		TextColor3 = "$Color",
		FontFace = "$FontDisplay",
	},
})
-- Stepped (steps = n): numbered markers over the bar, lit up to the value
table.insert(rules, {
	selector = ".ui-progress-step",
	priority = 0,
	properties = {
		BackgroundColor3 = "$Secondary",
		TextColor3 = "$SecondaryForeground",
		FontFace = "$FontSansSemibold",
		TextSize = "$TextSm",
		BorderSizePixel = 0,
	},
})
table.insert(
	rules,
	{ selector = ".ui-progress-step::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } }
)
table.insert(rules, {
	selector = ".ui-progress-step-on",
	priority = 5,
	properties = { BackgroundColor3 = "$Color", TextColor3 = "$ColorForeground" },
})
Progress.rules = rules

local function checkVariant(variant: string)
	if not table.find(Progress.variants, variant) then
		error(
			`[Lucy] unknown Progress variant "{variant}" (expected {table.concat(Progress.variants, ", ")})`,
			0
		)
	end
end

local function checkShape(shape: string)
	if not table.find(Progress.shapes, shape) then
		error(`[Lucy] unknown Progress shape "{shape}" (expected {table.concat(Progress.shapes, ", ")})`, 0)
	end
end

-- One tag per variant, built once.
local variantTag: { [string]: string } = {}
for _, variant in Progress.variants do
	variantTag[variant] = "ui-progress-variant-" .. variant
end

function Progress.fraction(value: number, max: number): number
	if max <= 0 then
		return 0
	end
	return math.clamp(value / max, 0, 1)
end

-- Clockwise sweep angles (degrees) for the right and left clipped half-rings.
function Progress.ringAngles(fraction: number): (number, number)
	local f = math.clamp(fraction, 0, 1)
	return math.clamp(f, 0, 0.5) * 360, 180 + math.clamp(f - 0.5, 0, 0.5) * 360
end

-- Stepped: how full the bar is for a value in steps. The fill reaches marker i's centre at
-- value i; before the first marker it grows toward it.
function Progress.stepFraction(value: number, steps: number): number
	if steps <= 0 or value <= 0 then
		return 0
	end
	if value < 1 then
		return value * 0.5 / steps
	end
	return math.clamp((value - 0.5) / steps, 0, 1)
end

-- Star meter: fill fraction (0..1) for star `index` out of `count` stars
function Progress.starFill(value: number, max: number, count: number, index: number): number
	if max <= 0 or count <= 0 then
		return 0
	end
	local perStar = max / count
	if perStar <= 0 then
		return 0
	end
	return math.clamp(value / perStar - (index - 1), 0, 1)
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "progress",
	defaults = { value = 0, max = 100, variant = "default", shape = "bar", visible = true },
	rules = Progress.rules,
	render = function(h)
		local p: Component.Props = h.props
		-- An unknown variant or shape fails the mount; later writes report like any effect.
		checkVariant(h:get("variant"))
		checkShape(h:get("shape"))
		local value, max, variant = h:ref("value"), h:ref("max"), h:ref("variant")
		local shape = h:ref("shape")
		local function variantTagNow(): string
			local v = variant()
			checkVariant(v)
			return variantTag[v]
		end
		if shape() == "stars" then
			local count = math.max(1, math.floor(tonumber(p.count) or tonumber(p.max) or 5))
			local gap = tonumber(p.gap) or 4
			local starSize: number
			if type(p.size) == "number" then
				starSize = p.size
			elseif type(p.size) == "string" and Progress.starSizes[p.size] then
				starSize = Progress.starSizes[p.size]
			else
				starSize = Progress.defaultStarSize
			end
			local starGlyph = if type(p.glyph) == "string" and #p.glyph > 0 then p.glyph else "\u{2605}"
			local starChildren: { any } = {
				Element.new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, gap),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}
			h.stars = {}
			for i = 1, count do
				local starIndex = i
				local fillClip = Element.new("Frame", {
					Name = "FillClip",
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Size = function(): UDim2
						local f = Progress.starFill(value(), max(), count, starIndex)
						return UDim2.fromScale(f, 1)
					end,
					ZIndex = 2,
					Element.new("TextLabel", {
						Name = "Fill",
						Size = UDim2.fromOffset(starSize, starSize),
						Text = starGlyph,
						TextSize = starSize,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						Tags = { "ui-progress-star-fill" },
					}),
				})
				local cell = Element.new("Frame", {
					Name = `Star{i}`,
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(starSize, starSize),
					LayoutOrder = i,
					Element.new("TextLabel", {
						Name = "Track",
						Size = UDim2.fromOffset(starSize, starSize),
						Text = starGlyph,
						TextSize = starSize,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 1,
						Tags = { "ui-progress-star-track" },
					}),
					fillClip,
				})
				h.stars[i] = cell
				table.insert(starChildren, cell)
			end
			local totalWidth = count * starSize + math.max(0, count - 1) * gap
			return Element.new("Frame", {
				Name = "Stars",
				Size = UDim2.fromOffset(totalWidth, starSize),
				BackgroundTransparency = 1,
				Visible = h:ref("visible"),
				Tags = { "ui-progress-stars" :: any, variantTagNow },
				starChildren,
			})
		end
		if shape() == "circle" then
			local function frac(): number
				return Progress.fraction(value(), max())
			end
			local function showTrack(): boolean
				local tv = p.trackVisible
				if type(tv) == "function" then
					return tv() ~= false
				end
				return tv ~= false
			end
			local function diameter(): number
				local raw = if type(p.size) == "function" then p.size() else p.size
				if type(raw) == "number" then
					return raw
				elseif type(raw) == "string" and Progress.sizes[raw] then
					return Progress.sizes[raw]
				end
				return Progress.defaultCircleSize
			end
			local defaultThicknessTag = if p.thickness == nil
				then "ui-progress-ring-default-thickness"
				else nil
			local trackStrokeProps: { [string]: any } = {
				Name = "Stroke",
				Tags = { "ui-progress-ring-track" :: any, defaultThicknessTag },
			}
			if p.thickness ~= nil then
				trackStrokeProps.Thickness = p.thickness
			end
			local trackStroke = Element.new("UIStroke", trackStrokeProps) :: UIStroke
			local track = Element.new("Frame", {
				Name = "Track",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
				Visible = showTrack,
				Tags = { "ui-progress-ring-circle" },
				trackStroke,
			}) :: Frame

			local rightGradient = Element.new("UIGradient", {
				Name = "Sweep",
				Transparency = RING_CUT,
				Rotation = function(): number
					local r = Progress.ringAngles(frac())
					return r
				end,
			}) :: UIGradient
			local rightStrokeProps: { [any]: any } = {
				Name = "Stroke",
				Tags = { "ui-progress-ring-stroke" :: any, defaultThicknessTag },
				rightGradient,
			}
			if p.thickness ~= nil then
				rightStrokeProps.Thickness = p.thickness
			end
			local rightStroke = Element.new("UIStroke", rightStrokeProps) :: UIStroke
			local rightCircle = Element.new("Frame", {
				Name = "RightCircle",
				Position = UDim2.fromScale(-1, 0),
				Size = UDim2.fromScale(2, 1),
				Tags = { "ui-progress-ring-circle" },
				rightStroke,
			}) :: Frame
			local rightHalf = Element.new("Frame", {
				Name = "RightHalf",
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				ZIndex = 2,
				Visible = function(): boolean
					return showTrack() and frac() > 0
				end,
				rightCircle,
			}) :: Frame

			local leftGradient = Element.new("UIGradient", {
				Name = "Sweep",
				Transparency = RING_CUT,
				Rotation = function(): number
					local _, l = Progress.ringAngles(frac())
					return l
				end,
			}) :: UIGradient
			local leftStrokeProps: { [any]: any } = {
				Name = "Stroke",
				Tags = { "ui-progress-ring-stroke" :: any, defaultThicknessTag },
				leftGradient,
			}
			if p.thickness ~= nil then
				leftStrokeProps.Thickness = p.thickness
			end
			local leftStroke = Element.new("UIStroke", leftStrokeProps) :: UIStroke
			local leftCircle = Element.new("Frame", {
				Name = "LeftCircle",
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(2, 1),
				Tags = { "ui-progress-ring-circle" },
				leftStroke,
			}) :: Frame
			local leftHalf = Element.new("Frame", {
				Name = "LeftHalf",
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				ZIndex = 2,
				Visible = function(): boolean
					return showTrack() and frac() > 0.5
				end,
				leftCircle,
			}) :: Frame

			local contentFrame = Element.new("Frame", {
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 3,
				Element.new("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
			}) :: Frame
			if p.content ~= nil then
				if type(p.content) == "function" then
					local built = p.content(h)
					if built ~= nil then
						Slot.fill(contentFrame, built, { app = h.app, startOrder = 0 })
					end
				else
					Slot.fill(contentFrame, p.content, { app = h.app, startOrder = 0 })
				end
			end
			if p.children ~= nil then
				Slot.fill(contentFrame, p.children, { app = h.app, startOrder = 0 })
			end

			h.track = track
			h.trackStroke = trackStroke
			h.rightHalf = rightHalf
			h.leftHalf = leftHalf
			h.rightStroke = rightStroke
			h.leftStroke = leftStroke
			h.rightGradient = rightGradient
			h.leftGradient = leftGradient
			h.indicator = rightStroke
			h.content = contentFrame

			return Element.new("Frame", {
				Size = function(): UDim2
					local px = diameter()
					return UDim2.fromOffset(px, px)
				end,
				Visible = h:ref("visible"),
				Tags = { "ui-progress-circle" :: any, variantTagNow },
				track,
				rightHalf,
				leftHalf,
				contentFrame,
			})
		end
		if type(p.steps) == "number" and p.steps >= 1 then
			local steps = math.floor(p.steps)
			local stepSize = p.stepSize or 28
			h.indicator = Element.new("Frame", {
				Name = "Indicator",
				Size = function()
					return UDim2.fromScale(Progress.stepFraction(value(), steps), 1)
				end,
				Tags = { "ui-progress-indicator" },
			})
			local children: { any } = {
				Element.new("Frame", {
					Name = "Bar",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.new(1, 0, 0, p.height or 8),
					ClipsDescendants = true,
					Tags = { "ui-progress" :: any, variantTagNow },
					h.indicator,
				}),
			}
			h.steps = {}
			for i = 1, steps do
				local marker = Element.new("TextLabel", {
					Name = `Step{i}`,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale((i - 0.5) / steps, 0.5),
					Size = UDim2.fromOffset(stepSize, stepSize),
					Text = tostring(i),
					ZIndex = 2,
					Tags = {
						"ui-progress-step" :: any,
						function(): string?
							return if value() >= i then "ui-progress-step-on" else nil
						end,
					},
				})
				h.steps[i] = marker
				table.insert(children, marker)
			end
			return Element.new("Frame", {
				Size = UDim2.new(1, 0, 0, math.max(stepSize, p.height or 8)),
				BackgroundTransparency = 1,
				Visible = h:ref("visible"),
				Tags = { "ui-progress-stepped" },
				children,
			})
		end
		h.indicator = Element.new("Frame", {
			Name = "Indicator",
			Size = function()
				return UDim2.fromScale(Progress.fraction(value(), max()), 1)
			end,
			Tags = { "ui-progress-indicator" },
		})
		return Element.new("Frame", {
			Size = UDim2.new(1, 0, 0, p.height or 8),
			ClipsDescendants = true,
			Visible = h:ref("visible"),
			Tags = {
				"ui-progress" :: any,
				function(): string
					local v = variant()
					checkVariant(v)
					return variantTag[v]
				end,
			},
			h.indicator,
		})
	end,
}

function Progress.new(props: { [string]: any }?)
	if props and (props.variant == "circle" or props.variant == "circular" or props.shape == "circular") then
		local out = table.clone(props)
		if out.variant == "circle" or out.variant == "circular" then
			out.shape = "circle"
			out.variant = "default"
		elseif out.shape == "circular" then
			out.shape = "circle"
		end
		return Component.mount(spec, out)
	end
	return Component.mount(spec, props)
end

Component.define(spec)

return Progress
