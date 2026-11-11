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
	transparency still applies.

	State keys: gradient, rotation, visible.
]]

local CollectionService = game:GetService("CollectionService")

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

return Gradient
