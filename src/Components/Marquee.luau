--!strict
--[[
	Marquee: one line of text that scrolls back and forth when it is too long to fit,
	holding a moment at each end. For song titles, tickers and names on boards.

		Marquee.new({ text = "Future Bounce VIP (Extended Club Mix)", variant = "large" })

	variant: the Text variants (h1 to h4, p, lead, large, small, muted, label)
	speed    pixels a second while it moves (40)
	pause    seconds it holds at each end (1.5)
	richText Roblox rich text tags

	Text that fits stays still, left aligned. It only moves while visible, and stays
	still, cut at the edge, when the player asks for reduced motion.

	State keys: text, variant, visible.
	handle.strip is the moving TextLabel; handle.scrolling says whether it is moving.
]]

local RunService = game:GetService("RunService")

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Text = require(script.Parent.Text)

local Marquee = {}

Marquee.speed = 40
Marquee.pause = 1.5

local function check(variant: string)
	if Text.variants[variant] == nil then
		error(`[Lucy] unknown Marquee variant "{variant}"`, 0)
	end
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
		local offset = Reactive.ref(0)

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

		local frame = Element.new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ClipsDescendants = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = visible,
			Tags = { "ui-marquee" },
			strip,
		})

		-- Side effect: move the strip while visible, from the start each time the text changes.
		h.scrolling = false
		Reactive.watchEffect(function()
			text()
			local on = visible() == true and not Preferences.reducedMotion()
			offset(0)
			h.scrolling = false
			if not on then
				return
			end
			local t = 0
			local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
				local overflow = strip.AbsoluteSize.X - frame.AbsoluteSize.X
				if overflow <= 1 then
					t = 0
					h.scrolling = false
					offset(0)
					return
				end
				t += dt
				h.scrolling = true
				offset(Marquee.offsetAt(t, overflow, speed, pause))
			end)
			Reactive.onCleanup(function()
				heartbeat:Disconnect()
				h.scrolling = false
			end)
		end)
		return frame
	end,
}

function Marquee.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Marquee
