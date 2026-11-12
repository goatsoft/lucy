--!strict
--[[
	Arrow: a big arrow that points at something on screen, grows in and keeps
	moving to catch the eye. Lucy.Tour points with it; a game can point at a HUD
	button, a door prompt or a new item with it too.

		Arrow.new({
			direction = "down",   -- down | up | left | right: the way it points
			variant = "arrow",    -- arrow | chevron | triangle
			motion = "bounce",    -- bounce | pulse | none
			size = "md",          -- sm | md | lg, or pixels (the arrow's square)
			color = "Ring",       -- a theme token or a Color3
			icon = nil,           -- an icon name: your own art, drawn pointing down
			Position = UDim2.fromOffset(x, y), -- where the tip goes
			Parent = gui,
		})
		arrow:replay()            -- grow in again (it also does when shown again)

	State keys: direction, variant, motion, size, color, icon, visible.
	Parts: arrow.body (moves), arrow.scale (its UIScale), arrow.shape (turned to
	the direction), arrow.parts.arrow / chevron / triangle, arrow.icon (an Icon,
	made the first time `icon` is set), arrow.fade() (the transparency now).

	Its AnchorPoint is its tip, so Position is where it points. The shapes are
	frames, so they need no upload. An icon replaces the shape: draw your art
	pointing down and it is turned like the shape; it keeps the Icon's colours.

	Motion: it grows in with a small overshoot, then bounces back from its tip and
	in again, or pulses in place. With reduced motion (Core/Preferences) it fades
	in instead and stays still; a pulse becomes a gentle fade in and out.
]]

local RunService = game:GetService("RunService")

local Animate = require(script.Parent.Parent.Core.Animate)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Arrow = {}

Arrow.variants = { "arrow", "chevron", "triangle" }
Arrow.motions = { "bounce", "pulse", "none" }
Arrow.directions = { "down", "up", "left", "right" }
Arrow.sizes = { sm = 24, md = 40, lg = 56 }
-- Seconds: the grow, the reduced-motion fade, and one bounce or pulse.
Arrow.timing = { grow = 0.45, fade = 0.3, period = 0.8 }
-- How far a bounce travels (a share of the size), how much a pulse swells,
-- and how far a reduced-motion pulse fades.
Arrow.travel = 0.25
Arrow.swell = 0.08
Arrow.breathe = 0.3

local TIP = {
	down = Vector2.new(0.5, 1),
	up = Vector2.new(0.5, 0),
	left = Vector2.new(0, 0.5),
	right = Vector2.new(1, 0.5),
}
local TURN = { down = 0, up = 180, left = 90, right = -90 }
local AWAY = {
	down = Vector2.new(0, -1),
	up = Vector2.new(0, 1),
	left = Vector2.new(1, 0),
	right = Vector2.new(-1, 0),
}

Arrow.rules = {
	{
		selector = ".ui-arrow-part",
		priority = 0,
		properties = { BorderSizePixel = 0 },
	},
	{ selector = ".ui-arrow-bar::UICorner", priority = 0, properties = { CornerRadius = UDim.new(0.5, 0) } },
} :: { Component.Rule }

local function check(list: { string }, value: any, what: string)
	if not table.find(list, value) then
		error(`[Lucy] unknown Arrow {what} "{tostring(value)}" (expected {table.concat(list, ", ")})`, 0)
	end
end

-- Ease out with a small overshoot past 1 (easeOutBack).
function Arrow.ease(p: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (p - 1) ^ 3 + c1 * (p - 1) ^ 2
end

-- 0 at the tip, 1 at the far end of a bounce, `t` seconds into the motion.
function Arrow.bounce(t: number): number
	return math.abs(math.sin(math.pi * t / Arrow.timing.period))
end

local function pixels(size: any): number
	if type(size) == "number" then
		return size
	end
	local named = Arrow.sizes[size]
	if named == nil then
		error(`[Lucy] unknown Arrow size "{tostring(size)}" (expected sm, md, lg or pixels)`, 0)
	end
	return named
end

local spec: Component.Spec = {
	kind = "arrow",
	defaults = {
		direction = "down",
		variant = "arrow",
		motion = "bounce",
		size = "md",
		color = "Ring",
		icon = "",
		visible = true,
	},
	rules = Arrow.rules,
	render = function(h)
		local app = h.app
		check(Arrow.directions, h:get("direction"), "direction")
		check(Arrow.variants, h:get("variant"), "variant")
		check(Arrow.motions, h:get("motion"), "motion")
		local direction, variant, motion = h:ref("direction"), h:ref("variant"), h:ref("motion")
		local sizeRef, colorRef, iconRef, visible =
			h:ref("size"), h:ref("color"), h:ref("icon"), h:ref("visible")

		local themeTick = Reactive.ref(0)
		local themeConn = app.theme.Changed:Connect(function()
			themeTick(themeTick() + 1)
		end)
		local color = Reactive.computed(function(): Color3
			themeTick()
			local value = colorRef()
			if typeof(value) == "Color3" then
				return value
			end
			local name = if type(value) == "string" then string.gsub(value, "^%$", "") else "Ring"
			local resolved = app.theme:resolve(name)
			return if typeof(resolved) == "Color3" then resolved else Color3.new(1, 1, 1)
		end)
		local size = Reactive.computed(function(): number
			return pixels(sizeRef())
		end)
		local hasIcon = Reactive.computed(function(): boolean
			local value = iconRef()
			return type(value) == "string" and value ~= ""
		end)
		local fade = Reactive.ref(0)
		h.fade = function(): number
			return fade()
		end

		-- One rounded bar of a shape, in shares of the arrow's square (drawn pointing down).
		local function bar(name: string, x: number, y: number, w: number, hgt: number, turn: number): Frame
			return Element.new("Frame", {
				Name = name,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				Size = UDim2.fromScale(w, hgt),
				Rotation = turn,
				BackgroundColor3 = color,
				BackgroundTransparency = fade,
				Tags = { "ui-arrow-part", "ui-arrow-bar" },
			}) :: Frame
		end
		local function group(name: string, shown: string, children: { Instance }): Frame
			local frame = Element.new("Frame", {
				Name = name,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = function()
					return variant() == shown and not hasIcon()
				end,
			}) :: Frame
			for _, child in children do
				child.Parent = frame
			end
			return frame
		end

		-- arrow: a shaft and a head, w thick, the tip at the bottom middle.
		local w, arm = 0.16, 0.42
		local tipY = 1 - w / 2
		local reach = arm / (2 * math.sqrt(2))
		local arrowShape = group("Arrow", "arrow", {
			bar("Shaft", 0.5, (w / 2 + tipY) / 2, w, tipY - w / 2 + w, 0),
			bar("ArmLeft", 0.5 - reach, tipY - reach, arm + w, w, 45),
			bar("ArmRight", 0.5 + reach, tipY - reach, arm + w, w, -45),
		})

		-- chevron: a bold head alone.
		local cw, carm, ctip = 0.18, 0.6, 0.78
		local creach = carm / (2 * math.sqrt(2))
		local chevronShape = group("Chevron", "chevron", {
			bar("ArmLeft", 0.5 - creach, ctip - creach, carm + cw, cw, 45),
			bar("ArmRight", 0.5 + creach, ctip - creach, carm + cw, cw, -45),
		})

		-- triangle: a diamond with its top half cut away by a hard gradient.
		local diamond = Element.new("Frame", {
			Name = "Diamond",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1 / math.sqrt(2), 1 / math.sqrt(2)),
			Rotation = 45,
			BackgroundColor3 = color,
			BackgroundTransparency = fade,
			Tags = { "ui-arrow-part" },
			Element.new("UIGradient", {
				Rotation = 45,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.499, 1),
					NumberSequenceKeypoint.new(0.501, 0),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
		}) :: Frame
		local triangleShape = group("Triangle", "triangle", { diamond })

		local shape = Element.new("Frame", {
			Name = "Shape",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Rotation = function(): number
				return TURN[direction()] or 0
			end,
			arrowShape,
			chevronShape,
			triangleShape,
		}) :: Frame

		local scale = Instance.new("UIScale")
		local body = Element.new("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			AnchorPoint = function(): Vector2
				return TIP[direction()] or TIP.down
			end,
			shape,
		}) :: Frame
		scale.Parent = body

		h.parts = { arrow = arrowShape, chevron = chevronShape, triangle = triangleShape }
		h.shape, h.body, h.scale = shape, body, scale

		-- The icon, made the first time one is set, in a scope of its own: a component
		-- made in a watch callback would go when the watch runs again.
		local iconScope = Reactive.effectScope(true)
		Reactive.onCleanup(function()
			iconScope:stop()
		end)
		Reactive.watch(iconRef, function(value)
			if h.icon == nil and type(value) == "string" and value ~= "" then
				local last = value
				iconScope:run(function()
					h.icon = Icon.new({
						app = app,
						icon = function(): string
							local now = iconRef()
							if type(now) == "string" and now ~= "" then
								last = now
							end
							return last
						end,
						size = function(): number
							return size()
						end,
						visible = function(): boolean
							return hasIcon()
						end,
						Parent = shape,
					})
					Element.hydrate(h.icon.Instance, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						ImageTransparency = fade,
					})
				end)
			end
		end, { immediate = true })

		-- Motion, on the frame clock from when it was shown.
		local shownAt = Animate.now()
		local function step()
			local t = Animate.now() - shownAt
			local timing = Arrow.timing
			local still = Preferences.reducedMotion()
			local kind = Reactive.peek(motion)
			local px: number = Reactive.untrack(function(): number
				return size()
			end)
			local grow, transparency, settled
			if still then
				grow = 1
				transparency = 1 - math.min(t / timing.fade, 1)
				settled = t - timing.fade
			else
				grow = Arrow.ease(math.min(t / timing.grow, 1))
				transparency = 0
				settled = t - timing.grow
			end
			local travel, swell = 0, 1
			if settled > 0 then
				if still then
					if kind == "pulse" then
						transparency = Arrow.breathe
							* (0.5 - 0.5 * math.cos(2 * math.pi * settled / timing.period))
					end
				elseif kind == "bounce" then
					travel = Arrow.travel * px * Arrow.bounce(settled)
				elseif kind == "pulse" then
					swell = 1 + Arrow.swell * math.sin(2 * math.pi * settled / timing.period)
				end
			end
			scale.Scale = grow * swell
			local tip = TIP[Reactive.peek(direction)] or TIP.down
			local away = AWAY[Reactive.peek(direction)] or AWAY.down
			body.Position = UDim2.new(tip.X, math.round(away.X * travel), tip.Y, math.round(away.Y * travel))
			fade(transparency)
		end
		h._replay = function()
			shownAt = Animate.now()
			step()
		end

		local beat: RBXScriptConnection? = nil
		local stopDrive: (() -> ())? = nil
		Reactive.watch(visible, function(on)
			if beat then
				beat:Disconnect()
				beat = nil
			end
			if stopDrive then
				stopDrive()
				stopDrive = nil
			end
			if on then
				shownAt = Animate.now()
				step()
				if Animate.manual then
					stopDrive = Animate.drive(function()
						step()
						return false
					end)
				else
					beat = RunService.Heartbeat:Connect(step)
				end
			end
		end, { immediate = true })
		Reactive.watch(direction, function()
			step()
		end)
		Reactive.onCleanup(function()
			themeConn:Disconnect()
			if beat then
				beat:Disconnect()
				beat = nil
			end
			if stopDrive then
				stopDrive()
				stopDrive = nil
			end
		end)

		return Element.new("Frame", {
			Name = "Arrow",
			BackgroundTransparency = 1,
			AnchorPoint = function(): Vector2
				local name = direction()
				check(Arrow.directions, name, "direction")
				return TIP[name]
			end,
			Size = function(): UDim2
				local px = size()
				return UDim2.fromOffset(px, px)
			end,
			Visible = visible,
			Tags = {
				"ui-arrow" :: any,
				function()
					local name = variant()
					check(Arrow.variants, name, "variant")
					return "ui-arrow-variant-" .. name
				end,
				function()
					local name = motion()
					check(Arrow.motions, name, "motion")
					return "ui-arrow-motion-" .. name
				end,
			},
			body,
		})
	end,
}

function Arrow.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	function handle.replay(h)
		if h._replay then
			h._replay()
		end
	end
	return handle
end

return Arrow
