--!strict
--[[
	Image: a picture, such as a dance icon, a song cover or a shop item.

		Image.new({
			image = 12345,            -- an asset id, or any content url (rbxassetid://, rbxthumb://)
			fit = "contain",          -- contain | cover | fill | tile
			size = UDim2.fromOffset(64, 64),
			aspectRatio = 1,          -- optional: keeps width / height
			rounded = "md",           -- optional: none | sm | md | lg | xl | full
			placeholder = true,       -- a pulsing $Muted box until the picture loads (default)
			Parent = card,
		})

	While the picture loads, a placeholder pulses in its place and fades away once it is there;
	one fetched already (Lucy.preload, Core/Preload) shows at once with none. placeholder = false
	leaves it out.

	State keys: image, fit, visible. Image.url(value) turns an id into a url.
	For icons that follow the theme's colours, use Icon.
]]

local TweenService = game:GetService("TweenService")

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Preload = require(script.Parent.Parent.Core.Preload)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Image = {}

Image.fits = {
	contain = Enum.ScaleType.Fit,
	cover = Enum.ScaleType.Crop,
	fill = Enum.ScaleType.Stretch,
	tile = Enum.ScaleType.Tile,
}

local RADII = {
	none = "$Space0",
	sm = "$RadiusSm",
	md = "$RadiusMd",
	lg = "$RadiusLg",
	xl = "$RadiusXl",
	full = "$RadiusFull",
}

local rules: { Component.Rule } = {
	{
		selector = ".ui-image",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-image-placeholder",
		priority = 0,
		properties = { BackgroundColor3 = "$Muted", BorderSizePixel = 0 },
	},
}
for name, radius in RADII do
	table.insert(rules, {
		selector = `.ui-image-rounded-{name}::UICorner`,
		priority = 10,
		properties = { CornerRadius = radius },
	})
end
Image.rules = rules

-- The placeholder's pulse while loading, and its fade once the picture is there
Image.pulse = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
Image.fade = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- The pulsing box over a picture until it loads; fades out, then hides
local function placeholder(label: ImageLabel, url: () -> string, rounded: string?)
	local tags = { "ui-image-placeholder" }
	if rounded then
		table.insert(tags, "ui-image-rounded-" .. rounded)
	end
	local box = Element.new("Frame", {
		Name = "Placeholder",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Visible = false,
		Tags = tags,
		Element.new("UICorner", {}),
	}) :: Frame
	box.Parent = label
	local loaded = Reactive.ref(label.IsLoaded)
	local connection = label:GetPropertyChangedSignal("IsLoaded"):Connect(function()
		loaded(label.IsLoaded)
	end)
	local pulse = TweenService:Create(box, Image.pulse, { BackgroundTransparency = 0.5 })
	local fade: Tween? = nil
	Reactive.watchEffect(function()
		local current = url()
		-- Fetched already (Lucy.preload) or nothing to show: no placeholder at all
		local waiting = current ~= "" and not loaded() and not Preload.isLoaded(current)
		if fade then
			fade:Cancel()
			fade = nil
		end
		if waiting then
			box.BackgroundTransparency = 0
			box.Visible = true
			pulse:Play()
		elseif box.Visible then
			pulse:Cancel()
			local out = TweenService:Create(box, Image.fade, { BackgroundTransparency = 1 })
			out.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					box.Visible = false
				end
			end)
			fade = out
			out:Play()
		end
	end)
	Reactive.onCleanup(function()
		connection:Disconnect()
		pulse:Cancel()
		if fade then
			fade:Cancel()
		end
	end)
end

-- A content url for an asset id (a number or a numeric string); urls pass through.
function Image.url(value: any): string
	if type(value) == "number" then
		return if value > 0 then "rbxassetid://" .. tostring(value) else ""
	end
	if type(value) == "string" then
		if string.match(value, "^%d+$") then
			return "rbxassetid://" .. value
		end
		return value
	end
	return ""
end

local function checkFit(fit: string): Enum.ScaleType
	local scale = Image.fits[fit]
	if scale == nil then
		error(`[Lucy] unknown Image fit "{fit}" (expected contain, cover, fill or tile)`, 0)
	end
	return scale
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "image",
	defaults = { image = "", fit = "contain", visible = true },
	rules = Image.rules,
	render = function(h)
		local p: Component.Props = h.props
		checkFit(h:get("fit"))
		local rounded: string? = p.rounded
		if rounded ~= nil and RADII[rounded] == nil then
			error(`[Lucy] unknown Image rounded "{rounded}" (expected none, sm, md, lg, xl or full)`, 0)
		end
		local image, fit = h:ref("image"), h:ref("fit")
		local ratio: UIAspectRatioConstraint? = nil
		if p.aspectRatio then
			ratio = Element.new("UIAspectRatioConstraint", { AspectRatio = p.aspectRatio })
		end
		local function url(): string
			return Image.url(image())
		end
		local label = Element.new("ImageLabel", {
			Size = p.size or UDim2.fromOffset(64, 64),
			Image = url,
			ScaleType = function()
				return checkFit(fit())
			end,
			Visible = h:ref("visible"),
			Tags = if rounded then { "ui-image", "ui-image-rounded-" .. rounded } else { "ui-image" },
			ratio :: any,
		}) :: ImageLabel
		if p.placeholder ~= false then
			placeholder(label, url, rounded)
		end
		return label
	end,
}

function Image.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Image
