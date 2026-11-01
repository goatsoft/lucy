--!strict
--[[
	Menu: a set of actions that opens on demand and closes once one is picked
	(a game's main actions, a player's options, a build tool's modes).

		local menu = Menu.new({
			id = "club",
			items = {
				{ value = "dj", label = "DJ request", icon = "club:dj", hint = "djVote" },
				{ value = "lab", label = "The Lab", icon = "club:lab" },
				{ value = "exit", label = "Exit", icon = "lucy:close", disabled = false },
			},
			variant = { gamepad = "radial", touch = "arc", default = "list" },
			anchor = clubButton,       -- an instance, handle or getter; nothing centres it
			side = "auto",             -- list: auto | bottom | top | left | right
			align = "start",           -- list: start | center | end
			width = 220,               -- list: at least this wide (and the anchor's width)
			radius = nil,              -- radial and arc: the circle's radius, by item count if left out
			shape = "round",           -- radial and arc buttons: round | squircle | square
			onSelect = function(value, menu) end,
		})
		clubButton.Activated:Connect(function() menu:toggle() end)
		menu:open()  menu:close()  menu:toggle()  menu:select("dj")

	An item is { value, label?, icon?, hint?, disabled? }. icon is any name Icon
	draws (a lucy: icon or one of the game's own sheets). hint names an action
	(app.actions); the list shows its key beside the item.

	Variants (a value or a responsive value, so each input gets its own shape):
	  list    a list next to its anchor, on the side that fits (side = "auto"
	          opens below, then above, then beside), kept on screen; a drawer
	          from the bottom on touch
	  radial  a ring of round buttons around the anchor (or the screen centre),
	          moved in until the whole ring is on screen; the stick points at one
	  arc     a fan of round buttons from the anchor, opening toward the middle
	          of the screen, so a corner button fans inward
	Ring and arc buttons show the item's icon (or its initials) with its label
	under it. shape (a value or a responsive value) picks their outline: round,
	squircle (a rounded square) or square (slightly rounded corners).

	It opens on the app's overlay layer as a modal: keyboard and gamepad focus
	stays inside, back and a press outside close it, and focus returns to the
	anchor. Picking an item calls onSelect, emits "select" and closes it.

	State keys: open, visible.
	Events: "open", "close" and "select" with the value, for Lucy.useUiSound.
	menu.items holds one list row per item, menu.slices one round button per
	item, in order; menu.variant() is the variant in use.
	Menu.ring, Menu.arc, Menu.toward, Menu.fit, Menu.angles and Menu.pick are
	the geometry it uses.
]]

local UserInputService = game:GetService("UserInputService")

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Kbd = require(script.Parent.Kbd)
local Overlay = require(script.Parent.Parent.Core.Overlay)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Responsive = require(script.Parent.Parent.Core.Responsive)
local ScrollArea = require(script.Parent.ScrollArea)

local Menu = {}

Menu.variants = { "list", "radial", "arc" }
Menu.shapes = { "round", "squircle", "square" }

-- A round button's size, the room under it for its label, and an arc's spacing in degrees.
Menu.sliceSize = 56
Menu.captionRoom = 26
Menu.arcSpacing = 34
-- How far the stick must be pushed before it points at an item.
Menu.deadzone = 0.5

local ACTIVATED = Element.on("Activated")

-- Geometry. Angles are degrees on the screen: 0 is right, 90 is down.

-- count points on a circle of `radius` around (0, 0), the first at `start` (the top), clockwise.
function Menu.ring(count: number, radius: number, start: number?): { Vector2 }
	local points = {}
	for i = 1, count do
		local angle = math.rad((start or -90) + (i - 1) * 360 / count)
		points[i] = Vector2.new(math.cos(angle), math.sin(angle)) * radius
	end
	return points
end

-- count points on a circle of `radius`, `spacing` degrees apart and centred on `direction`.
function Menu.arc(count: number, radius: number, direction: number, spacing: number): { Vector2 }
	local points = {}
	for i = 1, count do
		local angle = math.rad(direction + (i - (count + 1) / 2) * spacing)
		points[i] = Vector2.new(math.cos(angle), math.sin(angle)) * radius
	end
	return points
end

-- The angle from `from` toward the middle of a `view`-sized screen (up when already there).
function Menu.toward(from: Vector2, view: Vector2): number
	local d = view / 2 - from
	if d.Magnitude < 1 then
		return -90
	end
	return math.deg(math.atan2(d.Y, d.X))
end

-- `center` moved in until a circle of `extent` around it is `margin` inside the screen.
function Menu.fit(center: Vector2, extent: number, view: Vector2, margin: number): Vector2
	local function axis(value: number, size: number): number
		local low, high = extent + margin, size - extent - margin
		if low > high then
			return size / 2
		end
		return math.clamp(value, low, high)
	end
	return Vector2.new(axis(center.X, view.X), axis(center.Y, view.Y))
end

-- Each point's angle from the centre.
function Menu.angles(points: { Vector2 }): { number }
	local out = {}
	for i, point in points do
		out[i] = math.deg(math.atan2(point.Y, point.X))
	end
	return out
end

-- The index of the angle closest to `direction` (a screen direction), or nil for a small push.
function Menu.pick(direction: Vector2, angles: { number }): number?
	if direction.Magnitude < Menu.deadzone or #angles == 0 then
		return nil
	end
	local want = math.deg(math.atan2(direction.Y, direction.X))
	local best, bestGap = nil, math.huge
	for i, angle in angles do
		local gap = math.abs((want - angle + 180) % 360 - 180)
		if gap < bestGap then
			best, bestGap = i, gap
		end
	end
	return best
end

local function check(what: string, allowed: { string }, value: any)
	local values = if Responsive.isResponsive(value) then value else { value }
	for _, one in values do
		if not table.find(allowed, one) then
			error(`[Lucy] unknown Menu {what} "{tostring(one)}" ({table.concat(allowed, ", ")})`, 0)
		end
	end
end

type Entry = { value: any, text: string, icon: string?, hint: string?, disabled: boolean }

local function normalize(items: { any }?): { Entry }
	local list: { Entry } = {}
	local source: { any } = items or {}
	for _, raw in source do
		local item: { [string]: any } = if type(raw) == "table" then raw else { value = raw }
		if item.value == nil then
			error("[Lucy] Menu item needs a value", 0)
		end
		table.insert(list, {
			value = item.value,
			text = item.label or item.text or tostring(item.value),
			icon = item.icon,
			hint = item.hint,
			disabled = item.disabled == true,
		})
	end
	return list
end

-- Up to two initials, for a round button with no icon.
local function initials(text: string): string
	local out = ""
	for word in string.gmatch(text, "%w+") do
		out ..= string.upper(string.sub(word, 1, 1))
		if #out == 2 then
			break
		end
	end
	return out
end

Menu.rules = {
	{
		selector = ".ui-menu-content",
		priority = 0,
		properties = { BackgroundColor3 = "$Popover", BackgroundTransparency = 0, BorderSizePixel = 0 },
	},
	{ selector = ".ui-menu-content::UICorner", priority = 0, properties = { CornerRadius = "$RadiusMd" } },
	{
		selector = ".ui-menu-content::UIStroke",
		priority = 0,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-menu-content::UIPadding",
		priority = 0,
		properties = {
			PaddingTop = "$Space1",
			PaddingBottom = "$Space1",
			PaddingLeft = "$Space1",
			PaddingRight = "$Space1",
		},
	},
	-- A ring or an arc floats with no panel behind it
	{
		selector = ".ui-menu-content.ui-menu-ring",
		priority = 10,
		properties = { BackgroundTransparency = 1 },
	},
	{
		selector = ".ui-menu-content.ui-menu-ring::UIStroke",
		priority = 10,
		properties = { Transparency = 1 },
	},
	{
		selector = ".ui-menu-content.ui-menu-ring::UIPadding",
		priority = 10,
		properties = {
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
		},
	},
	{
		selector = ".ui-menu-drawer::UIPadding",
		priority = 20,
		properties = {
			PaddingTop = "$Space4",
			PaddingBottom = "$Space4",
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
		},
	},
	{ selector = ".ui-menu-drawer::UICorner", priority = 20, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-menu-item",
		priority = 0,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{ selector = ".ui-menu-item::UICorner", priority = 0, properties = { CornerRadius = "$RadiusSm" } },
	{
		selector = ".ui-menu-item::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space2", PaddingRight = "$Space2" },
	},
	{ selector = ".ui-menu-item:Hover", priority = 10, properties = { BackgroundTransparency = 0 } },
	{
		selector = ".ui-menu-item-label",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-menu-item-label.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
	{
		selector = ".ui-menu-slice",
		priority = 0,
		properties = { BackgroundColor3 = "$Popover", BackgroundTransparency = 0, BorderSizePixel = 0 },
	},
	{ selector = ".ui-menu-slice::UICorner", priority = 0, properties = { CornerRadius = UDim.new(0.5, 0) } },
	{
		selector = ".ui-menu-slice.ui-menu-squircle::UICorner",
		priority = 5,
		properties = { CornerRadius = UDim.new(0.3, 0) },
	},
	{
		selector = ".ui-menu-slice.ui-menu-square::UICorner",
		priority = 5,
		properties = { CornerRadius = "$RadiusMd" },
	},
	{
		selector = ".ui-menu-slice::UIStroke",
		priority = 0,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{ selector = ".ui-menu-slice:Hover", priority = 10, properties = { BackgroundColor3 = "$Accent" } },
	{ selector = ".ui-menu-slice.ui-disabled", priority = 30, properties = { BackgroundTransparency = 0.5 } },
	{
		selector = ".ui-menu-slice-mark",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSansSemibold",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-menu-caption",
		priority = 0,
		properties = {
			BackgroundColor3 = "$Popover",
			BackgroundTransparency = 0.1,
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{ selector = ".ui-menu-caption::UICorner", priority = 0, properties = { CornerRadius = "$RadiusSm" } },
	{
		selector = ".ui-menu-caption::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space1", PaddingRight = "$Space1" },
	},
	{ selector = ".ui-menu-caption.ui-disabled", priority = 30, properties = { TextTransparency = 0.5 } },
} :: { Component.Rule }

local spec: Component.Spec = {
	kind = "menu",
	defaults = { open = false, visible = true },
	rules = Menu.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local open = h:ref("open")
		local entries: { Entry } = p._menuEntries
		local count = #entries
		local variant = Composables.useResponsive(app, p.variant or "list") :: () -> string
		h.variant = variant
		local shape = Composables.useResponsive(app, p.shape or "round") :: () -> string
		h.shape = shape
		local function isList(): boolean
			return variant() == "list"
		end
		local function isRing(): boolean
			return not isList()
		end
		local height = Composables.useMetric(app, "ControlMd")

		-- The ring's radius: by item count, so neighbours never overlap. A label sits under
		-- each button, so neighbours stay a button and a label apart.
		local function radius(): number
			if p.radius then
				return p.radius
			end
			local gap = Menu.sliceSize + Menu.captionRoom + 8
			if variant() == "arc" then
				return math.max(110, math.ceil(gap / 2 / math.sin(math.rad(Menu.arcSpacing / 2))))
			end
			return math.max(80, math.ceil(gap / 2 / math.sin(math.pi / math.max(count, 2))))
		end
		local function extent(): number
			return radius() + Menu.sliceSize / 2 + Menu.captionRoom
		end
		-- Where each round button sits around the centre; set when it is placed.
		local points = Reactive.ref(Menu.ring(count, 80) :: { Vector2 })

		-- The list.
		local rows = {}
		local listFrame = Element.new("Frame", {
			Name = "Items",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Component.list({ Padding = UDim.new(0, 2) }) :: any,
		})
		-- When any item has an icon, every label starts after the icon's column.
		local indent = 0
		for _, item in entries do
			if item.icon then
				indent = 24
			end
		end
		for index, item in entries do
			local function off(): boolean
				return item.disabled
			end
			local function usable(): boolean
				return isList() and not item.disabled
			end
			local hintRoom = if item.hint then 56 else 0
			local row = Element.new("TextButton", {
				Name = `Item{index}`,
				LayoutOrder = index,
				Text = "",
				AutoButtonColor = false,
				Size = function(): UDim2
					return UDim2.new(1, 0, 0, height())
				end,
				Visible = isList,
				Interactable = usable,
				Selectable = usable,
				Tags = { "ui-menu-item" :: any, ["ui-disabled"] = off },
				[ACTIVATED] = function()
					h:select(item.value)
				end,
				Element.new("TextLabel", {
					Name = "Label",
					Position = UDim2.fromOffset(indent, 0),
					Size = UDim2.new(1, -(indent + hintRoom), 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = item.text,
					Tags = { "ui-menu-item-label" :: any, ["ui-disabled"] = off },
				}),
			})
			if item.icon then
				local icon = Icon.new({ app = app, icon = item.icon, size = "sm", name = "Icon" })
				icon.Instance.AnchorPoint = Vector2.new(0, 0.5)
				icon.Instance.Position = UDim2.fromScale(0, 0.5)
				icon.Instance.Parent = row
			end
			if item.hint then
				local kbd = Kbd.new({ app = app, action = item.hint, variant = "mono" })
				kbd.Instance.AnchorPoint = Vector2.new(1, 0.5)
				kbd.Instance.Position = UDim2.fromScale(1, 0.5)
				kbd.Instance.Parent = row
			end
			row.Parent = listFrame
			rows[index] = row
		end
		h.items = rows

		local overlayRef: Reactive.Ref<Overlay.Overlay?> = Reactive.ref(nil :: Overlay.Overlay?)
		local function isDrawer(): boolean
			local overlay = overlayRef()
			return overlay ~= nil and overlay.presentation() == "drawer"
		end
		local padSmall = Component.space(app, "Space1", 4).Offset
		local padLarge = Component.space(app, "Space4", 16).Offset
		local list = ScrollArea.new({
			app = app,
			name = "List",
			scrollbar = "auto",
			visible = isList,
			maxHeight = function(): number
				local overlay = overlayRef()
				if not overlay then
					return math.huge
				end
				local pad = if isDrawer() then padLarge else padSmall
				return math.max(0, overlay.maxHeight() - pad * 2 - overlay.safeBottom())
			end,
			children = { listFrame },
		})

		-- The ring or arc.
		local slices = {}
		local ringFrame = Element.new("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			Visible = isRing,
			Size = function(): UDim2
				if not isRing() then
					return UDim2.fromOffset(0, 0)
				end
				local side = math.ceil(extent() * 2)
				return UDim2.fromOffset(side, side)
			end,
		})
		for index, item in entries do
			local function off(): boolean
				return item.disabled
			end
			local function usable(): boolean
				return isRing() and not item.disabled
			end
			local slice = Element.new("TextButton", {
				Name = `Slice{index}`,
				Text = "",
				AutoButtonColor = false,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(Menu.sliceSize, Menu.sliceSize),
				Position = function(): UDim2
					local at = points()[index] or Vector2.zero
					return UDim2.new(0.5, math.floor(at.X + 0.5), 0.5, math.floor(at.Y + 0.5))
				end,
				Visible = isRing,
				Interactable = usable,
				Selectable = usable,
				Tags = {
					"ui-menu-slice" :: any,
					["ui-disabled"] = off,
					["ui-menu-squircle"] = function(): boolean
						return shape() == "squircle"
					end,
					["ui-menu-square"] = function(): boolean
						return shape() == "square"
					end,
				},
				[ACTIVATED] = function()
					h:select(item.value)
				end,
				Element.new("TextLabel", {
					Name = "Caption",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 1, 4),
					Size = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = item.text,
					Tags = { "ui-menu-caption" :: any, ["ui-disabled"] = off },
				}),
			})
			if item.icon then
				local icon = Icon.new({ app = app, icon = item.icon, size = 24, name = "Icon" })
				icon.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Instance.Position = UDim2.fromScale(0.5, 0.5)
				icon.Instance.Parent = slice
			else
				Element.new("TextLabel", {
					Name = "Mark",
					Size = UDim2.fromScale(1, 1),
					Text = initials(item.text),
					Tags = { "ui-menu-slice-mark" :: any },
					Parent = slice,
				})
			end
			slice.Parent = ringFrame
			slices[index] = slice
		end
		h.slices = slices

		local content = Element.new("Frame", {
			Name = "Content",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Active = true,
			Tags = {
				"ui-menu-content" :: any,
				["ui-menu-ring"] = isRing,
				["ui-menu-drawer"] = function(): boolean
					return isList() and isDrawer()
				end,
			},
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			list.Instance,
			ringFrame,
		}) :: Frame
		h.content = content

		local overlay = Overlay.use(app, {
			open = open,
			content = content,
			presentation = function(): string
				return if isList() then "auto" else "popup"
			end,
			prefer = "popup",
			anchor = p.anchor,
			side = p.side or "auto",
			align = p.align,
			width = p.width or 220,
			name = "Menu",
			tags = { "ui-menu-overlay" },
			id = h.id,
			place = function(_presentation: string, input: Overlay.PlaceInput): Overlay.Placement?
				if isList() then
					return nil
				end
				local view = input.view
				local anchor = input.anchor
				local center = if anchor then anchor.position + anchor.size / 2 else view / 2
				local r = radius()
				if variant() == "radial" then
					points(Menu.ring(count, r))
					center = Menu.fit(center, extent(), view, Overlay.margin)
				else
					points(Menu.arc(count, r, Menu.toward(center, view), Menu.arcSpacing))
				end
				return {
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.fromOffset(math.floor(center.X + 0.5), math.floor(center.Y + 0.5)),
					maxHeight = view.Y,
				}
			end,
			defaultFocus = function()
				local set = if isList() then rows else slices
				for index, item in entries do
					if not item.disabled then
						return set[index]
					end
				end
				return nil
			end,
		})
		overlayRef(overlay)
		h.presentation = overlay.presentation
		Component.claimSelection(app, overlay.root)

		-- The stick points at a round button while a ring or arc is open.
		Composables.useWhile(function(): boolean
			return open() == true and isRing()
		end, function()
			return UserInputService.InputChanged:Connect(function(input: InputObject)
				if input.KeyCode ~= Enum.KeyCode.Thumbstick1 then
					return
				end
				local index =
					Menu.pick(Vector2.new(input.Position.X, -input.Position.Y), Menu.angles(points()))
				if index and not entries[index].disabled and app.input then
					app.input:focus(slices[index])
				end
			end)
		end)

		Reactive.watch(open, function(isOpen, previous)
			if previous ~= nil and (isOpen == true) ~= (previous == true) then
				h:emit(if isOpen then "open" else "close")
			end
		end, { immediate = true })

		return Element.new("Frame", {
			Name = "Menu",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 0),
			Visible = h:ref("visible"),
		})
	end,
}

function Menu.new(props: { [string]: any }?)
	local given: { [string]: any } = table.clone(props or {})
	check("variant", Menu.variants, given.variant or "list")
	check("shape", Menu.shapes, given.shape or "round")
	given._menuEntries = normalize(given.items)
	local handle = Component.mount(spec, given)
	function handle.open(h)
		h:set("open", true)
	end
	function handle.close(h)
		h:set("open", false)
	end
	function handle.toggle(h)
		h:set("open", not h:get("open"))
	end
	-- The player picked `value`: report it, emit select and close. A disabled or unknown
	-- item is ignored.
	function handle.select(h, value: any)
		if h.destroyed then
			return
		end
		for _, item in h.props._menuEntries do
			if item.value == value then
				if item.disabled then
					return
				end
				h:emit("select", value)
				if h.props.onSelect then
					h.props.onSelect(value, h)
				end
				h:close()
				return
			end
		end
	end
	return handle
end

return Menu
