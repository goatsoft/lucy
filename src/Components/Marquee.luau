--!strict
--[[
	Marquee: one line of text that scrolls back and forth when it is too long to fit,
	holding a moment at each end, or with loop on goes round and round like a ticker.
	For song titles, tickers and names on boards.

		Marquee.new({ text = "Future Bounce VIP (Extended Club Mix)", variant = "large" })

	variant: the Text variants (h1 to h4, p, lead, large, small, muted, label)
	speed    pixels a second while it moves (40)
	pause    seconds it holds at each end (1.5); with loop, only before it first moves
	loop     scrolls on round in one direction, a copy of the text following the first,
	         and carries on from where it was when the text changes
	gap      pixels between the text and its copy when it loops (48)
	richText Roblox rich text tags

	Text that fits stays still, left aligned. It only moves while visible, and stays
	still, cut at the edge, when the player asks for reduced motion.

	State keys: text, variant, visible.
	handle.strip is the moving TextLabel; handle.scrolling says whether it is moving.
	handle.repeatStrip is the loop's copy: it follows the strip's text styling, so style the strip.
]]

local RunService = game:GetService("RunService")

local Animate = require(script.Parent.Parent.Core.Animate)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Text = require(script.Parent.Text)

local Marquee = {}

-- Where GUI layout runs live (edit mode, a client). A running server lays guis out only when read
-- and fires no AbsoluteSize changes, so there the Marquee looks every frame instead.
local function laysOutLive(): boolean
	return not (RunService:IsServer() and RunService:IsRunning())
end

Marquee.speed = 40
Marquee.pause = 1.5
Marquee.gap = 48

-- The text styling the loop's copy takes from the strip
local MIRRORED = {
	"TextSize",
	"TextColor3",
	"TextTransparency",
	"TextStrokeColor3",
	"TextStrokeTransparency",
	"FontFace",
	"LineHeight",
}

local function check(variant: string)
	if Text.variants[variant] == nil then
		error(`[Lucy] unknown Marquee variant "{variant}"`, 0)
	end
end

-- How much the UIScales above an instance shrink or grow it on screen, all together (its
-- offsets times this are its pixels)
function Marquee.scaleOf(instance: Instance): number
	local scale = 1
	local node: Instance? = instance
	while node do
		local ui = node:FindFirstChildWhichIsA("UIScale")
		if ui and ui.Scale > 0 then
			scale *= ui.Scale
		end
		node = node.Parent
	end
	return scale
end

-- Where the strip is `t` seconds into a cycle: hold, move to the end, hold, move back.
function Marquee.offsetAt(t: number, overflow: number, speed: number, pause: number): number
	local travel = overflow / speed
	local cycle = 2 * (pause + travel)
	local at = t % cycle
	if at < pause then
		return 0
	elseif at < pause + travel then
		return (at - pause) * speed
	elseif at < 2 * pause + travel then
		return overflow
	end
	return overflow - (at - 2 * pause - travel) * speed
end

-- Where a looping strip is `t` seconds in: still for `pause`, then on round at `speed`, starting
-- again after `period` pixels (one text and its gap), where its copy has taken its place.
function Marquee.loopOffsetAt(t: number, period: number, speed: number, pause: number): number
	if t < pause or period <= 0 then
		return 0
	end
	return ((t - pause) * speed) % period
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "marquee",
	defaults = { text = "", variant = "p", visible = true },
	-- The strip is styled as Text, by Text's own rules.
	rules = Text.rules,
	ruleKey = "text",
	render = function(h)
		local p: Component.Props = h.props
		check(h:get("variant")) -- an unknown variant fails the mount
		local variant, text, visible = h:ref("variant"), h:ref("text"), h:ref("visible")
		local speed: number = p.speed or Marquee.speed
		local pause: number = p.pause or Marquee.pause
		local loop = p.loop == true
		local gap: number = p.gap or Marquee.gap
		local offset = Reactive.ref(0)
		local copyAt = Reactive.ref(0)
		local looping = Reactive.ref(false)

		local strip = Element.new("TextLabel", {
			Name = "Strip",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			TextWrapped = false,
			RichText = p.richText == true,
			Text = text,
			Position = function()
				return UDim2.fromOffset(-math.floor(offset() + 0.5), 0)
			end,
			Tags = {
				"ui-text" :: any,
				function()
					local name = variant()
					check(name)
					return "ui-text-variant-" .. name
				end,
			},
		})
		h.strip = strip

		-- The loop's copy, one text and a gap after the strip, styled as the strip is
		local copy: TextLabel? = nil
		if loop then
			local c = Element.new("TextLabel", {
				Name = "StripRepeat",
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				TextWrapped = false,
				RichText = p.richText == true,
				Text = text,
				Visible = looping,
				Position = function()
					return UDim2.fromOffset(math.floor(copyAt() + 0.5), 0)
				end,
				Tags = {
					"ui-text" :: any,
					function()
						return "ui-text-variant-" .. variant()
					end,
				},
			}) :: TextLabel
			for _, property in MIRRORED do
				local function follow()
					(c :: any)[property] = (strip :: any)[property]
				end
				follow()
				local conn = strip:GetPropertyChangedSignal(property):Connect(follow)
				Reactive.onCleanup(function()
					conn:Disconnect()
				end)
			end
			copy = c
		end
		h.repeatStrip = copy

		local frame = Element.new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ClipsDescendants = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = visible,
			Tags = { "ui-marquee" },
			strip,
			copy,
		})

		-- Side effect: move the strip while visible, from the start each time the text changes. A
		-- loop is a ticker: a new text carries on from where the old one was, so its clock lives here.
		-- A frame step runs only while the text is too long: a board of short names costs nothing a
		-- frame, and a size change (a resize, a longer name laid out) starts or stops it.
		h.scrolling = false
		local loopClock = 0
		Reactive.watchEffect(function()
			text()
			local on = visible() == true and not Preferences.reducedMotion()
			if not loop or not on then
				offset(0)
				looping(false)
				loopClock = 0
			end
			h.scrolling = false
			if not on then
				return
			end
			local t = if loop then loopClock else 0
			local live = laysOutLive()
			-- Sizes on screen, in the offsets the strip moves by: a UIScale above (Lucy's own on a
			-- phone) makes an offset smaller on screen, so divide it back out
			local function measure(): (number, number)
				local scale = Marquee.scaleOf(frame)
				local width = strip.AbsoluteSize.X / scale
				return width, width - frame.AbsoluteSize.X / scale
			end
			local function rest()
				t = 0
				h.scrolling = false
				offset(0)
				looping(false)
			end
			-- One frame; true when the text fits now, which ends the stepping (where a size change
			-- will start it again)
			local function stepFrame(dt: number): boolean
				local width, overflow = measure()
				if overflow <= 1 then
					rest()
					return live
				end
				t += dt
				h.scrolling = true
				if loop then
					loopClock = t
					local at = Marquee.loopOffsetAt(t, width + gap, speed, pause)
					offset(at)
					copyAt(width + gap - at)
					looping(true)
				else
					offset(Marquee.offsetAt(t, overflow, speed, pause))
				end
				return false
			end
			local stop: (() -> ())? = nil
			local function run()
				if stop then
					return
				end
				if Animate.manual then
					local done = false
					local disconnect = Animate.drive(function(dt: number): boolean
						done = done or stepFrame(dt)
						if done then
							stop = nil
						end
						return done
					end)
					if not done then
						stop = disconnect
					end
				else
					local heartbeat: RBXScriptConnection
					heartbeat = RunService.Heartbeat:Connect(function(dt: number)
						if stepFrame(dt) then
							heartbeat:Disconnect()
							stop = nil
						end
					end)
					stop = function()
						heartbeat:Disconnect()
					end
				end
			end
			local function check()
				local _, overflow = measure()
				if overflow > 1 or not live then
					run()
				elseif not stop then
					rest()
				end
			end
			local sized = {
				strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(check),
				frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(check),
			}
			check()
			Reactive.onCleanup(function()
				for _, connection in sized do
					connection:Disconnect()
				end
				if stop then
					stop()
					stop = nil
				end
				h.scrolling = false
				-- A loop's copy stays up across a text change (no blink); hiding it is the effect's job
				if not loop then
					looping(false)
				end
			end)
		end)
		return frame
	end,
}

function Marquee.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Marquee
