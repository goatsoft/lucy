--!strict
--[[
	Image: a picture, such as a dance icon, a song cover or a shop item.

		Image.new({
			image = 12345,            -- an asset id, or any content url (rbxassetid://, rbxthumb://)
			fit = "contain",          -- contain | cover | fill | tile
			size = UDim2.fromOffset(64, 64),
			aspectRatio = 1,          -- optional: keeps width / height
			rounded = "md",           -- optional: none | sm | md | lg | xl | full
			Parent = card,
		})

	State keys: image, fit, visible. Image.url(value) turns an id into a url.
	For icons that follow the theme's colours, use Icon.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

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
}
for name, radius in RADII do
	table.insert(rules, {
		selector = `.ui-image-rounded-{name}::UICorner`,
		priority = 10,
		properties = { CornerRadius = radius },
	})
end
Image.rules = rules

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
		return Element.new("ImageLabel", {
			Size = p.size or UDim2.fromOffset(64, 64),
			Image = function()
				return Image.url(image())
			end,
			ScaleType = function()
				return checkFit(fit())
			end,
			Visible = h:ref("visible"),
			Tags = if rounded then { "ui-image", "ui-image-rounded-" .. rounded } else { "ui-image" },
			ratio :: any,
		})
	end,
}

function Image.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Image
