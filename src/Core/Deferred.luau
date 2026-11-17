--!strict
--[[
	Deferred: content a component builds the first time it shows, not when it is made
	(ADR 0049). Shared by Tabs, and by every component that opens and closes.

		local deferred, keep = Deferred.mode(props, "Tabs") -- reads and checks `mount` and `keep`

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

	The content has a scope of its own under the component's, so it lives until it is removed
	or the component is destroyed, whatever asked for the build. Removing destroys what the
	slots did not hold before the build, so a slot's own layout and padding stay.

	Every part is listed in `handle._deferred`, where Devtools reads what is not built yet.
]]

local Component = require(script.Parent.Component)
local Reactive = require(script.Parent.Reactive)

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
	_scope: Reactive.Scope?,
	_before: { [Instance]: boolean }?,
	_building: boolean,
}
export type Part = typeof(setmetatable({} :: PartFields, Part))

--[[
	`mount` and `keep` as a component's props give them: whether its content is built on
	first show ("open", the default) or at once ("now"), and whether it is kept after.
	`keep` with mount = "now" is an error: that content is always kept.
]]
function Deferred.mode(props: { [string]: any }, what: string): (boolean, boolean)
	local mount = props.mount
	if mount == nil then
		mount = "open"
	end
	if mount ~= "open" and mount ~= "now" then
		error(`[Lucy] {what}: mount is "open" or "now", not "{tostring(mount)}"`, 0)
	end
	local keep = props.keep
	if keep ~= nil then
		if type(keep) ~= "boolean" then
			error(`[Lucy] {what}: keep is true or false, not "{tostring(keep)}"`, 0)
		end
		if mount == "now" then
			error(
				`[Lucy] {what}: keep goes with mount = "open"; with mount = "now" the content is always kept`,
				0
			)
		end
	end
	return mount == "open", keep ~= false
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

-- Builds a component that is open from the start. Call it once the handle is finished.
function Part.start(self: Part, open: Reactive.Ref<boolean>)
	if Reactive.peek(open) then
		buildOrClose(self, open)
	end
end

return Deferred
