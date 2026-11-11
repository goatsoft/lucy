--!strict
--[[
	Gradient: one of the theme's gradients on what it is in. A theme names its gradients as tokens
	(Tokens.gradient, "Gradient<Name>"), so a game's gradients change with the theme like any
	other colour, and the game picks one by name.

		Gradient.new({
			gradient = "Surface",   -- the token after "Gradient": GradientSurface (built in: Surface, Primary)
			rotation = 90,          -- degrees: 90 runs top to bottom, 0 left to right
			Parent = frame,
		})

	It is a UIGradient on its parent, so the parent's corners and outline keep it, and its
	children sit on top. A gradient tints the colour under it, so while it is on, the parent's fill
	is white (the ui-gradient-host tag) and the gradient's own colours show; the parent's
	transparency still applies. It tints the parent's own words too (a text-only Button draws
	them on itself), so it warns in Studio on a parent that shows text: put the words in a child.

	State keys: gradient, rotation, visible.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Gradient = {}

local HOST = "ui-gradient-host"

local rules: { Component.Rule } = {
	-- Above a component's own fill (its variants and states), below focus
	{ selector = "." .. HOST, priority = 90, properties = { BackgroundColor3 = "$White" } },
}
Gradient.rules = rules

-- The tag and the rule for one gradient token, added to the theme the first time it is used
local function tagFor(name: string): string
	return "ui-gradient-" .. string.lower(name)
end

local function rulesFor(name: string): { Component.Rule }
	return {
		{ selector = "." .. tagFor(name), priority = 0, properties = { Color = "$Gradient" .. name } },
	}
end

local spec: Component.Spec = {
	kind = "gradient",
	defaults = { gradient = "Surface", rotation = 90, visible = true },
	rules = Gradient.rules,
	render = function(h)
		local name, rotation, visible = h:ref("gradient"), h:ref("rotation"), h:ref("visible")
		-- The named gradient's tag; its rule joins the theme the first time the name is used
		local function named(): string
			local current = name()
			h.app.theme:addRules("gradient-" .. current, rulesFor(current))
			return tagFor(current)
		end
		return Element.new("UIGradient", {
			Rotation = rotation,
			Enabled = visible,
			Tags = { "ui-gradient" :: any, named },
		})
	end,
	mounted = function(h)
		-- The parent's fill goes white while the gradient is on it and showing
		local instance = h.Instance :: UIGradient
		local host: Instance? = nil
		local function release()
			if host then
				CollectionService:RemoveTag(host, HOST)
				host = nil
			end
		end
		local function hold()
			local parent = instance.Parent
			local want = if parent and parent:IsA("GuiObject") and instance.Enabled then parent else nil
			if want ~= host then
				release()
				if want then
					CollectionService:AddTag(want, HOST)
					host = want
					-- Its own words would take the gradient's colours (Studio only, once per host)
					local texty = want:IsA("TextButton") or want:IsA("TextLabel")
					local words = if texty then (want :: any).Text else ""
					if RunService:IsStudio() and words ~= "" then
						warn(
							`Lucy.Gradient: {want:GetFullName()} shows its own text ("{words}"), which the gradient tints too; put the words in a child (a Button with an icon, or a Text inside)`
						)
					end
				end
			end
		end
		hold()
		h.maid:give(instance.AncestryChanged:Connect(hold))
		h.maid:give(instance:GetPropertyChangedSignal("Enabled"):Connect(hold))
		h.maid:give(release)
	end,
}

function Gradient.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

-- The colours a gradient token has in the current theme, for code that draws its own
-- (a ColorSequence)
function Gradient.colors(app: any, name: string): ColorSequence
	return app.theme:resolve("Gradient" .. name)
end

-- A property as it shows: what a style rule set (GetStyled), else the instance's own
local function styled(instance: Instance, property: string): any
	local ok, value = pcall(function()
		return (instance :: any):GetStyled(property)
	end)
	return if ok and value ~= nil then value else (instance :: any)[property]
end

-- The gradient drawn on `object` (a Gradient, or any UIGradient), if one is on and showing
function Gradient.on(object: Instance): UIGradient?
	for _, child in object:GetChildren() do
		if child:IsA("UIGradient") and child.Enabled then
			return child
		end
	end
	return nil
end

-- The colour a sequence has at t, 0 to 1, blended as a UIGradient blends it
function Gradient.at(sequence: ColorSequence, t: number): Color3
	local points = sequence.Keypoints
	t = math.clamp(t, 0, 1)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if t <= b.Time then
			local span = b.Time - a.Time
			return if span <= 0 then b.Value else a.Value:Lerp(b.Value, (t - a.Time) / span)
		end
	end
	return points[#points].Value
end

-- Where a screen point falls along a UIGradient on `host`, 0 at its start to 1 at its end
-- (its rotation and offset taken in)
function Gradient.along(gradient: UIGradient, host: GuiObject, point: Vector2): number
	local angle = math.rad(styled(gradient, "Rotation") :: number)
	local direction = Vector2.new(math.cos(angle), math.sin(angle))
	local size = host.AbsoluteSize
	local reach = math.abs(size.X * direction.X) + math.abs(size.Y * direction.Y)
	if reach <= 0 then
		return 0
	end
	local offset = styled(gradient, "Offset") :: Vector2
	local centre = host.AbsolutePosition + size / 2 + offset * size
	return (point - centre):Dot(direction) / reach + 0.5
end

-- The colours `host` shows on the way from one screen point to another, as a sequence that runs
-- from the first to the second: its fill tinted by its gradient. For something drawn over part
-- of a gradient that must match it there (ScrollArea's edge fades).
function Gradient.between(
	gradient: UIGradient,
	host: GuiObject,
	from: Vector2,
	to: Vector2,
	fill: Color3
): ColorSequence
	local sequence = styled(gradient, "Color") :: ColorSequence
	local steps = 4
	local points = {}
	for i = 0, steps do
		local t = i / steps
		local color = Gradient.at(sequence, Gradient.along(gradient, host, from:Lerp(to, t)))
		table.insert(
			points,
			ColorSequenceKeypoint.new(t, Color3.new(color.R * fill.R, color.G * fill.G, color.B * fill.B))
		)
	end
	return ColorSequence.new(points)
end

return Gradient
