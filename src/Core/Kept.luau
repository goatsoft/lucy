--!strict
--[[
	Kept (ADR 0062): frames a game keeps in sight over any modal overlay, such as the player's
	health while a modal inventory is open. Internal: games call app:keep(frame).

		local stop = app:keep(healthFrame)
		Kept.zones(app)   -- a ref: the kept frames' rectangles on the screen while they are kept

	While any modal overlay is open, each kept frame moves into the "kept" portal (display order
	920: above "modal", below "tour" and "toast") at the same place on the screen, and an empty
	spacer of its size takes its place where it was, so a layout around it does not move. When the
	last modal closes it goes back. A kept frame takes no presses while it is kept (Active off);
	presses go to the overlay under it. Docks leave its room (Core/Dock).
]]

local Reactive = require(script.Parent.Reactive)
local Scroll = require(script.Parent.Scroll)

local Kept = {}

export type Rect = { position: Vector2, size: Vector2 }

type Entry = {
	frame: GuiObject,
	lifted: boolean,
	spacer: Frame?,
	holder: Frame?,
	parent: Instance?,
	position: UDim2,
	size: UDim2,
	anchor: Vector2,
	active: boolean,
}

type State = {
	entries: { Entry },
	zones: Reactive.Ref<{ Rect }>,
	scope: Reactive.Scope,
}

local function state(app: any): State
	local existing = app._lucyKept
	if existing then
		return existing
	end
	local made: State = {
		entries = {},
		zones = Reactive.ref({}),
		scope = Reactive.effectScope(true),
	}
	app._lucyKept = made
	return made
end

local function publish(s: State)
	local list = {}
	for _, entry in s.entries do
		if entry.lifted and entry.frame.Visible then
			table.insert(list, { position = entry.frame.AbsolutePosition, size = entry.frame.AbsoluteSize })
		end
	end
	s.zones(list)
end

local function lift(app: any, s: State, entry: Entry)
	if entry.lifted then
		return
	end
	local frame = entry.frame
	local parent = frame.Parent
	if not parent then
		return
	end
	local portal = app:portal("kept")
	local scale = Scroll.scaleOf(portal)
	local spot = frame.AbsolutePosition - portal.AbsolutePosition
	local box = frame.AbsoluteSize

	local spacer = Instance.new("Frame")
	spacer.Name = frame.Name .. "_Kept"
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.fromOffset(box.X / scale, box.Y / scale)
	spacer.Position = frame.Position
	spacer.AnchorPoint = frame.AnchorPoint
	spacer.LayoutOrder = frame.LayoutOrder

	entry.parent = parent
	entry.position = frame.Position
	entry.size = frame.Size
	entry.anchor = frame.AnchorPoint
	entry.active = frame.Active

	local holder = Instance.new("Frame")
	holder.Name = "Kept"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = portal

	spacer.Parent = parent
	frame.AnchorPoint = Vector2.zero
	frame.Position = UDim2.fromOffset(spot.X / scale, spot.Y / scale)
	frame.Size = UDim2.fromOffset(box.X / scale, box.Y / scale)
	frame.Active = false
	frame.Parent = holder

	entry.spacer = spacer
	entry.holder = holder
	entry.lifted = true
	publish(s)
end

local function drop(s: State, entry: Entry)
	if not entry.lifted then
		return
	end
	local frame = entry.frame
	entry.lifted = false
	frame.AnchorPoint = entry.anchor
	frame.Position = entry.position
	frame.Size = entry.size
	frame.Active = entry.active
	if entry.parent and entry.parent.Parent then
		frame.Parent = entry.parent
	end
	if entry.spacer then
		entry.spacer:Destroy()
		entry.spacer = nil
	end
	if entry.holder then
		entry.holder:Destroy()
		entry.holder = nil
	end
	publish(s)
end

-- The kept frames' rectangles on the screen while they are kept (screen pixels)
function Kept.zones(app: any): Reactive.Ref<{ Rect }>
	return state(app).zones
end

function Kept.keep(app: any, frame: GuiObject): () -> ()
	local s = state(app)
	local entry: Entry = {
		frame = frame,
		lifted = false,
		spacer = nil,
		holder = nil,
		parent = nil,
		position = frame.Position,
		size = frame.Size,
		anchor = frame.AnchorPoint,
		active = frame.Active,
	}
	table.insert(s.entries, entry)

	local scope = Reactive.effectScope(true)
	scope:run(function()
		Reactive.watchEffect(function()
			if app:modalOpen() then
				lift(app, s, entry)
			else
				drop(s, entry)
			end
		end)
	end)
	local shown = frame:GetPropertyChangedSignal("Visible"):Connect(function()
		publish(s)
	end)

	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		shown:Disconnect()
		scope:stop()
		drop(s, entry)
		local index = table.find(s.entries, entry)
		if index then
			table.remove(s.entries, index)
		end
		publish(s)
	end
end

return Kept
