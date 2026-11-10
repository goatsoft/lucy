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
			returnFocus = nil,         -- focus on close: nil the anchor, an object, handle or
			                           -- getter, or false for nothing (a HUD button)
			side = "auto",             -- list: auto | bottom | top | left | right
			align = "start",           -- list: start | center | end
			width = 220,               -- list: at least this wide (and the anchor's, and the widest label's)
			radius = nil,              -- radial: the ring's (by item count); arc: its curve's (900)
			toward = "auto",           -- arc: auto (the screen's middle) | left | right: its labels' side
			shape = "round",           -- radial and arc buttons: round | squircle | square
			size = "md",               -- md | lg, like a Button's: lg rows and ring buttons are bigger
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
	  radial  a ring of round buttons around the anchor (or the screen centre);
	          when it does not fit around an anchor by the edge it opens clear
	          of the anchor, toward the middle; the stick points at one
	  arc     a fan like a dock's stack: buttons one above another from the
	          anchor (below it from an anchor in the top half) along a gentle
	          curve, each tilted with it, its label in a pill on the side toward
	          the middle (toward = "left" or "right" picks the side); up and
	          down walk it in item order (D-pad, stick and arrow keys). Too tall
	          for the screen (a phone), it wraps into curves side by side, past
	          the labels, and up and down still walk every item in order, left
	          and right step across the curves
	Ring buttons show the item's icon (or its initials) with its label under
	it. shape (a value or a responsive value) picks the outline of ring and fan
	buttons: round, squircle (a rounded square) or square (slightly rounded
	corners). A ring or fan item's focus ring goes round the whole item, its
	button and its label (each button's ItemRing, a Component.partRing).

	It opens on the app's overlay layer as a modal: keyboard and gamepad focus
	stays inside, back and a press outside close it, and focus returns to the
	anchor. Picking an item calls onSelect, emits "select" and closes it.

	State keys: open, visible.
	Events: "open", "close" and "select" with the value, for Lucy.useUiSound.
	menu.items holds one list row per item, menu.slices one round button per
	item, in order; menu.variant(), menu.shape() and menu.size() are the ones in use.
	Menu.ring, Menu.fan, Menu.fanRows, Menu.fanLinks, Menu.toward, Menu.fit, Menu.around, Menu.nudge, Menu.angles,
	Menu.pick and Menu.itemBounds are the geometry it uses.
]]

local TextService = game:GetService("TextService")
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
Menu.sizes = { "md", "lg" }
Menu.towards = { "auto", "left", "right" }

-- A round button's size at each size (sliceSize is md's) and the room under it for its label
-- (lg's text is larger, so it has captionGrow more).
Menu.sliceSizes = { md = 56, lg = 72 }
Menu.sliceSize = Menu.sliceSizes.md
Menu.captionRoom = 26
Menu.captionGrow = 6
-- How far a label sits from its button: beside it (a fan) or under it (a ring).
Menu.captionGap = 10
Menu.captionDrop = 4
-- The room between a ring or fan item (its button and label) and the focus ring round it.
Menu.itemRingPad = 6
-- A fan's curve: the radius of the circle its buttons follow, and the room between them.
Menu.fanRadius = 900
Menu.fanGap = 10
-- Between a wrapped fan's curves, past the last one's labels: a focused item's ring clears the
-- next curve's buttons by about one ring's width (Menu.itemRingPad and its stroke), tilt included.
Menu.fanCurveGap = 34
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

-- A fan like a dock's stack: count buttons one after another from an anchor along a gentle
-- curve. `start` is the distance from the anchor's centre to the first button, `step` the distance
-- between buttons, both along the curve. `up` is -1 to rise up the screen and 1 to drop down it;
-- `bend` is 1 to curve right and -1 to curve left. Returns each button's offset from the anchor's
-- centre and its tilt in degrees, so each faces along the curve.
-- With `rows` (fewer than count), the fan wraps: rows buttons a curve, each next curve
-- `columnStep` beside the last, on the side away from the bend (where the labels are), its
-- buttons level with the first curve's.
function Menu.fan(
	count: number,
	start: number,
	step: number,
	radius: number,
	up: number,
	bend: number,
	rows: number?,
	columnStep: number?
): ({ Vector2 }, { number })
	local perCurve = math.max(1, rows or count)
	local points, tilts = {}, {}
	for i = 1, count do
		local row, column = (i - 1) % perCurve, (i - 1) // perCurve
		local theta = (start + row * step) / radius
		local x = bend * radius * (1 - math.cos(theta)) - bend * column * (columnStep or 0)
		points[i] = Vector2.new(x, up * radius * math.sin(theta))
		tilts[i] = math.deg(theta) * bend * -up
	end
	return points, tilts
end

-- How many buttons a fan puts on each curve: all of them when they fit in `room` (from the
-- anchor's centre to the screen's edge the fan runs toward), else as few curves as fit, the
-- buttons shared evenly between them.
function Menu.fanRows(count: number, room: number, start: number, step: number, size: number): number
	local fits = math.floor((room - start - size / 2) / step) + 1
	if fits >= count then
		return count
	end
	local curves = math.ceil(count / math.max(1, fits))
	return math.ceil(count / curves)
end

-- Where each arrow goes from each of a fan's buttons: along the fan (away from the anchor and
-- back) in item order, wrapping round, so a fan wrapped into curves walks as if it were one;
-- across to the button level with it on the next curve (`columnsRight`: the curves run right)
-- or the last on a shorter curve; nowhere (itself) past the outer curves. `usable[i]` false
-- (disabled) is passed over. `up` is the fan's, -1 when it rises. Indices into the items.
export type FanLink = { up: number, down: number, left: number, right: number }
function Menu.fanLinks(
	count: number,
	rows: number,
	up: number,
	columnsRight: boolean,
	usable: { boolean }
): { FanLink }
	local perCurve = math.max(1, rows)
	local function along(from: number, step: number): number
		for offset = 1, count do
			local index = ((from - 1 + step * offset) % count) + 1
			if usable[index] ~= false then
				return index
			end
		end
		return from
	end
	local function across(from: number, side: number): number
		local row, column = (from - 1) % perCurve, (from - 1) // perCurve
		local first = (column + side) * perCurve + 1
		if first < 1 or first > count then
			return from
		end
		local last = math.min(count, first + perCurve - 1)
		for index = math.min(first + row, last), first, -1 do
			if usable[index] ~= false then
				return index
			end
		end
		return from
	end
	local links = {}
	for i = 1, count do
		local away, back = along(i, 1), along(i, -1)
		local right, left =
			across(i, if columnsRight then 1 else -1), across(i, if columnsRight then -1 else 1)
		links[i] = {
			up = if up < 0 then away else back,
			down = if up < 0 then back else away,
			left = left,
			right = right,
		}
	end
	return links
end

export type Pad = { left: number, right: number, top: number, bottom: number }

-- How far to move `center` so every point around it, with `pad` around each, is `margin` inside
-- the screen.
function Menu.nudge(center: Vector2, points: { Vector2 }, pad: Pad, view: Vector2, margin: number): Vector2
	if #points == 0 then
		return Vector2.zero
	end
	local low, high = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for _, point in points do
		local at = center + point
		low = low:Min(at - Vector2.new(pad.left, pad.top))
		high = high:Max(at + Vector2.new(pad.right, pad.bottom))
	end
	local function axis(lowValue: number, highValue: number, limit: number): number
		if lowValue < margin then
			return margin - lowValue
		elseif highValue > limit - margin then
			return math.max(margin - lowValue, limit - margin - highValue)
		end
		return 0
	end
	return Vector2.new(axis(low.X, high.X, view.X), axis(low.Y, high.Y, view.Y))
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

-- Where the focus ring of a ring or fan item goes, in its button's own space: round the button
-- (`size` square) and its label (`caption`, the label's size) on `side` ("left", "right" or
-- "below"), with `pad` of room, and twice that past the label's far end (the ring's stroke sits
-- inside its edge, so it would run into the label's text). Returns its top left corner and size.
function Menu.itemBounds(side: string, size: number, caption: Vector2, pad: number): (Vector2, Vector2)
	local minX, minY, maxX, maxY = 0, 0, size, size
	local middle = size / 2
	if side == "left" or side == "right" then
		minY = math.min(0, middle - caption.Y / 2)
		maxY = math.max(size, middle + caption.Y / 2)
		if side == "left" then
			minX = -Menu.captionGap - caption.X - pad
		else
			maxX = size + Menu.captionGap + caption.X + pad
		end
	else
		minX = math.min(0, middle - caption.X / 2)
		maxX = math.max(size, middle + caption.X / 2)
		maxY = math.max(size, size + Menu.captionDrop + caption.Y + pad)
	end
	return Vector2.new(minX - pad, minY - pad), Vector2.new(maxX - minX + pad * 2, maxY - minY + pad * 2)
end

-- The centre of a ring opened from an anchor: around the anchor when the whole ring fits there,
-- otherwise clear of it toward the middle of the screen, so the ring never covers the button that
-- opened it.
function Menu.around(
	anchorCenter: Vector2,
	anchorSize: Vector2,
	extent: number,
	view: Vector2,
	margin: number
): Vector2
	local fitted = Menu.fit(anchorCenter, extent, view, margin)
	if (fitted - anchorCenter).Magnitude < 0.5 then
		return fitted
	end
	local angle = math.rad(Menu.toward(anchorCenter, view))
	local direction = Vector2.new(math.cos(angle), math.sin(angle))
	local along = math.abs(direction.X) * anchorSize.X / 2 + math.abs(direction.Y) * anchorSize.Y / 2
	return Menu.fit(anchorCenter + direction * (extent + along + 8), extent, view, margin)
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
	-- A ring or fan item's focus ring (round its button and label) follows the button's shape: a
	-- pill round a round button, a rounded box round a squircle or square one
	{
		selector = ".ui-menu-item-ring.ui-menu-squircle >> .ui-part-ring-corner",
		priority = 5,
		properties = { CornerRadius = UDim.new(0, 17 + Menu.itemRingPad) },
	},
	{
		selector = ".ui-menu-item-ring.ui-menu-squircle.ui-menu-lg >> .ui-part-ring-corner",
		priority = 6,
		properties = { CornerRadius = UDim.new(0, 22 + Menu.itemRingPad) },
	},
	-- size = "lg": larger text on rows, labels and initials
	{
		selector = ".ui-menu-item.ui-menu-lg >> .ui-menu-item-label",
		priority = 5,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-menu-slice.ui-menu-lg >> .ui-menu-caption",
		priority = 5,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-menu-slice.ui-menu-lg >> .ui-menu-slice-mark",
		priority = 5,
		properties = { TextSize = "$TextBase" },
	},
	{
		selector = ".ui-menu-item-ring.ui-menu-square >> .ui-part-ring-corner",
		priority = 5,
		properties = { CornerRadius = "$RadiusMd" },
	},
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
	-- A fan's labels are pills beside their buttons
	{
		selector = ".ui-menu-caption.ui-menu-caption-pill::UICorner",
		priority = 10,
		properties = { CornerRadius = UDim.new(0.5, 0) },
	},
	{
		selector = ".ui-menu-caption.ui-menu-caption-pill::UIPadding",
		priority = 10,
		properties = {
			PaddingLeft = "$Space3",
			PaddingRight = "$Space3",
			PaddingTop = "$Space1",
			PaddingBottom = "$Space1",
		},
	},
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
		local sizeName = Composables.useResponsive(app, p.size or "md") :: () -> string
		h.size = sizeName
		local function large(): boolean
			return sizeName() == "lg"
		end
		local function sliceSize(): number
			return Menu.sliceSizes[sizeName()] or Menu.sliceSize
		end
		local function captionRoom(): number
			return Menu.captionRoom + (if large() then Menu.captionGrow else 0)
		end
		local function isList(): boolean
			return variant() == "list"
		end
		local function isRing(): boolean
			return not isList()
		end
		local heightMd = Composables.useMetric(app, "ControlMd")
		local heightLg = Composables.useMetric(app, "ControlLg")
		local function height(): number
			return if large() then heightLg() else heightMd()
		end

		-- The ring's radius: by item count, so neighbours never overlap. A label sits under
		-- each button, so neighbours stay a button and a label apart.
		local function radius(): number
			if p.radius then
				return p.radius
			end
			local gap = sliceSize() + captionRoom() + 8
			if variant() == "arc" then
				return Menu.fanRadius
			end
			return math.max(80, math.ceil(gap / 2 / math.sin(math.pi / math.max(count, 2))))
		end
		local function extent(): number
			return radius() + sliceSize() / 2 + captionRoom()
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
		local hasIcon = false
		for _, item in entries do
			if item.icon then
				hasIcon = true
			end
		end
		local function indent(): number
			return if not hasIcon then 0 elseif large() then 28 else 24
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
				Tags = { "ui-menu-item" :: any, ["ui-disabled"] = off, ["ui-menu-lg"] = large },
				[ACTIVATED] = function()
					h:select(item.value)
				end,
				Element.new("TextLabel", {
					Name = "Label",
					Position = function(): UDim2
						return UDim2.fromOffset(indent(), 0)
					end,
					Size = function(): UDim2
						return UDim2.new(1, -(indent() + hintRoom), 1, 0)
					end,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = item.text,
					Tags = { "ui-menu-item-label" :: any, ["ui-disabled"] = off },
				}),
			})
			if item.icon then
				local icon = Icon.new({
					app = app,
					icon = item.icon,
					size = function(): string
						return if large() then "md" else "sm"
					end,
					name = "Icon",
				})
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

		-- The list is at least as wide as its widest row needs (label, icon column, key, padding),
		-- so a label never ends in an ellipsis however large the game styles its type. Measured
		-- with the label's styled font and size, again whenever its style changes.
		local fitWidth = Reactive.ref(0)
		local measuring = false
		local function measureRows()
			if measuring then
				return
			end
			measuring = true
			task.defer(function()
				measuring = false
				local widest = 0
				for index, row in rows do
					local label = row:FindFirstChild("Label") :: TextLabel?
					if label and label.Text ~= "" then
						local ok, bounds = pcall(function(): Vector2
							local params = Instance.new("GetTextBoundsParams")
							params.Text = label.Text
							params.Font = (label :: any):GetStyled("FontFace")
							params.Size = (label :: any):GetStyled("TextSize")
							params.Width = math.huge
							return TextService:GetTextBoundsAsync(params)
						end)
						if ok then
							local hintRoom = if entries[index].hint then 56 else 0
							widest = math.max(widest, bounds.X + indent() + hintRoom)
						end
					end
				end
				-- The row's padding (Space2 each side) and a little air, so rounding never truncates
				local pad = Component.space(app, "Space2", 8).Offset
				fitWidth(math.ceil(widest + pad * 2 + 8))
			end)
		end
		for _, row in rows do
			local label = row:FindFirstChild("Label")
			if label then
				pcall(function()
					(label :: any).StyledPropertiesChanged:Connect(measureRows)
				end)
			end
		end
		measureRows()

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

		-- The ring or arc. A fan's buttons tilt along its curve, with their labels beside them
		-- (left or right); a ring's labels sit below. Set when it is placed.
		local tilts = Reactive.ref({} :: { number })
		-- Where the arrows go from each fan button (empty for a ring: the engine and the stick)
		local links = Reactive.ref({} :: { FanLink })
		local labelSide = Reactive.ref("below")
		local fanSize = Reactive.ref(Vector2.zero)
		local slices = {}
		local captions = {}
		local ringFrame = Element.new("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			Visible = isRing,
			Size = function(): UDim2
				if not isRing() then
					return UDim2.fromOffset(0, 0)
				elseif variant() == "arc" then
					local size = fanSize()
					return UDim2.fromOffset(math.ceil(size.X), math.ceil(size.Y))
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
				Size = function(): UDim2
					local side = sliceSize()
					return UDim2.fromOffset(side, side)
				end,
				Position = function(): UDim2
					local at = points()[index] or Vector2.zero
					return UDim2.new(0.5, math.floor(at.X + 0.5), 0.5, math.floor(at.Y + 0.5))
				end,
				Rotation = function(): number
					return if variant() == "arc" then tilts()[index] or 0 else 0
				end,
				Visible = isRing,
				-- A fan walks in item order, also across its curves (Menu.fanLinks)
				NextSelectionUp = function(): GuiObject?
					local link = links()[index]
					return link and slices[link.up]
				end,
				NextSelectionDown = function(): GuiObject?
					local link = links()[index]
					return link and slices[link.down]
				end,
				NextSelectionLeft = function(): GuiObject?
					local link = links()[index]
					return link and slices[link.left]
				end,
				NextSelectionRight = function(): GuiObject?
					local link = links()[index]
					return link and slices[link.right]
				end,
				Interactable = usable,
				Selectable = usable,
				-- Its focus ring goes round the whole item, button and label (the ItemRing below)
				Tags = {
					"ui-menu-slice" :: any,
					"ui-ring-host",
					["ui-disabled"] = off,
					["ui-menu-lg"] = large,
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
			})
			local function beside(): boolean
				return labelSide() ~= "below"
			end
			captions[index] = Element.new("TextLabel", {
				Name = "Caption",
				AnchorPoint = function(): Vector2
					local side = labelSide()
					return if side == "left"
						then Vector2.new(1, 0.5)
						elseif side == "right" then Vector2.new(0, 0.5)
						else Vector2.new(0.5, 0)
				end,
				Position = function(): UDim2
					local side = labelSide()
					return if side == "left"
						then UDim2.new(0, -Menu.captionGap, 0.5, 0)
						elseif side == "right" then UDim2.new(1, Menu.captionGap, 0.5, 0)
						else UDim2.new(0.5, 0, 1, Menu.captionDrop)
				end,
				-- A pill beside its button is as tall as its text (and padding), so a game's
				-- theme can give it any text size
				Size = function(): UDim2
					return UDim2.fromOffset(0, if beside() then 0 elseif large() then 24 else 20)
				end,
				AutomaticSize = function(): Enum.AutomaticSize
					return if beside() then Enum.AutomaticSize.XY else Enum.AutomaticSize.X
				end,
				Text = item.text,
				Tags = { "ui-menu-caption" :: any, ["ui-disabled"] = off, ["ui-menu-caption-pill"] = beside },
				Parent = slice,
			})

			-- The item's focus ring (Component.partRing), round the button and its label. The label's
			-- size is measured in the button's own units: a UIScale above scales AbsoluteSize, not offsets.
			local caption = captions[index]
			local captionSize = Reactive.ref(Vector2.zero)
			local function measure()
				local scale = slice.AbsoluteSize.X / sliceSize()
				captionSize(if scale > 0 then caption.AbsoluteSize / scale else caption.AbsoluteSize)
			end
			caption:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
			measure()
			local function itemBounds(): (Vector2, Vector2)
				return Menu.itemBounds(labelSide(), sliceSize(), captionSize(), Menu.itemRingPad)
			end
			Element.hydrate(Component.partRing(app), {
				Name = "ItemRing",
				AnchorPoint = Vector2.zero,
				Position = function(): UDim2
					local at = itemBounds()
					return UDim2.fromOffset(math.floor(at.X), math.floor(at.Y))
				end,
				Size = function(): UDim2
					local _, size = itemBounds()
					return UDim2.fromOffset(math.ceil(size.X), math.ceil(size.Y))
				end,
				Tags = {
					"ui-menu-item-ring" :: any,
					["ui-menu-lg"] = large,
					["ui-menu-squircle"] = function(): boolean
						return shape() == "squircle"
					end,
					["ui-menu-square"] = function(): boolean
						return shape() == "square"
					end,
				},
				Parent = slice,
			})
			-- The whole item takes a press, as its focus ring shows it: the button, its label and the
			-- gap between them. Clear, never selected itself (the button is what focus lands on).
			Element.new("TextButton", {
				Name = "Hit",
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Selectable = false,
				Interactable = usable,
				ZIndex = 3,
				Position = function(): UDim2
					local at = itemBounds()
					return UDim2.fromOffset(math.floor(at.X), math.floor(at.Y))
				end,
				Size = function(): UDim2
					local _, size = itemBounds()
					return UDim2.fromOffset(math.ceil(size.X), math.ceil(size.Y))
				end,
				[ACTIVATED] = function()
					h:select(item.value)
				end,
				Parent = slice,
			})
			if item.icon then
				local icon = Icon.new({
					app = app,
					icon = item.icon,
					size = function(): number
						return if large() then 32 else 24
					end,
					name = "Icon",
				})
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
			returnFocus = p.returnFocus,
			presentation = function(): string
				return if isList() then "auto" else "popup"
			end,
			prefer = "popup",
			anchor = p.anchor,
			side = p.side or "auto",
			align = p.align,
			width = function(): number
				return math.max(p.width or 220, fitWidth())
			end,
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
					tilts({})
					links({})
					labelSide("below")
					center = if anchor
						then Menu.around(center, anchor.size, extent(), view, Overlay.margin)
						else Menu.fit(center, extent(), view, Overlay.margin)
				else
					-- Up from an anchor in the lower half, down from one in the upper half; labels
					-- on the side toward the middle, the curve bending away from them.
					local up = if center.Y > view.Y / 2 then -1 else 1
					local labelsLeft = if p.toward == "left"
						then true
						elseif p.toward == "right" then false
						else center.X >= view.X / 2
					local size = sliceSize()
					local start = (if anchor then anchor.size.Y / 2 else 0) + 12 + size / 2
					local step = size + Menu.fanGap
					-- Labels measured in the menu's own units: a UIScale above scales AbsoluteSize
					local shown = if slices[1] then slices[1].AbsoluteSize.X / size else 0
					local labelRoom = 0
					for index, item in entries do
						local measured = captions[index].AbsoluteSize.X / (if shown > 0 then shown else 1)
						labelRoom = math.max(labelRoom, measured, #item.text * 8 + 24)
					end
					labelRoom += 10
					-- Too many for the screen's height: the fan wraps into curves side by side, the
					-- next one past the labels of the last
					local room = if up < 0
						then center.Y - Overlay.margin
						else view.Y - Overlay.margin - center.Y
					local rows = Menu.fanRows(count, room, start, step, size)
					local fan, tilt = Menu.fan(
						count,
						start,
						step,
						r,
						up,
						if labelsLeft then 1 else -1,
						rows,
						size + labelRoom + Menu.fanCurveGap
					)
					points(fan)
					tilts(tilt)
					local usable = {}
					for index, item in entries do
						usable[index] = not item.disabled
					end
					links(Menu.fanLinks(count, rows, up, not labelsLeft, usable))
					labelSide(if labelsLeft then "left" else "right")
					local pad = {
						left = size / 2 + (if labelsLeft then labelRoom else 0),
						right = size / 2 + (if labelsLeft then 0 else labelRoom),
						top = size / 2,
						bottom = size / 2,
					}
					center += Menu.nudge(center, fan, pad, view, Overlay.margin)
					-- The frame around the centre covers every button and label.
					local reach = Vector2.zero
					for _, point in fan do
						reach = reach:Max(Vector2.new(math.abs(point.X), math.abs(point.Y)))
					end
					fanSize(Vector2.new(reach.X + size / 2 + labelRoom, reach.Y + size / 2) * 2)
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

		-- The stick points at a round button while a ring is open (a fan is a stack: up and down
		-- walk it).
		Composables.useWhile(function(): boolean
			return open() == true and variant() == "radial"
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
	check("size", Menu.sizes, given.size or "md")
	check("toward", Menu.towards, given.toward or "auto")
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
