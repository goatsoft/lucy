--!strict
--[[
	Switch

		Switch.new({
			label = "Music",
			checked = true,
			disabled = false,
			onCheckedChange = function(checked, switch) end,
		})
		switch:toggle()

	Track and thumb grow with density (36x20 desktop, 44x24 touch, 52x28 console);
	the whole row is the hit area. State keys: checked, label, disabled, visible.
]]

local TweenService = game:GetService("TweenService")

local Component = require(script.Parent.Parent.Core.Component)

local Switch = {}

local TRACK = {
	default = Vector2.new(36, 20),
	touch = Vector2.new(44, 24),
	tv = Vector2.new(52, 28),
}

local rules: { Component.Rule } = {
	{
		selector = ".ui-switch",
		priority = 0,
		properties = { BackgroundColor3 = "$Input", BorderSizePixel = 0 },
	},
	{ selector = ".ui-switch::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-switch.ui-checked",
		priority = 10,
		properties = { BackgroundColor3 = "$Primary" },
		transitions = { BackgroundColor3 = TweenInfo.new(0.15) },
	},
	{
		selector = ".ui-switch-thumb",
		priority = 0,
		properties = { BackgroundColor3 = "$Background", BorderSizePixel = 0 },
	},
	{ selector = ".ui-switch-thumb::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-switch-label",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-switch.ui-disabled", priority = 30, properties = { BackgroundTransparency = 0.5 } },
	{ selector = ".ui-switch-label.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
}
Switch.rules = rules

function Switch.new(props: { [string]: any }?)
	local p: Component.Props = props or {}
	local handle
	handle = Component.mount({
		kind = "switch",
		props = p,
		defaults = { checked = false, label = "", disabled = false, visible = true },
		rules = Switch.rules,
		render = function(h)
			local root = Component.create("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Tags = { "ui-switch-root" },
			})
			Component.list({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				Parent = root,
			})
			local track = Component.create(
				"Frame",
				{ Name = "Track", LayoutOrder = 1, Tags = { "ui-switch" }, Parent = root }
			)
			local thumb = Component.create("Frame", {
				Name = "Thumb",
				AnchorPoint = Vector2.new(0, 0.5),
				Tags = { "ui-switch-thumb" },
				Parent = track,
			})
			local label = Component.create("TextLabel", {
				Name = "Label",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 2,
				Tags = { "ui-switch-label" },
				Parent = root,
			})
			h.track, h.thumb, h.label = track, thumb, label
			h.maid:give(root.Activated:Connect(function()
				h:toggle()
			end))
			return root
		end,
		-- Incremental: only keys that changed touch the instances. A toggle is a tag
		-- flip plus replaying one of two prebuilt thumb tweens.
		update = function(h, state, previous)
			local first = previous == nil
			local before: Component.State = previous or {}
			if first or before.visible ~= state.visible then
				h.Instance.Visible = state.visible
			end
			if first or before.disabled ~= state.disabled then
				h.Instance.Interactable = not state.disabled
				h.Instance.Selectable = not state.disabled
				Component.setFlag(h.track, "ui-disabled", state.disabled)
				Component.setFlag(h.label, "ui-disabled", state.disabled)
			end
			if first or before.label ~= state.label then
				h.label.Text = state.label
				h.label.Visible = state.label ~= ""
			end
			if first or before.checked ~= state.checked then
				Component.setFlag(h.track, "ui-checked", state.checked)
				if h.placeThumb then
					h.placeThumb(not first)
				end
			end
			if not first and before.checked ~= state.checked and p.onCheckedChange then
				p.onCheckedChange(state.checked, h)
			end
		end,
	})

	-- Size from density: runs once and on density changes, and rebuilds the two
	-- thumb tweens (Play on one overrides the other, so they can be replayed).
	local SLIDE = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
	local positions: { [boolean]: UDim2 } = {}
	local tweens: { [boolean]: Tween } = {}

	-- Moves the thumb to match `checked`; slides only when asked and on screen.
	function handle.placeThumb(animate: boolean)
		local checked = handle:get("checked") == true
		if animate and handle.Instance.Parent then
			tweens[checked]:Play()
		else
			tweens[not checked]:Cancel()
			handle.thumb.Position = positions[checked]
		end
	end

	Component.onDensity(handle, function()
		local density = handle.app.theme:getDensity()
		local size = TRACK[density] or TRACK.default
		local knob = size.Y - 4
		handle.track.Size = UDim2.fromOffset(size.X, size.Y)
		handle.thumb.Size = UDim2.fromOffset(knob, knob)
		handle.Instance.Size =
			UDim2.fromOffset(0, math.max(Component.metric(handle.app, "ControlSm"), size.Y))
		positions[true] = UDim2.new(0, size.X - knob - 2, 0.5, 0)
		positions[false] = UDim2.new(0, 2, 0.5, 0)
		for _, on in { true, false } do
			if tweens[on] then
				tweens[on]:Cancel()
			end
			tweens[on] = TweenService:Create(handle.thumb, SLIDE, { Position = positions[on] })
		end
		handle.placeThumb(false)
	end)

	function handle.toggle(h)
		if h:get("disabled") then
			return
		end
		h:set({ checked = not h:get("checked") })
	end
	return handle
end

return Switch
