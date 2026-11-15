--!strict
--[[
	Effect type "shine" (Components/Effect): a polished button or card catching the light. Now and
	then a slanted band of light sweeps across it, left to right, kept inside its rounded corners,
	then it rests until the next glint. Nothing is drawn outside its box, so a shiny gold button
	stays a button rather than gaining a ring.

		local button = Lucy.Button.new({ text = "UNLOCK VIP+", Parent = row })
		Lucy.Effect.new({ type = "shine", radius = 12, Parent = button.Instance })

	The effect fills its box (it is not kept square): give it the box of the thing it lights, or
	parent it to that thing, over its fill and under its words.

	Options: radius (the corner radius in pixels, to match the thing it lights; default 8), every
	(seconds from one glint to the next; default 2.8), sweep (seconds a glint takes to cross;
	default 0.75), width (the band's width, a share of the box's width; default 0.35), slant
	(degrees the band leans; default 20), strength (how bright the band is at its middle, 0 to 1;
	default 0.85). The first glint runs as it appears. With reduced motion there is no glint.

	Parts on the handle: clip (the frame that keeps the light inside, inset from the edges by a
	share of the radius), glint (the band) and fade (its UIGradient). Tags: ui-effect-shine-glint and ui-effect-shine-<variant>;
	the band is white, warm white for warning.
]]

local Component = require(script.Parent.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Parent.Core.Element)

local rules: { Component.Rule } = {
	{
		selector = ".ui-effect-shine-glint",
		priority = 0,
		properties = { BackgroundColor3 = "$White", BackgroundTransparency = 0, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-effect-shine-glint.ui-effect-shine-warning",
		priority = 10,
		properties = { BackgroundColor3 = Color3.fromRGB(255, 252, 236) },
	},
}

-- The band across its width: clear at its edges, brightest in the middle (strength)
local function band(strength: number): NumberSequence
	local peak = 1 - math.clamp(strength, 0, 1)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 1 - (1 - peak) * 0.45),
		NumberSequenceKeypoint.new(0.5, peak),
		NumberSequenceKeypoint.new(0.65, 1 - (1 - peak) * 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
end

return {
	intro = 0,
	loop = true,
	fill = true, -- the picture takes the whole box, whatever its shape
	defaults = { radius = 8, every = 2.8, sweep = 0.75, width = 0.35, slant = 20, strength = 0.85 },
	rules = rules,
	render = function(ctx: any): Instance
		local radius = math.max(0, tonumber(ctx.option("radius")) or 8)
		local sweep = math.max(0.05, tonumber(ctx.option("sweep")) or 0.75)
		local every = math.max(sweep, tonumber(ctx.option("every")) or 2.8)
		local width = math.clamp(tonumber(ctx.option("width")) or 0.35, 0.05, 1)
		local slant = tonumber(ctx.option("slant")) or 20
		local strength = tonumber(ctx.option("strength")) or 0.85

		-- 0 to 1 across the box while a glint runs; nil while it rests
		local function progress(): number?
			local t = ctx.elapsed() % every
			return if t < sweep then t / sweep else nil
		end

		local fade = Element.new("UIGradient", { Transparency = band(strength) })
		local glint = Element.new("Frame", {
			Name = "Glint",
			AnchorPoint = Vector2.new(0.5, 0.5),
			-- Tall enough that, leaning, it still crosses the box from top to bottom
			Size = UDim2.fromScale(width, 3),
			Rotation = slant,
			Position = function(): UDim2
				local p = progress()
				-- From fully off the left edge to fully off the right; off to the left at rest
				local x = if p then -width + p * (1 + 2 * width) else -width
				return UDim2.fromScale(x, 0.5)
			end,
			Visible = function(): boolean
				return progress() ~= nil
			end,
			Tags = function(): { string }
				return { "ui-effect-shine-glint", "ui-effect-shine-" .. ctx.variant() }
			end,
			fade,
		})
		-- A plain clipping frame (a CanvasGroup would round the clip, but crashed Studio with no
		-- size yet), inset from the edges by a share of the radius, so the light keeps inside the
		-- rounded corners: a soft band crossing a corner's cut-off sliver is too faint to see
		local inset = math.ceil(radius * 0.3)
		local clip = Element.new("Frame", {
			Name = "Shine",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Active = false,
			glint,
		})
		ctx.handle.clip = clip
		ctx.handle.glint = glint
		ctx.handle.fade = fade
		return clip
	end,
}
