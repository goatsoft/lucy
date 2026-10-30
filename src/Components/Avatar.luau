--!strict
--[[
	Avatar: a player's headshot, or a monogram for a bot or an empty slot.

		Avatar.new({
			userId = player.UserId,   -- 0 or below shows the monogram
			name = player.DisplayName, -- the monogram's initials
			size = "md",              -- sm | md | lg
			square = false,           -- rounded corners instead of a circle
			Parent = row,
		})

	State keys: userId, name, size, visible.
	Parts: avatar.image (the headshot), avatar.monogram (the initials).
	Avatar.headshot(userId) and Avatar.initials(name) are the helpers it uses.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)

local Avatar = {}

Avatar.sizes = { sm = 32, md = 40, lg = 56 }

local TEXT = { sm = "$TextXs", md = "$TextSm", lg = "$TextBase" }

local rules: { Component.Rule } = {
	{
		selector = ".ui-avatar",
		priority = 0,
		properties = { BackgroundColor3 = "$Muted", BorderSizePixel = 0 },
	},
	{ selector = ".ui-avatar::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{ selector = ".ui-avatar-square::UICorner", priority = 10, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-avatar-image",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	-- The headshot is rounded too: a parent's corner does not clip its children.
	{ selector = ".ui-avatar-image::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
	{
		selector = ".ui-avatar-image-square::UICorner",
		priority = 10,
		properties = { CornerRadius = "$RadiusMd" },
	},
	{
		selector = ".ui-avatar-monogram",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansSemibold",
			TextSize = "$TextSm",
		},
	},
}
for size, token in TEXT do
	table.insert(rules, {
		selector = `.ui-avatar-monogram-{size}`,
		priority = 10,
		properties = { TextSize = token },
	})
end
Avatar.rules = rules

-- "rbxthumb" headshot url for a player, or "" for a bot (0 or below) or nil.
function Avatar.headshot(userId: number?): string
	if type(userId) ~= "number" or userId <= 0 then
		return ""
	end
	return `rbxthumb://type=AvatarHeadShot&id={string.format("%d", userId)}&w=150&h=150`
end

-- First letters of the first two words, upper case; "?" when there are none.
function Avatar.initials(name: string?): string
	local out = ""
	if type(name) == "string" then
		for word in string.gmatch(name, "%S+") do
			out ..= string.upper(string.sub(word, 1, 1))
			if #out == 2 then
				break
			end
		end
	end
	return if out == "" then "?" else out
end

local function checkSize(size: string): number
	local px = Avatar.sizes[size]
	if px == nil then
		error(`[Lucy] unknown Avatar size "{size}" (expected sm, md or lg)`, 0)
	end
	return px
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "avatar",
	defaults = { userId = 0, name = "", size = "md", visible = true },
	rules = Avatar.rules,
	render = function(h)
		local p: Component.Props = h.props
		checkSize(h:get("size"))
		local square = p.square == true
		local userId, name, size = h:ref("userId"), h:ref("name"), h:ref("size")
		local function url(): string
			return Avatar.headshot(userId())
		end
		local function hasImage(): boolean
			return url() ~= ""
		end

		local image = Element.new("ImageLabel", {
			Name = "Headshot",
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Crop,
			Image = url,
			Visible = hasImage,
			Tags = if square then { "ui-avatar-image", "ui-avatar-image-square" } else { "ui-avatar-image" },
		})
		local monogram = Element.new("TextLabel", {
			Name = "Monogram",
			Size = UDim2.fromScale(1, 1),
			Text = function()
				return Avatar.initials(name())
			end,
			Visible = function()
				return not hasImage()
			end,
			Tags = {
				"ui-avatar-monogram" :: any,
				function()
					return "ui-avatar-monogram-" .. size()
				end,
			},
		})
		h.image, h.monogram = image, monogram

		return Element.new("Frame", {
			Size = function()
				local px = checkSize(size())
				return UDim2.fromOffset(px, px)
			end,
			Visible = h:ref("visible"),
			Tags = {
				"ui-avatar" :: any,
				if square then "ui-avatar-square" else "ui-avatar-round",
				function()
					return "ui-avatar-size-" .. size()
				end,
			},
			image,
			monogram,
		})
	end,
}

function Avatar.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Avatar
