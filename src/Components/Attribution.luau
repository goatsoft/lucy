--!strict
--[[
	Attribution

		Attribution.new({
			label = "Built with",     -- optional prefix (default "Built with")
			brand = "Lucy",           -- brand text (default "Lucy")
			variant = "default",      -- default | light | secondary | outline | brand
			size = "md",              -- sm | md | lg
			shape = "rounded",        -- rounded (pill) | square (slightly rounded)
			image = nil,              -- optional image override (defaults to Lucy's masthead)
			onClick = function(a) end,-- optional click handler
			Parent = frame,
		})

	State keys: label, brand, variant, size, shape, image, visible.
	Parts: attribution.image (masthead), attribution.label (prefix), attribution.brand (brand).

	On dark grounds, Lucy's masthead art has transparent cutouts that let the dark
	background show through as linework. On light grounds ("light" variant), it
	uses the linework-restored asset with ink background fill and contour stroke.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Attribution = {}

Attribution.variants = { "default", "light", "secondary", "outline", "brand" }
Attribution.shapes = { "rounded", "square" }
Attribution.sizes = { "sm", "md", "lg" }

-- Uploaded Lucy masthead assets (GOATsoft group):
-- dark: original transparent cutouts; dark backgrounds show through as outlines
-- light: linework restored with dark ink fill and drawn around silhouette contour
Attribution.assets = {
	dark = "rbxassetid://102504233692554",
	light = "rbxassetid://91863674670315",
}

-- Image sizes for each badge size (width, height in px, preserving ~0.886 aspect ratio)
local IMAGE_SIZES = {
	sm = Vector2.new(14, 16),
	md = Vector2.new(18, 20),
	lg = Vector2.new(21, 24),
}

local ACTIVATED = Element.on("Activated")

local BASE, VARIANT, STATE = 0, 10, 20

local rules: { Component.Rule } = {
	{
		selector = ".ui-attribution",
		priority = BASE,
		properties = {
			BackgroundColor3 = "$Card",
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
		},
		transitions = { BackgroundColor3 = TweenInfo.new(0.12) },
	},
	{
		selector = ".ui-attribution::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusFull" },
	},
	{
		selector = ".ui-attribution-shape-square::UICorner",
		priority = VARIANT,
		properties = { CornerRadius = "$RadiusMd" },
	},
	{
		selector = ".ui-attribution::UIPadding",
		priority = BASE,
		properties = {
			PaddingLeft = "$Space3",
			PaddingRight = "$Space3",
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
	},
	{
		selector = ".ui-attribution-size-sm::UIPadding",
		priority = VARIANT,
		properties = {
			PaddingLeft = "$Space2",
			PaddingRight = "$Space2",
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		},
	},
	{
		selector = ".ui-attribution-size-lg::UIPadding",
		priority = VARIANT,
		properties = {
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		},
	},

	-- Image element
	{
		selector = ".ui-attribution-image",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ImageColor3 = "$White",
		},
	},

	-- Text labels
	{
		selector = ".ui-attribution-label",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextXs",
			BorderSizePixel = 0,
		},
	},
	{
		selector = ".ui-attribution-brand",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Primary",
			FontFace = "$FontDisplay",
			TextSize = "$TextXs",
			BorderSizePixel = 0,
		},
	},
	{
		selector = ".ui-attribution-size-lg > .ui-attribution-label",
		priority = VARIANT,
		properties = { TextSize = "$TextSm" },
	},
	{
		selector = ".ui-attribution-size-lg > .ui-attribution-brand",
		priority = VARIANT,
		properties = { TextSize = "$TextSm" },
	},

	-- Variant: default
	{
		selector = ".ui-attribution-variant-default",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Card" },
	},
	{
		selector = ".ui-attribution-variant-default::UIStroke",
		priority = VARIANT,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},

	-- Variant: light (pure white surface with subtle grey border and ink text)
	{
		selector = ".ui-attribution-variant-light",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$White" },
	},
	{
		selector = ".ui-attribution-variant-light > .ui-attribution-label",
		priority = VARIANT + 5,
		properties = { TextColor3 = "$Zinc700" },
	},
	{
		selector = ".ui-attribution-variant-light > .ui-attribution-brand",
		priority = VARIANT + 5,
		properties = { TextColor3 = "$Zinc900" },
	},
	{
		selector = ".ui-attribution-variant-light::UIStroke",
		priority = VARIANT,
		properties = {
			Color = "$Zinc200",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},

	-- Variant: secondary
	{
		selector = ".ui-attribution-variant-secondary",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Secondary" },
	},

	-- Variant: outline
	{
		selector = ".ui-attribution-variant-outline",
		priority = VARIANT,
		properties = { BackgroundTransparency = 1 },
	},
	{
		selector = ".ui-attribution-variant-outline::UIStroke",
		priority = VARIANT,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},

	-- Variant: brand
	{
		selector = ".ui-attribution-variant-brand",
		priority = VARIANT,
		properties = { BackgroundColor3 = "$Card" },
	},
	{
		selector = ".ui-attribution-variant-brand::UIStroke",
		priority = VARIANT,
		properties = {
			Color = "$Primary",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},

	-- Clickable hover & active states
	{
		selector = ".ui-attribution-clickable:Hover",
		priority = STATE,
		properties = { BackgroundTransparency = 0.05 },
	},
	{
		selector = ".ui-attribution-clickable:Press",
		priority = STATE + 5,
		properties = { BackgroundTransparency = 0.15 },
	},
}
Attribution.rules = rules

local function check(list: { string }, value: string, what: string)
	if not table.find(list, value) then
		error(`[Lucy] unknown Attribution {what} "{value}" (expected {table.concat(list, ", ")})`, 0)
	end
end

local spec: Component.Spec = {
	kind = "attribution",
	defaults = {
		label = "Built with",
		brand = "Lucy",
		variant = "default",
		size = "md",
		shape = "rounded",
		visible = true,
	},
	rules = Attribution.rules,
	render = function(h)
		check(Attribution.variants, h:get("variant"), "variant")
		check(Attribution.shapes, h:get("shape"), "shape")
		check(Attribution.sizes, h:get("size"), "size")

		local variant = h:ref("variant")
		local shape = h:ref("shape")
		local size = h:ref("size")
		local labelText = h:ref("label")
		local brandText = h:ref("brand")
		local imageProp = h:ref("image")

		local isClickable = h.props.onClick ~= nil
		local containerClass = if isClickable then "ImageButton" else "Frame"

		-- Track theme switches so the masthead asset adapts to light backgrounds
		local themeTick = Reactive.ref(0)
		local themeConn = h.app.theme.Changed:Connect(function()
			themeTick(themeTick() + 1)
		end)
		h.maid:give(themeConn)

		-- Derive masthead asset based on variant and theme (or explicit image prop)
		local mastheadImage = Reactive.computed(function(): string
			themeTick()
			local custom = imageProp()
			if custom and custom ~= "" then
				return custom
			end
			local v = variant()
			if v == "light" then
				return Attribution.assets.light
			end
			if h.app.theme:get() == "light" and v ~= "brand" then
				return Attribution.assets.light
			end
			return Attribution.assets.dark
		end)

		local imageDimensions = Reactive.computed(function(): UDim2
			local s = size()
			local dims = IMAGE_SIZES[s] or IMAGE_SIZES.md
			return UDim2.fromOffset(dims.X, dims.Y)
		end)

		local image = Element.new("ImageLabel", {
			LayoutOrder = 1,
			Size = imageDimensions,
			Image = mastheadImage,
			ScaleType = Enum.ScaleType.Fit,
			Tags = { "ui-attribution-image" },
		})
		local label = Element.new("TextLabel", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = labelText,
			Tags = { "ui-attribution-label" },
		})
		local brand = Element.new("TextLabel", {
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = brandText,
			Tags = { "ui-attribution-brand" },
		})
		h.parts = { image = image, label = label, brand = brand }

		local props: { [string]: any } = {
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Visible = h:ref("visible"),
			Tags = {
				"ui-attribution" :: any,
				function()
					local v = variant()
					check(Attribution.variants, v, "variant")
					return "ui-attribution-variant-" .. v
				end,
				function()
					local s = size()
					check(Attribution.sizes, s, "size")
					return "ui-attribution-size-" .. s
				end,
				["ui-attribution-shape-square"] = function(): boolean
					local sh = shape()
					check(Attribution.shapes, sh, "shape")
					return sh == "square"
				end,
				["ui-attribution-clickable"] = isClickable,
			},
			Children = {
				Element.new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				image,
				label,
				brand,
			},
		}

		if isClickable then
			props[ACTIVATED] = function()
				if h.props.onClick then
					h.props.onClick(h)
				end
				h:click()
			end
		end

		return Element.new(containerClass, props)
	end,
}

function Attribution.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	if props and props.onClick ~= nil then
		Component.clickable(handle)
	end
	return handle
end

return Attribution
