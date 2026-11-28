--!strict
--[[
	Dock: sheets that open side by side from one edge of the screen (a Sheet's `dock` prop). Internal:
	Sheet calls it in place of Overlay.use when it is given a dock.

		local member = Dock.join(app, "loot", {
			open = shown,          -- the sheet's open ref; back and outside presses write false
			content = frame,       -- the sheet's frame (Core/PanelFrame)
			width = 360,           -- its width
			side = "right",        -- the edge the dock opens from (its first sheet's says)
			dismissible = true,
			defaultFocus = fn,     -- what to select when it opens
			id = "bag",
		})
		member.presentation()  member.maxHeight()  member.safeBottom()  member.visible()
		member.root  member.scrim  member.place()  member.close(reason?)

	Every sheet in a dock opens at the dock's edge, and the ones already open slide over to make
	room: the newest is always at the edge, the rest beside it in the order they opened. A sheet
	slides in as it opens and out as it closes, and the others slide back (no slide with reduced
	motion). The dock is one overlay: one backdrop, one focus scope across all its sheets (the
	gamepad moves between them), and it counts as one modal. Back closes the newest; a press
	outside closes them all. Docked sheets are always panels, whatever the input: on a narrow
	screen each takes its share of the room.
]]

local TweenService = game:GetService("TweenService")

local Element = require(script.Parent.Element)
local Overlay = require(script.Parent.Overlay)
local Preferences = require(script.Parent.Preferences)
local Reactive = require(script.Parent.Reactive)

local Dock = {}

Dock.slideTime = 0.25 -- seconds a sheet takes to slide in or out

type Member = {
	open: Reactive.Ref<boolean>,
	content: GuiObject,
	width: number,
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
	members: { Member },
	version: Reactive.Ref<number>,
	row: Frame,
	layout: UIListLayout,
	overlay: Overlay.Overlay,
	side: string,
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
	place: () -> (),
	close: (reason: string?) -> (),
}

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

local function make(app: any, name: string, side: string): DockState
	local scope = Reactive.effectScope(true)
	local dock: DockState = nil :: any
	scope:run(function()
		local version = Reactive.ref(0)
		local left = side == "left"
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = if left
			then Enum.HorizontalAlignment.Left
			else Enum.HorizontalAlignment.Right
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		local row = Element.new("Frame", {
			Name = "Dock",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),
		}) :: Frame
		layout.Parent = row

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

		-- The dock's width: what each sheet shows of itself, kept on the screen
		local function total(view: number): number
			local room = math.floor(view * Overlay.panelShare)
			local sum = 0
			for _, member in dock.members do
				sum += member.width * member.shown()
			end
			return math.min(sum, room)
		end

		local overlay = Overlay.use(app, {
			open = anyShown,
			content = row,
			presentation = "panel",
			prefer = "panel",
			modal = true,
			dismissible = true,
			onBack = function()
				local top = newest(dock)
				if top and top.dismissible then
					top.open(false)
				end
			end,
			place = function(_presentation: string, input: Overlay.PlaceInput): Overlay.Placement
				local inset = math.max(0, input.top or 0)
				return {
					anchorPoint = Vector2.new(if left then 0 else 1, 0),
					position = UDim2.new(if left then 0 else 1, 0, 0, inset),
					width = total(input.view.X),
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
			members = {},
			version = version,
			row = row,
			layout = layout,
			overlay = overlay,
			side = side,
			scope = scope,
			nextOrder = 0,
		}
	end)
	return dock
end

-- Slides a member in (to 1) or out (to 0); the dock places itself as it goes
local function slide(member: Member, target: number, done: (() -> ())?)
	if member.tween then
		member.tween:Cancel()
		member.tween = nil
	end
	if Preferences.reducedMotion() then
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

function Dock.join(app: any, name: string, options: { [string]: any }): Joined
	if not Reactive._hasOwner() then
		error("[Lucy] Dock.join needs an owner: call it in a component's render", 2)
	end
	local side = if options.side == "left" then "left" else "right"
	local all = docks(app)
	local dock = all[name]
	if not dock then
		dock = make(app, name, side)
		all[name] = dock
	end
	local left = dock.side == "left"

	local content: GuiObject = options.content
	local width: number = options.width or Overlay.panelWidth
	local append = options.append == true
	local animateSlide = options.slide ~= false
	local progress = Instance.new("NumberValue")
	local shown = Reactive.ref(0)
	local holder = Element.new("Frame", {
		Name = options.id or "Sheet",
		BackgroundTransparency = 1,
		ClipsDescendants = function(): boolean
			return shown() < 1
		end,
		Size = function(): UDim2
			return UDim2.new(0, math.floor(width * shown() + 0.5), 1, 0)
		end,
	}) :: Frame
	-- The panel keeps its full width inside, from the dock's own edge, so it slides out from there
	local pinRight = if append then not left else left
	content.AnchorPoint = Vector2.new(if pinRight then 1 else 0, 0)
	content.Position = UDim2.fromScale(if pinRight then 1 else 0, 0)
	content.Size = UDim2.new(0, width, 1, 0)
	content.Parent = holder
	holder.Parent = dock.row

	local member: Member = {
		open = options.open,
		content = content,
		width = width,
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

	Reactive.watch(member.open, function(isNowOpen, previous)
		if isNowOpen and not previous then
			dock.nextOrder += 1
			member.order = dock.nextOrder
			-- Default: newest sits at the outer edge (first on left, last on right).
			-- With append = true: newest sits on the inner side (to the right of existing sheets on a left dock).
			holder.LayoutOrder = if left
				then (if append then member.order else -member.order)
				else (if append then -member.order else member.order)
			member.closing(false)
			holder.Visible = true
			if animateSlide then
				slide(member, 1)
			else
				if member.tween then
					member.tween:Cancel()
					member.tween = nil
				end
				member.progress.Value = 1
			end
			focusOn(app, member)
		elseif not isNowOpen and previous then
			member.closing(true)
			local function finishClose()
				if not isOpen(member) then
					member.closing(false)
					holder.Visible = false
					dock.overlay.place()
				end
			end
			if animateSlide then
				slide(member, 0, finishClose)
			else
				if member.tween then
					member.tween:Cancel()
					member.tween = nil
				end
				member.progress.Value = 0
				finishClose()
			end
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
		maxHeight = overlay.maxHeight,
		safeBottom = function(): number
			return 0
		end,
		visible = function(): boolean
			return member.open() or member.closing()
		end,
		place = overlay.place,
		close = function(_reason: string?)
			member.open(false)
		end,
	}
end

return Dock
