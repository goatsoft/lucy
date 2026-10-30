--!strict
--[[
	Collapsible: a header the player presses to show or hide what is under it.

		Collapsible.new({
			text = "Advanced",
			content = advancedSettings, -- an Instance, a handle, or a function returning either
			open = false,
			variant = "default",        -- default | details
			disabled = false,
			visible = true,
			onOpenChange = function(open, collapsible) end,
			Parent = panel,
		})
		collapsible:toggle()

	`default` is a full width header with a chevron on the right and a line under
	it (Accordion is a stack of these). `details` is a compact header with the
	chevron before the text and the content indented under it, for a "show more"
	inside other content. Opening and closing slide the height over a short tween
	(at once while it is not on screen yet); closed content is hidden, so
	keyboard and gamepad focus skip it.

	The header is the focus stop: A, Enter or a click opens and closes it.

	State keys: text, open, variant, disabled, visible.
	Events: "toggle" with the new open state, for Lucy.useUiSound.
	collapsible.header, .label, .chevron (an Icon), .body (the clipped part) and
	.content (holds the content) are its parts.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Animate = require(script.Parent.Parent.Core.Animate)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local Icon = require(script.Parent.Icon)

local Collapsible = {}

Collapsible.variants = { "default", "details" }

-- How long opening and closing take.
Collapsible.tween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local INSTANT = TweenInfo.new(0)

-- The chevron each variant draws, and how far it turns when open.
local CHEVRON: { [string]: { icon: string, turn: number } } = {
	default = { icon = "lucy:chevron-down", turn = 180 },
	details = { icon = "lucy:chevron-right", turn = 90 },
}

local ACTIVATED = Element.on("Activated")
local OUT_SIZE = Element.out("AbsoluteSize")

local BASE, VARIANT, DISABLED = 0, 10, 30

Collapsible.rules = {
	{
		selector = ".ui-collapsible-header",
		priority = BASE,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-collapsible-header::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusMd" },
	},
	{
		selector = ".ui-collapsible-header-variant-default::UIPadding",
		priority = VARIANT,
		properties = { PaddingTop = "$Space4", PaddingBottom = "$Space4" },
	},
	{
		selector = ".ui-collapsible-header-variant-details::UIPadding",
		priority = VARIANT,
		properties = { PaddingTop = "$Space1", PaddingBottom = "$Space1" },
	},
	{
		selector = ".ui-collapsible-label",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-collapsible-label.ui-disabled",
		priority = DISABLED,
		properties = { TextTransparency = 0.5 },
	},
	{
		selector = ".ui-collapsible-content-variant-default::UIPadding",
		priority = VARIANT,
		properties = { PaddingBottom = "$Space4" },
	},
	{
		selector = ".ui-collapsible-content-variant-details::UIPadding",
		priority = VARIANT,
		properties = { PaddingLeft = "$Space6", PaddingBottom = "$Space2" },
	},
	{
		selector = ".ui-collapsible-divider",
		priority = BASE,
		properties = { BackgroundColor3 = "$Border", BorderSizePixel = 0 },
	},
} :: { Component.Rule }

function Collapsible.check(variant: string)
	if not table.find(Collapsible.variants, variant) then
		error(
			`[Lucy] unknown Collapsible variant "{variant}" (expected {table.concat(
				Collapsible.variants,
				", "
			)})`,
			0
		)
	end
end

-- Shared tag lists, one per part and variant.
local tagLists: { [string]: { string } } = {}
local function tags(part: string, variant: string): { string }
	local key = part .. "/" .. variant
	local list = tagLists[key]
	if not list then
		list = { part .. "-variant-" .. variant }
		tagLists[key] = list
	end
	return list
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "collapsible",
	defaults = { text = "", open = false, variant = "default", disabled = false, visible = true },
	rules = Collapsible.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		Collapsible.check(h:get("variant"))
		local open, disabled, variantRef = h:ref("open"), h:ref("disabled"), h:ref("variant")
		local function variant(): string
			local v = variantRef()
			Collapsible.check(v)
			return v
		end
		local function enabled(): boolean
			return not disabled()
		end
		local function variantTags(part: string): () -> { string }
			return function()
				return tags(part, variant())
			end
		end

		if p.onOpenChange then
			Reactive.watch(open, function(value)
				p.onOpenChange(value, h)
			end)
		end

		-- 0 closed, 1 open. Tweened once the collapsible is on screen, at once before.
		local root: Frame? = nil
		-- The info is a plain function, read when the target changes: being on
		-- screen is not reactive, so a computed would keep its first answer.
		local progress: () -> number = Animate.tween(function(): number
			return if open() then 1 else 0
		end, function(): TweenInfo
			local shown = root ~= nil and root:FindFirstAncestorWhichIsA("LayerCollector") ~= nil
			return if shown then Collapsible.tween else INSTANT
		end) :: any

		local label = Element.new("TextLabel", {
			Name = "Label",
			Text = h:ref("text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = function(): number
				return if variant() == "details" then 2 else 1
			end,
			Tags = { "ui-collapsible-label" :: any, ["ui-disabled"] = disabled },
		})
		local flex = Instance.new("UIFlexItem")
		flex.FlexMode = Enum.UIFlexMode.Fill
		flex.Parent = label

		local chevron = Icon.new({
			app = app,
			name = "Chevron",
			size = "sm",
			variant = "muted",
			icon = Reactive.computed(function(): string
				return CHEVRON[variant()].icon
			end),
		})
		Element.hydrate(chevron.Instance, {
			Rotation = function(): number
				return progress() * CHEVRON[variant()].turn
			end,
		})
		-- A list layout drops the rotation of what it places, so the list places
		-- this holder and the chevron turns inside it.
		local holder = Element.new("Frame", {
			Name = "ChevronHolder",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = function(): number
				return if variant() == "details" then 1 else 2
			end,
			chevron.Instance,
		})

		local header = Element.new("TextButton", {
			Name = "Header",
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Interactable = enabled,
			Selectable = enabled,
			Tags = {
				"ui-collapsible-header" :: any,
				variantTags("ui-collapsible-header"),
				["ui-disabled"] = disabled,
			},
			[ACTIVATED] = function()
				h:toggle()
			end,
			Component.list({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = Component.space(app, "Space2", 8),
			}) :: any,
			label,
			holder,
		})

		-- The content's height, in the same units as the body's size.
		local measured = Reactive.ref(Vector2.zero)
		local content = Element.new("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tags = { "ui-collapsible-content" :: any, variantTags("ui-collapsible-content") },
			[OUT_SIZE] = measured :: any,
		})
		local given = p.content
		if type(given) == "function" then
			given = given()
		end
		if given ~= nil then
			Component.adopt(content, { given })
		end
		local function contentHeight(): number
			local height = measured().Y
			local scale = Scroll.scaleOf(content)
			return height / (if scale > 0 then scale else 1)
		end

		local body = Element.new("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = 2,
			Size = function()
				return UDim2.new(1, 0, 0, math.round(progress() * contentHeight()))
			end,
			Visible = function(): boolean
				return open() or progress() > 0
			end,
			Tags = { "ui-collapsible-body" },
			content,
		})

		local divider = Element.new("Frame", {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = 3,
			Visible = function(): boolean
				return variant() == "default"
			end,
			Tags = { "ui-collapsible-divider" },
		})

		h.header, h.label, h.chevron, h.body, h.content = header, label, chevron, body, content

		local frame = Element.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			Tags = { "ui-collapsible" :: any, variantTags("ui-collapsible") },
			Component.list({}) :: any,
			header,
			body,
			divider,
		})
		root = frame
		return frame
	end,
}

function Collapsible.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	-- The player opened or closed it.
	function handle.toggle(h)
		if h.destroyed or h:get("disabled") then
			return
		end
		local open = not h:get("open")
		h:set("open", open)
		h:emit("toggle", open)
	end

	-- Enter on the header (InputManager.activate).
	function handle.press(h, object: Instance): boolean
		if object ~= h.header then
			return false
		end
		h:toggle()
		return true
	end
	return handle
end

return Collapsible
