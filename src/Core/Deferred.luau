--!strict
--[[
	Deferred: content a component builds later than it is made (ADR 0049): the first time it
	shows (mount = "shown"), or the first time it is scrolled near (mount = "intersect").
	Shared by Tabs, Stack, and every component that opens and closes.

		local mount, keep = Deferred.mode(props, "Tabs") -- reads and checks `mount` and `keep`

		local part = Deferred.new(handle, {
			slots = { panel },        -- where the content goes
			build = function(part)    -- makes the content and puts it in the slots
				Deferred.place(panel, props.content)
			end,
			keep = keep,              -- false: removed when it stops showing
			name = "songs",           -- which part this is, when a component has several (a tab's value)
		})
		part:build()                  -- builds now; true when this call built it
		part:remove()                 -- takes away what build made
		part.built()                  -- a ref: true while the content exists

	For a component that opens and closes:

		local shown = part:follow(open, { visible = visible }) -- in render
		part:start(open)                                      -- once the handle is finished

	`shown` reads true once `open` is true and the content is built, and writing it writes
	`open`. Hand `shown` to whatever must not see "open" before the content exists (placing,
	focus, the game's onOpenChange): watchers on `open` itself run in no set order, so one of
	them could otherwise find an empty panel. A builder that throws closes the component
	again and reports the error. With keep = false the content is removed once `visible`
	(`open` when left out) goes false while closed, so a drawer can slide out first.

	For a list whose children are built as they are scrolled near (Stack):

		Deferred.intersect(parts) -- in render; each part's first slot is the frame that is watched

	A part is built the first time its slot is shown and within Scroll.overscan views of the
	visible part of the ScrollingFrame around it (with none around it, as soon as it shows).
	The slot must hold some room before it is built, or every slot is in view at once.

	The content has a scope of its own under the component's, so it lives until it is removed
	or the component is destroyed, whatever asked for the build. Removing destroys what the
	slots did not hold before the build, so a slot's own layout and padding stay.

	Every part is listed in `handle._deferred`, where Devtools reads what is not built yet.
]]

local RunService = game:GetService("RunService")

local Component = require(script.Parent.Component)
local Preload = require(script.Parent.Preload)
local Reactive = require(script.Parent.Reactive)
local Scroll = require(script.Parent.Scroll)

local Deferred = {}

-- Where an error from a builder run by `follow` goes. A spec may swap it.
Deferred.report = function(err: any)
	task.spawn(error, err, 0)
end

export type Options = {
	slots: { Instance },
	build: (part: any) -> (),
	keep: boolean?,
	name: any?,
	removed: (() -> ())?, -- runs after `remove` has taken the content away
}

local Part = {}
Part.__index = Part

type PartFields = {
	handle: any,
	slots: { Instance },
	name: any?,
	keep: boolean,
	built: Reactive.Ref<boolean>,
	_build: (part: any) -> (),
	_removed: (() -> ())?,
	_scope: Reactive.Scope?,
	_before: { [Instance]: boolean }?,
	_building: boolean,
}
export type Part = typeof(setmetatable({} :: PartFields, Part))

local SHOWN_MOUNTS = { "immediate", "shown" }

--[[
	`mount` and `keep` as a component's props give them: when its content is built
	("immediate" when the component is made, "shown" the first time it shows, "intersect" the
	first time it is scrolled near), and whether it is kept after. `allowed` lists the values
	the component takes (immediate and shown when left out) and `default` the one it takes when
	the prop is left out ("shown"). `keep` goes with "shown" only: "immediate" content is always
	kept, and so far "intersect" content is too.
]]
function Deferred.mode(
	props: { [string]: any },
	what: string,
	allowed: { string }?,
	default: string?
): (string, boolean)
	local values = allowed or SHOWN_MOUNTS
	local mount = props.mount
	if mount == nil then
		mount = default or "shown"
	end
	if type(mount) ~= "string" or not table.find(values, mount) then
		error(`[Lucy] {what}: mount is "{table.concat(values, '" or "')}", not "{tostring(mount)}"`, 0)
	end
	local keep = props.keep
	if keep ~= nil then
		if type(keep) ~= "boolean" then
			error(`[Lucy] {what}: keep is true or false, not "{tostring(keep)}"`, 0)
		end
		if mount ~= "shown" then
			error(
				`[Lucy] {what}: keep goes with mount = "shown"; with mount = "{mount}" the content is always kept`,
				0
			)
		end
	end
	return mount, keep ~= false
end

-- Puts `item` (an Instance, a handle or a list of them) in `slot`, unless it is in there already.
local function adoptNew(slot: Instance, item: any, order: number): number
	local kind = typeof(item)
	if kind == "Instance" then
		if item == slot or item:IsDescendantOf(slot) then
			return order
		end
		return Component.adopt(slot, item, order)
	end
	if kind == "table" then
		if typeof(item.Instance) == "Instance" then
			return adoptNew(slot, item.Instance, order)
		end
		for _, child in ipairs(item) do
			order = adoptNew(slot, child, order)
		end
	end
	return order
end

--[[
	Runs a builder as `builder(slot)`. What it parents to `slot` stays; an Instance, a handle
	or a list of them it returns is put in `slot` unless it is inside it already. `content`
	may also be the Instance, handle or list itself.
]]
function Deferred.place(slot: Instance, content: any)
	local result = content
	if type(content) == "function" then
		result = content(slot)
	end
	adoptNew(slot, result, 0)
end

function Deferred.new(handle: any, options: Options): Part
	local fields: PartFields = {
		handle = handle,
		slots = options.slots,
		name = options.name,
		keep = options.keep ~= false,
		built = Reactive.ref(false),
		_build = options.build,
		_removed = options.removed,
		_scope = nil,
		_before = nil,
		_building = false,
	}
	local part: Part = setmetatable(fields, Part)
	local list = handle._deferred
	if not list then
		list = {}
		handle._deferred = list
	end
	table.insert(list, part)
	return part
end

-- Ends the content's scope and destroys what the slots did not hold before the build.
local function clear(part: Part)
	local scope = part._scope
	part._scope = nil
	if scope then
		scope:stop()
	end
	local before = part._before
	part._before = nil
	if not before then
		return
	end
	for _, slot in part.slots do
		for _, child in slot:GetChildren() do
			if not before[child] then
				child:Destroy()
			end
		end
	end
end

--[[
	Builds the content now. True when this call built it; false when it was built already or
	the component is destroyed. A builder that throws leaves nothing behind and the error goes
	to the caller, so the next call builds afresh.
]]
function Part.build(self: Part): boolean
	local handle = self.handle
	if handle.destroyed or self._building or Reactive.peek(self.built) then
		return false
	end
	local before: { [Instance]: boolean } = {}
	for _, slot in self.slots do
		for _, child in slot:GetChildren() do
			before[child] = true
		end
	end
	self._before = before
	-- A scope under the component's, never under whatever is running now: a watcher's own
	-- scope ends when the watcher runs again, and the content must outlive that.
	local scope: Reactive.Scope = handle.scope:run(Reactive.effectScope)
	self._scope = scope
	self._building = true
	local ok, err = pcall(scope.run, scope, Reactive.untrack, self._build, self)
	self._building = false
	if not ok then
		clear(self)
		error(err, 0)
	end
	-- Mounting claimed the selection ring of what the component held then; this is new
	for _, slot in self.slots do
		for _, child in slot:GetChildren() do
			if not before[child] then
				Component.claimSelection(handle.app, child)
			end
		end
	end
	self.built(true)
	return true
end

-- Takes away what `build` made. `built` goes false first, so nothing sees a half removed panel.
function Part.remove(self: Part)
	if not Reactive.peek(self.built) then
		return
	end
	self.built(false)
	clear(self)
	if self._removed then
		self._removed()
	end
end

-- The slots a Dialog or Sheet builds on open, in the order they are placed.
local SLOTS = { "header", "children", "footer", "corner" }

--[[
	For Dialog and Sheet (slot components): whether `props` gives one `build` function that
	makes its content, in place of the slots. Both is an error. (When it is built is `mount`.)
]]
function Deferred.building(props: { [string]: any }, what: string): boolean
	local build = props.build
	if build == nil then
		return false
	end
	if type(build) ~= "function" then
		error(`[Lucy] {what}: build is a function returning \{ header, children, footer, corner \}`, 0)
	end
	local given = {}
	for _, name in SLOTS do
		if props[name] ~= nil then
			table.insert(given, name)
		end
	end
	if #given > 0 then
		error(
			`[Lucy] {what}: give build or the slots, not both; move {table.concat(given, ", ")} into what build returns`,
			0
		)
	end
	return true
end

--[[
	For a Dialog or Sheet with `build`, inside its presence: runs `props.build(handle)` and puts
	what it returns, { header, children, footer, corner }, in those slots in that order, so
	something made once (a Tabs: its bar in the header, itself in the body) goes in both. Returns
	what it made.
]]
function Deferred.placeBuild(
	handle: any,
	props: { [string]: any },
	what: string,
	slots: { [string]: Instance }
): { [string]: any }
	local made = props.build(handle)
	if made == nil then
		made = {}
	end
	if type(made) ~= "table" or typeof(made.Instance) == "Instance" then
		error(`[Lucy] {what}: build returns \{ header, children, footer, corner \} or nothing`, 0)
	end
	for _, name in SLOTS do
		if made[name] ~= nil then
			Component.adopt(slots[name], made[name])
		end
	end
	return made
end

--[[
	The part for a Dialog or Sheet with `build` (Deferred.building said so): `props.build(handle)`
	runs once on first open and returns { header, children, footer, corner }, each placed in its
	slot in that order, so something made once (a Tabs: its bar in the header, itself in the
	body) goes in both. `placed(made)` runs after, for what follows the content (which slots
	show).
]]
function Deferred.slots(
	handle: any,
	props: { [string]: any },
	what: string,
	slots: { [string]: Instance },
	options: { removed: (() -> ())?, placed: ((made: { [string]: any }) -> ())? }?
): Part
	local list = {}
	for _, name in SLOTS do
		table.insert(list, slots[name])
	end
	local placed = options and options.placed
	return Deferred.new(handle, {
		slots = list,
		keep = props.keep,
		removed = options and options.removed,
		build = function()
			local made = props.build(handle)
			if made == nil then
				made = {}
			end
			if type(made) ~= "table" or typeof(made.Instance) == "Instance" then
				error(`[Lucy] {what}: build returns \{ header, children, footer, corner \} or nothing`, 0)
			end
			for _, name in SLOTS do
				if made[name] ~= nil then
					Component.adopt(slots[name], made[name])
				end
			end
			if placed then
				placed(made)
			end
		end,
	})
end

local function buildOrClose(self: Part, open: Reactive.Ref<boolean>)
	local ok, err = pcall(self.build, self)
	if not ok then
		open(false)
		Deferred.report(err)
	end
end

--[[
	For a component that opens and closes. Builds when `open` goes true, and returns `shown`:
	true once it is open and built, and a write to it writes `open`. Call it in render.
	options.visible: a getter that stays true while a closed component is still on screen
	(sliding out); with keep = false the content is removed once it goes false.
]]
function Part.follow(
	self: Part,
	open: Reactive.Ref<boolean>,
	options: { visible: (() -> boolean)? }?
): Reactive.Ref<boolean>
	local built = self.built
	local shown = Reactive._accessor(function(): boolean
		return open() == true and built()
	end, function(value: boolean)
		open(value)
	end)
	-- Why an effect and not a binding: building makes instances and a scope, must also run on
	-- demand (`build`), and has to finish before `shown` turns true; nothing declarative can own
	-- that (a show branch has no memory for kept content and runs late inside a batch). An
	-- effect, not a watch: a failed build writes `open` false from inside this run, and a watch
	-- would go on remembering true and skip the next open. The first run is mount, where `start`
	-- builds once the handle is finished.
	local mounted = false
	Reactive._effect(function()
		local isOpen = open()
		if not mounted then
			mounted = true
		elseif isOpen then
			Reactive._untracked(buildOrClose, self, open)
		end
	end)
	if not self.keep then
		local visible: () -> boolean = (options and options.visible) or open
		-- Why a watch: removing ends the content's scope and destroys what `build` made, the
		-- other half of the same side effect, and it must wait for the moment the panel has left
		-- the screen
		Reactive.watch(visible, function(isVisible)
			-- Opened again while it slid out: it stays
			if not isVisible and not Reactive.peek(open) then
				self:remove()
			end
		end)
	end
	return shown
end

--[[
	Builds each part the first time its first slot is shown and near the visible part of the
	ScrollingFrame around it (Scroll.whenNear: within Scroll.overscan views). Call it in render.
	A builder that throws is reported and that part is left alone (`part:build()` tries again).

	Why signals and not a binding: building makes instances and a scope, and what triggers it
	is layout the engine reports through property signals, which nothing reactive tracks.
]]
function Deferred.intersect(parts: { Part })
	local stops: { () -> () } = {}
	for index, part in parts do
		stops[index] = Scroll.whenNear(part.slots[1] :: GuiObject, function()
			if part.handle.destroyed or Reactive.peek(part.built) then
				return
			end
			local ok, err = pcall(part.build, part)
			if not ok then
				Deferred.report(err)
			end
		end)
	end
	Reactive.onCleanup(function()
		for _, stop in stops do
			stop()
		end
	end)
end

--[[
	Lucy.prebuild(handles): builds, ahead of time, the content of components that build on
	first show (a Sheet or Dialog with `build`, a Tabs, a Stack with mount = "intersect"), one
	handle a frame so no frame pays for more than one. For the panels players open first, once
	they are in the game. Each handle's own `build()` is called, so a component that is built
	already, was opened meanwhile or is destroyed costs nothing. Returns a job: `done()` and
	`progress()` (0 to 1) are getters to follow.
]]
function Deferred.prebuild(handles: { any }): { done: () -> boolean, progress: () -> number }
	local total = #handles
	local finished = Reactive.ref(0)
	task.spawn(function()
		for index, handle in handles do
			if not handle.destroyed and type(handle.build) == "function" then
				local ok, err = pcall(handle.build, handle)
				if not ok then
					Deferred.report(err)
				end
			end
			finished(index)
			if index < total then
				RunService.Heartbeat:Wait()
			end
		end
	end)
	return {
		done = function(): boolean
			return finished() >= total
		end,
		progress = function(): number
			return if total == 0 then 1 else finished() / total
		end,
	}
end

-- A list of handles or instances from one, a list of them, or a function returning either
local function listOf(value: any): { any }
	if type(value) == "function" then
		value = value()
	end
	if value == nil then
		return {}
	end
	if typeof(value) == "Instance" or (type(value) == "table" and value.Instance ~= nil) then
		return { value }
	end
	return value
end

--[[
	Anticipation (ADR 0051), for an overlay that builds on open (Dialog, Sheet, Menu, Select):

		preload = { ids } or function() return { ids } end   -- its pictures, read when needed
		trigger = button or handle or { ... }                  -- what opens it: hovered or focused,
		                                                       -- it warms
		ahead = { overlays } or function() return ... end    -- warmed when this one opens

	handle:warm() warms its pictures and builds it ahead (one overlay a frame, as Lucy.prebuild),
	without opening it. On open its pictures go to the front of the queue. Call once the handle is
	finished; it lives in the handle's scope.
]]
function Deferred.anticipate(handle: any, props: { [string]: any }, what: string)
	local preloadOf = props.preload
	if preloadOf ~= nil and type(preloadOf) ~= "function" and type(preloadOf) ~= "table" then
		error(`[Lucy] {what}: preload is a list of pictures or a function returning one`, 3)
	end
	local function pictures(): { any }
		if type(preloadOf) == "function" then
			return preloadOf() or {}
		end
		return preloadOf or {}
	end
	local built = false
	function handle.warm(h: any)
		if h.destroyed then
			return
		end
		if preloadOf ~= nil then
			Preload.preload(pictures())
		end
		if not built then
			built = true
			Deferred.prebuild({ h })
		end
	end
	local scope = handle.scope
	if not scope then
		return
	end
	scope:run(function()
		-- Why a watch: opening hands work to other systems (the picture queue, other overlays'
		-- builds), side effects with nothing declarative to bind
		Reactive.watch(handle:ref("open"), function(isOpen: boolean)
			if not isOpen then
				return
			end
			if preloadOf ~= nil then
				Preload.preload(pictures(), { first = true })
			end
			for _, other in listOf(props.ahead) do
				if type(other) == "table" and type(other.warm) == "function" then
					other:warm()
				end
			end
		end)
		local triggers: { Instance } = {}
		for _, item in listOf(props.trigger) do
			local instance = if typeof(item) == "Instance" then item else item.Instance
			if instance then
				table.insert(triggers, instance)
			end
		end
		if #triggers == 0 then
			return
		end
		local connections: { RBXScriptConnection } = {}
		for _, instance in triggers do
			if instance:IsA("GuiObject") then
				table.insert(
					connections,
					(instance :: GuiObject).MouseEnter:Connect(function()
						handle:warm()
					end)
				)
			end
		end
		Reactive.onCleanup(function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end)
		-- Keyboard and gamepad focus, Lucy's own (the engine's selection included)
		local focused = handle.app.input:focusRef()
		Reactive.watch(focused, function(object: GuiObject?)
			if not object then
				return
			end
			for _, instance in triggers do
				if object == instance or object:IsDescendantOf(instance) then
					handle:warm()
					return
				end
			end
		end)
	end)
end

-- Builds a component that is open from the start. Call it once the handle is finished.
function Part.start(self: Part, open: Reactive.Ref<boolean>)
	if Reactive.peek(open) then
		buildOrClose(self, open)
	end
end

return Deferred
