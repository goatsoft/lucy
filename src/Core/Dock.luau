--!strict
--[[
	Dock (ADR 0061, ADR 0062): sheets that open side by side from the edges of the screen (a
	Sheet's `dock` prop). Internal: Sheet calls it in place of Overlay.use when it is given a dock.

		local member = Dock.join(app, "loot", {
			open = shown,          -- the sheet's open ref; back and outside presses write false
			content = frame,       -- the sheet's frame (Core/PanelFrame)
			width = 360,           -- its width
			minWidth = 280,        -- how narrow it may go when the screen is short of room; it then
			                       -- scrolls sideways (default: width, it never shrinks)
			side = "right",        -- the edge this sheet docks to: left | right
			pin = false,           -- true: it holds its place at its edge, and sheets opened after it
			                       -- open inward beside it; false: the newest is at the edge
			slide = true,          -- false: appears and goes without sliding
			scrim = true,          -- false: drop the dimmed backdrop when every open sheet sets it
			dismissible = true,
			defaultFocus = fn,     -- what to select when it opens
			id = "bag",
		})
		member.presentation()  member.maxHeight()  member.safeBottom()  member.visible()
		member.width()         -- the width it has now (less than its width while squeezed)
		member.root  member.scrim  member.place()  member.close(reason?)

		Dock.fit(items, room)  -- pure: the widths sheets get in `room` (see Fitting)

	A dock has a row at each edge, and each sheet docks to its own `side`. At an edge, pinned
	sheets sit nearest it in the order they opened, then the unpinned ones, the newest of those
	nearest the edge: a newly opened unpinned sheet slides in there and pushes the rest inward. The
	dock is one overlay whatever the edges: one backdrop, one focus scope across all its sheets (the
	gamepad moves between them), and it counts as one modal. Back closes the newest; a press outside
	every sheet (between the rows too) closes them all. Opening a sheet in one dock closes the
	sheets of the app's other docks: one modal dock at a time.

	Fitting: the rows share the screen's width. When the open sheets do not fit at their widths,
	they give way, unpinned before pinned and the oldest first, each down to its minWidth; if even
	that is too much, each takes a share of the room by its minWidth. A squeezed sheet's body
	scrolls sideways. Nothing is scaled down. A frame kept with app:keep (Core/Kept) at the top or
	bottom of the screen is room a sheet under it leaves free.
]]

local TweenService = game:GetService("TweenService")

local Element = require(script.Parent.Element)
local Kept = require(script.Parent.Kept)
local Overlay = require(script.Parent.Overlay)
local Preferences = require(script.Parent.Preferences)
local Reactive = require(script.Parent.Reactive)
local Scroll = require(script.Parent.Scroll)

local Dock = {}

Dock.slideTime = 0.25 -- seconds a sheet takes to slide in or out
Dock.keptGap = 8 -- room left between a sheet and a kept frame beside its top or bottom
Dock.keptReach = 24 -- a kept frame this near the screen's top or bottom counts as on that edge

type Member = {
	open: Reactive.Ref<boolean>,
	content: GuiObject,
	width: number,
	minWidth: number,
	side: string,
	pin: boolean,
	scrim: boolean,
	dismissible: boolean,
	defaultFocus: (() -> any)?,
	holder: Frame,
	progress: NumberValue,
	shown: Reactive.Ref<number>, -- how far in it is, 0 to 1 (follows progress)
	closing: Reactive.Ref<boolean>,
	order: number,
	tween: Tween?,
}

type DockState = {
	name: string,
	members: { Member },
	version: Reactive.Ref<number>,
	room: Reactive.Ref<number>, -- the screen's width, in the overlay's own units
	frame: Frame,
	rows: { [string]: Frame },
	overlay: Overlay.Overlay,
	scope: Reactive.Scope,
	nextOrder: number,
}

export type Joined = {
	root: Frame,
	scrim: GuiObject,
	content: GuiObject,
	presentation: () -> string,
	maxHeight: () -> number,
	safeBottom: () -> number,
	visible: () -> boolean,
	width: () -> number,
	place: () -> (),
	close: (reason: string?) -> (),
}

export type FitItem = { width: number, minWidth: number, pin: boolean, order: number }

local function docks(app: any): { [string]: DockState }
	local all = app._lucyDocks
	if not all then
		all = {}
		app._lucyDocks = all
	end
	return all
end

local function isOpen(member: Member): boolean
	return (Reactive.peek(member.open :: any) :: any) == true
end

-- The open members, newest last
local function opened(dock: DockState): { Member }
	local list = {}
	for _, member in dock.members do
		if isOpen(member) then
			table.insert(list, member)
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

local function newest(dock: DockState): Member?
	local list = opened(dock)
	return list[#list]
end

local function focusOn(app: any, member: Member?)
	if not member or not app.input or not app.input:isNavigating() then
		return
	end
	local target = member.defaultFocus and member.defaultFocus()
	if type(target) == "table" and target.Instance then
		target = target.Instance
	end
	if typeof(target) ~= "Instance" then
		target = Overlay.firstSelectable(member.content)
	end
	if target then
		task.delay(Dock.slideTime, function()
			if isOpen(member) then
				app.input:focus(target)
			end
		end)
	end
end

-- Where a sheet sits in its edge's row, from the edge inward: pinned ones first in the order
-- they opened, then the unpinned, the newest first
local function rank(member: Member): number
	if member.pin then
		return member.order
	end
	return 2000000 - member.order
end

-- A row lists from its left: on the left edge the rank is the order, on the right reversed
local function layoutOrder(member: Member): number
	local r = rank(member)
	return if member.side == "left" then r else -r
end

--[[
	Pure. The widths `items` get in `room`. Each item's width is what it wants and its minWidth
	how far it will give way. When they do not all fit, they give way in turn, unpinned before
	pinned and the oldest (lowest order) first, each down to its minWidth. If the minWidths still
	do not fit, each gets a share of the room by its minWidth. Returns the widths in the items'
	order.
]]
function Dock.fit(items: { FitItem }, room: number): { number }
	local widths = {}
	local total = 0
	for i, item in items do
		widths[i] = item.width
		total += item.width
	end
	if total <= room then
		return widths
	end
	local least = 0
	for _, item in items do
		least += math.min(item.minWidth, item.width)
	end
	if least > room then
		for i, item in items do
			local floor = math.min(item.minWidth, item.width)
			widths[i] = if least > 0 then room * floor / least else 0
		end
		return widths
	end
	local turn = {}
	for i in items do
		table.insert(turn, i)
	end
	table.sort(turn, function(a, b)
		local x, y = items[a], items[b]
		if x.pin ~= y.pin then
			return not x.pin
		end
		return x.order < y.order
	end)
	local over = total - room
	for _, i in turn do
		if over <= 0 then
			break
		end
		local item = items[i]
		local give = math.min(over, item.width - math.min(item.minWidth, item.width))
		widths[i] -= give
		over -= give
	end
	return widths
end

local function make(app: any, name: string): DockState
	local scope = Reactive.effectScope(true)
	local dock: DockState = nil :: any
	scope:run(function()
		local version = Reactive.ref(0)
		local room = Reactive.ref(0)

		local frame = Element.new("Frame", {
			Name = "Edges",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),
		}) :: Frame
		local rows: { [string]: Frame } = {}
		for _, edge in { "left", "right" } do
			local left = edge == "left"
			local row = Element.new("Frame", {
				Name = if left then "Left" else "Right",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(if left then 0 else 1, 0),
				Position = UDim2.fromScale(if left then 0 else 1, 0),
				Size = UDim2.fromScale(1, 1),
			}) :: Frame
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.HorizontalAlignment = if left
				then Enum.HorizontalAlignment.Left
				else Enum.HorizontalAlignment.Right
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = row
			row.Parent = frame
			rows[edge] = row
		end
		-- The room the rows share follows the screen's width
		local function measure()
			local scale = Scroll.scaleOf(frame)
			local parent = frame.Parent
			local wide = if parent and parent:IsA("GuiBase2d")
				then parent.AbsoluteSize.X
				else frame.AbsoluteSize.X
			room(if scale > 0 then math.floor(wide / scale) else 0)
		end
		frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		frame.AncestryChanged:Connect(measure)

		-- Open while any sheet in it is open or still sliding out; writing false (a press outside)
		-- closes them all
		local anyShown = Reactive.computed({
			get = function(): boolean
				version()
				if not dock then
					return false
				end
				for _, member in dock.members do
					if member.open() or member.closing() then
						return true
					end
				end
				return false
			end,
			set = function(value: boolean)
				if value == false and dock then
					for _, member in dock.members do
						member.open(false)
					end
				end
			end,
		})

		local overlay = Overlay.use(app, {
			open = anyShown,
			content = frame,
			presentation = "panel",
			prefer = "panel",
			modal = true,
			scrim = function(): boolean
				version()
				if not dock then
					return false
				end
				for _, member in dock.members do
					if (member.open() or member.closing()) and member.scrim then
						return true
					end
				end
				return false
			end,
			dismissible = true,
			-- The frame spans the screen: only the sheets in it count as inside it
			solid = false,
			onBack = function()
				local top = newest(dock)
				if top and top.dismissible then
					top.open(false)
				end
			end,
			place = function(_presentation: string, input: Overlay.PlaceInput): Overlay.Placement
				local inset = math.max(0, input.top or 0)
				return {
					anchorPoint = Vector2.zero,
					position = UDim2.fromOffset(0, inset),
					width = input.view.X,
					fullHeight = true,
					top = inset,
					maxHeight = math.max(0, input.view.Y - inset),
				}
			end,
			defaultFocus = function(): any
				local top = newest(dock)
				if not top then
					return nil
				end
				local target = top.defaultFocus and top.defaultFocus()
				return target or Overlay.firstSelectable(top.content)
			end,
			id = name,
			name = "Dock",
			tags = { "ui-dock" },
		})

		dock = {
			name = name,
			members = {},
			version = version,
			room = room,
			frame = frame,
			rows = rows,
			overlay = overlay,
			scope = scope,
			nextOrder = 0,
		}
	end)
	return dock
end

-- The widths every member has now, by member (scaled by how far in each is)
local function widthsOf(dock: DockState): { [Member]: number }
	local items: { FitItem } = {}
	local list: { Member } = {}
	for _, member in dock.members do
		local shown = member.shown()
		if shown > 0 then
			table.insert(list, member)
			table.insert(items, {
				width = member.width * shown,
				minWidth = member.minWidth * shown,
				pin = member.pin,
				order = member.order,
			})
		end
	end
	local widths = Dock.fit(items, dock.room())
	local out = {}
	for i, member in list do
		out[member] = widths[i]
	end
	return out
end

-- Slides a member in (to 1) or out (to 0); the dock places itself as it goes
local function slide(member: Member, target: number, animate: boolean, done: (() -> ())?)
	if member.tween then
		member.tween:Cancel()
		member.tween = nil
	end
	if not animate or Preferences.reducedMotion() then
		member.progress.Value = target
		if done then
			done()
		end
		return
	end
	local tween = TweenService:Create(
		member.progress,
		TweenInfo.new(Dock.slideTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = target }
	)
	member.tween = tween
	tween.Completed:Once(function(state)
		if member.tween == tween then
			member.tween = nil
		end
		if state == Enum.PlaybackState.Completed and done then
			done()
		end
	end)
	tween:Play()
end

-- Room a member leaves at its top and bottom for kept frames beside it (overlay units)
local function keptRoom(holder: Frame, zones: { Kept.Rect }): (number, number)
	if #zones == 0 then
		return 0, 0
	end
	local scale = Scroll.scaleOf(holder)
	if scale <= 0 then
		return 0, 0
	end
	local at = holder.AbsolutePosition
	local size = holder.AbsoluteSize
	local top, bottom = 0, 0
	local reach = Dock.keptReach * scale
	for _, zone in zones do
		local left = math.max(at.X, zone.position.X)
		local right = math.min(at.X + size.X, zone.position.X + zone.size.X)
		if right <= left then
			continue
		end
		local zoneBottom = zone.position.Y + zone.size.Y
		if zoneBottom >= at.Y + size.Y - reach then
			bottom = math.max(bottom, (at.Y + size.Y - zone.position.Y) / scale + Dock.keptGap)
		elseif zone.position.Y <= at.Y + reach then
			top = math.max(top, (zoneBottom - at.Y) / scale + Dock.keptGap)
		end
	end
	return math.max(0, math.floor(top)), math.max(0, math.floor(bottom))
end

function Dock.join(app: any, name: string, options: { [string]: any }): Joined
	if not Reactive._hasOwner() then
		error("[Lucy] Dock.join needs an owner: call it in a component's render", 2)
	end
	local all = docks(app)
	local dock = all[name]
	if not dock then
		dock = make(app, name)
		all[name] = dock
	end

	local side = if options.side == "left" then "left" else "right"
	local left = side == "left"
	local content: GuiObject = options.content
	local width: number = options.width or Overlay.panelWidth
	local minWidth: number = math.min(options.minWidth or width, width)
	local animate = options.slide ~= false
	local progress = Instance.new("NumberValue")
	local shown = Reactive.ref(0)
	local rect = Reactive.ref(0) -- changes when the holder moves or resizes (for kept room)
	local zones = Kept.zones(app)

	local member: Member = nil :: any
	-- The width this sheet has now, scaled by how far in it is
	local function now(): number
		dock.version()
		local widths = widthsOf(dock)
		return widths[member] or 0
	end
	local holder = Element.new("Frame", {
		Name = options.id or "Sheet",
		BackgroundTransparency = 1,
		ClipsDescendants = function(): boolean
			return shown() < 1
		end,
		Size = function(): UDim2
			return UDim2.new(0, math.floor(now() + 0.5), 1, 0)
		end,
	}) :: Frame
	local function room(): (number, number)
		rect()
		return keptRoom(holder, zones())
	end
	-- The panel keeps its own width inside (all of it, or what fitting leaves it), from the edge
	-- side, so it slides out from there; it stops short of kept frames above or below it
	content.AnchorPoint = Vector2.new(if left then 1 else 0, 0)
	Element.hydrate(content, {
		Position = function(): UDim2
			local top = room()
			return UDim2.new(if left then 1 else 0, 0, 0, top)
		end,
		Size = function(): UDim2
			local s = shown()
			local full = if s > 0 then now() / s else width
			local top, bottom = room()
			return UDim2.new(0, math.floor(full + 0.5), 1, -(top + bottom))
		end,
	})
	content.Parent = holder
	holder.Parent = dock.rows[side]

	member = {
		open = options.open,
		content = content,
		width = width,
		minWidth = minWidth,
		side = side,
		pin = options.pin == true,
		scrim = options.scrim ~= false,
		dismissible = options.dismissible ~= false,
		defaultFocus = options.defaultFocus,
		holder = holder,
		progress = progress,
		shown = shown,
		closing = Reactive.ref(false),
		order = 0,
		tween = nil,
	}
	table.insert(dock.members, member)
	dock.version(dock.version() + 1)

	local changed = progress.Changed:Connect(function(value: number)
		shown(value)
		dock.overlay.place()
	end)
	local function moved()
		rect(rect() + 1)
	end
	local movedAt = holder:GetPropertyChangedSignal("AbsolutePosition"):Connect(moved)
	local movedSize = holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(moved)

	Reactive.watch(member.open, function(isNowOpen, previous)
		if isNowOpen and not previous then
			-- One modal dock at a time: the others close
			for otherName, other in all do
				if otherName ~= name then
					for _, m in other.members do
						if isOpen(m) then
							m.open(false)
						end
					end
				end
			end
			dock.nextOrder += 1
			member.order = dock.nextOrder
			holder.LayoutOrder = layoutOrder(member)
			member.closing(false)
			holder.Visible = true
			dock.version(dock.version() + 1)
			slide(member, 1, animate)
			focusOn(app, member)
		elseif not isNowOpen and previous then
			member.closing(true)
			slide(member, 0, animate, function()
				if not isOpen(member) then
					member.closing(false)
					holder.Visible = false
					dock.overlay.place()
				end
			end)
			-- focus goes to the newest still open
			local focused = app.input and app.input:focused()
			if focused and focused:IsDescendantOf(holder) then
				focusOn(app, newest(dock))
			end
		end
	end, { immediate = true })
	if not isOpen(member) then
		holder.Visible = false
	end

	Reactive.onCleanup(function()
		changed:Disconnect()
		movedAt:Disconnect()
		movedSize:Disconnect()
		if member.tween then
			member.tween:Cancel()
		end
		local index = table.find(dock.members, member)
		if index then
			table.remove(dock.members, index)
		end
		dock.version(dock.version() + 1)
		holder:Destroy()
		progress:Destroy()
		dock.overlay.place()
	end)

	local overlay = dock.overlay
	return {
		root = overlay.root,
		scrim = overlay.scrim,
		content = content,
		presentation = function(): string
			return "panel"
		end,
		maxHeight = function(): number
			local top, bottom = room()
			return math.max(0, overlay.maxHeight() - top - bottom)
		end,
		safeBottom = function(): number
			return 0
		end,
		visible = function(): boolean
			return member.open() or member.closing()
		end,
		width = function(): number
			local s = shown()
			return if s > 0 then now() / s else width
		end,
		place = overlay.place,
		close = function(_reason: string?)
			member.open(false)
		end,
	}
end

return Dock
