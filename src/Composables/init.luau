--!strict
--[[
	Composables (ADR 0018): plain functions that create reactive state inside the
	current owner (a component's render, an effect, an effectScope) and return it.
	Everything they create stops with that owner. Called with no owner they error,
	since nothing would ever stop them.

		render = function(h)
			local density = Lucy.useDensity(h.app)               -- "default" | "touch" | "tv"
			local height = Lucy.useMetric(h.app, "ControlMd")     -- pixels, follows density
			Lucy.useBackHandler(h.app, open, function() h:close() return true end)
			Lucy.useFocusScope(h.app, open, { root = content })
			Lucy.useUiSound(h.app, { activate = playClick })     -- the game's own sounds
			local gap = Lucy.useResponsive(h.app, { touch = 16, default = 8 })
			local board = Lucy.useTable({ data = players, columns = columns })
			local dances = Lucy.useSort({ data = list, columns = columns, multi = true })  -- dances.items()
			Lucy.useWhile(open, function() return signal:Connect(onFire) end)  -- only while open
			local timer = Lucy.useCountdown(endsAt)              -- timer.remaining(), timer.done()
			local drag = Lucy.useDrag(handle, { onMove = move })  -- drag.dragging(), drag.delta()
			local typed = Lucy.useReveal(line, { rate = 34 })    -- typed.visible(): characters shown
			local xp = Lucy.useCount(xpRef, { seconds = 0.8 })   -- xp.value(): counting up to it
			local board = Lucy.useRequest(h.app, "boards.get", args) -- board.data(), board.loading()
			...
		end

	Write your own the same way: take refs or getters, return refs or computeds,
	and register any cleanup with Lucy.onCleanup.
]]

local Animate = require(script.Parent.Core.Animate)
local Component = require(script.Parent.Core.Component)
local Reactive = require(script.Parent.Core.Reactive)
local Responsive = require(script.Parent.Core.Responsive)
local Signal = require(script.Parent.Core.Signal)
local SortModel = require(script.Parent.Core.SortModel)
local TableModel = require(script.Parent.Core.TableModel)
local UiEvents = require(script.Parent.Core.UiEvents)

local UserInputService = game:GetService("UserInputService")

local Composables = {}

local function requireOwner(name: string)
	if not Reactive._hasOwner() then
		error(`[Lucy] {name} needs an owner: call it in a component's render, an effect or an effectScope`, 3)
	end
end

--[[
	The theme's density as a read-only ref. Follows the theme itself (not the
	store key), so anything read alongside it, such as tokens, is already updated.
	One per app, shared by every caller and stopped with the app: a component
	asking for it costs nothing.
]]
function Composables.useDensity(app: any): Reactive.Computed<string>
	requireOwner("useDensity")
	local shared = app._lucyDensity
	if shared then
		return shared
	end
	local density = Reactive.ref(app.theme:getDensity())
	app.maid:give(app.theme.DensityChanged:Connect(function(name: string)
		density(name)
	end))
	local function read(): string
		return density()
	end
	app._lucyDensity = read
	return read
end

-- Bumped when control heights change without a density change (text size).
local function metricsVersion(app: any): () -> number
	local shared = app._lucyMetrics
	if shared then
		return shared
	end
	local count = 0
	local version = Reactive.ref(count)
	app.maid:give(app.theme.MetricsChanged:Connect(function()
		count += 1
		version(count)
	end))
	local function read(): number
		return version()
	end
	app._lucyMetrics = read
	return read
end

-- A control size token (ControlSm, ControlMd, ControlLg, ControlXl, ControlIcon) in pixels.
-- Follows the density and the player's text size.
function Composables.useMetric(app: any, token: string): Reactive.Computed<number>
	requireOwner("useMetric")
	local density = Composables.useDensity(app)
	local metrics = metricsVersion(app)
	return Reactive.computed(function()
		density()
		metrics()
		return Component.metric(app, token)
	end)
end

--[[
	A responsive value ({ touch = 16, default = 8 }, see Responsive) resolved
	against the app's input state, as a getter that follows it. A plain value is
	returned as a getter too, so callers bind either the same way. A getter (or a
	ref) is followed as it is: a layout that depends on the game's own state.
]]
function Composables.useResponsive(app: any, value: any): () -> any
	requireOwner("useResponsive")
	if type(value) == "function" then
		return value
	end
	if not Responsive.isResponsive(value) then
		return function(): any
			return value
		end
	end
	local state = app.state
	local segments = state:_segments("input")
	return Reactive.computed(function(): any
		return Responsive.pick(state:_tracked(segments) or {}, value)
	end)
end

-- Puts `handler` on the back stack (the back keys) while `active` is true.
-- The handler returns true when it consumed the back press.
function Composables.useBackHandler(app: any, active: Reactive.MaybeRef<boolean>, handler: () -> boolean?)
	requireOwner("useBackHandler")
	Reactive.watchEffect(function(onCleanup)
		if Reactive.toValue(active) then
			onCleanup(Reactive._untracked(app.input.pushBack, app.input, handler))
		end
	end)
end

-- Keeps keyboard and gamepad focus inside `options.root` while `active` is true
-- (an InputManager focus scope: { root, defaultFocus }).
function Composables.useFocusScope(app: any, active: Reactive.MaybeRef<boolean>, options: { [string]: any })
	requireOwner("useFocusScope")
	Reactive.watchEffect(function(onCleanup)
		if Reactive.toValue(active) then
			onCleanup(Reactive._untracked(app.input.pushScope, app.input, options))
		end
	end)
end

--[[
	A focus zone (ADR 0045): a group of controls on a screen that nothing selects until the
	player steps in with a key, such as a HUD card or a column of buttons beside the play area
	where the left stick has to keep walking the character. With nothing selected, a key in
	`options.keys` steps in: focus lands on the zone's first or last control (reading order),
	the D-pad and keys stay inside it (a focus scope, and the zone a SelectionGroup that stops
	at its edges), and B steps back out, leaving nothing selected. Focus going anywhere else
	(a click, a panel opening, the zone hiding) leaves it too.

		local zone = Lucy.useFocusZone(app, card, {
			name = "hudCard",                                  -- unique in the app (its action set)
			keys = { [Enum.KeyCode.DPadUp] = "first" },        -- "first" | "last" | (list) -> GuiObject?
			enabled = function() return not onStage() end,     -- when stepping in is allowed
		})
		zone.inside()   -- tracked: focus is in the zone
		zone.enter("first")  zone.leave()

	root is a GuiObject, a ref or a getter. The keys are an action set ("zone:<name>", sinking)
	on only while stepping in is allowed: `enabled` is true, nothing is selected and no modal
	is open; otherwise the keys reach whatever else uses them.
]]
export type FocusZone = {
	inside: () -> boolean,
	enter: (where: any?) -> (),
	leave: () -> (),
}

local EDGES =
	{ "SelectionBehaviorUp", "SelectionBehaviorDown", "SelectionBehaviorLeft", "SelectionBehaviorRight" }

function Composables.useFocusZone(
	app: any,
	root: Reactive.MaybeRef<GuiObject?>,
	options: { [string]: any }
): FocusZone
	requireOwner("useFocusZone")
	local name = options.name
	if type(name) ~= "string" or name == "" then
		error("[Lucy] useFocusZone: options.name is required (unique in the app)", 2)
	end
	local set = `zone:{name}`
	local actions: { [string]: { Enum.KeyCode } } = {}
	local landing: { [string]: any } = {}
	for key, where in options.keys or {} do
		local action = `{set}:{key.Name}`
		actions[action] = { key }
		landing[action] = where
	end
	app.actions:define(set, actions, { priority = options.priority, sink = true })

	local selected = app.input:focusRef()
	local entered = Reactive.ref(false)
	local target: GuiObject? = nil

	local function zoneNow(): GuiObject?
		return Reactive.untrack(function()
			return Reactive.toValue(root)
		end)
	end

	local inside = Reactive.computed(function(): boolean
		local object = selected()
		local zone = Reactive.toValue(root)
		return object ~= nil and zone ~= nil and object:IsDescendantOf(zone)
	end)

	local function pick(where: any): GuiObject?
		local zone = zoneNow()
		if not zone then
			return nil
		end
		local list = app.input:selectables(zone)
		if type(where) == "function" then
			return where(list)
		end
		return if where == "last" then list[#list] else list[1]
	end

	local function enter(where: any?)
		local first = pick(where or "first")
		if not first then
			return
		end
		target = first
		if Reactive.peek(entered) then
			app.input:focus(first)
		else
			entered(true)
		end
	end

	local function leave()
		entered(false)
	end

	for action, where in landing do
		app.actions:on(action, function()
			enter(where)
		end)
	end

	-- The keys step in only while it is allowed and nothing has focus
	Composables.useWhile(function()
		local allowed = if options.enabled == nil then true else Reactive.toValue(options.enabled)
		return not (allowed and selected() == nil and not app:modalOpen() and Reactive.toValue(root) ~= nil)
	end, function()
		return app.actions:disable(set)
	end)

	-- Inside: a focus scope on the zone (Tab and arrows stay in it; it lands on `target`), the
	-- zone a SelectionGroup stopping at its edges (the D-pad), nothing selected after
	Reactive.watchEffect(function(onCleanup)
		if not entered() then
			return
		end
		local zone = zoneNow()
		if not zone then
			entered(false)
			return
		end
		local before = { group = zone.SelectionGroup }
		zone.SelectionGroup = true
		for _, edge in EDGES do
			before[edge] = (zone :: any)[edge];
			(zone :: any)[edge] = Enum.SelectionBehavior.Stop
		end
		local pop = Reactive.untrack(function()
			return app.input:pushScope({
				root = zone,
				defaultFocus = function()
					return target
				end,
				returnFocus = false,
			})
		end)
		-- The scope selects only while navigating; stepping in always does
		if Reactive.untrack(selected) ~= target and target then
			app.input:focus(target)
		end
		onCleanup(function()
			pop()
			if zone.Parent then
				zone.SelectionGroup = before.group
				for _, edge in EDGES do
					(zone :: any)[edge] = before[edge]
				end
			end
		end)
	end)

	-- Focus gone from the zone (a click elsewhere, a panel, the zone hidden): out
	local wasInside = false
	Reactive.watchEffect(function()
		local now = inside()
		if now then
			wasInside = true
		elseif wasInside then
			wasInside = false
			if Reactive.peek(entered) then
				entered(false)
			end
		end
	end)

	-- B steps out
	Composables.useBackHandler(app, inside, function()
		leave()
		if Reactive.untrack(inside) then
			app.input:focus(nil)
		end
		return true
	end)

	return {
		inside = function(): boolean
			return inside()
		end,
		enter = enter,
		leave = leave,
	}
end

--[[
	Holds the gamepad's selection on `target` while `active` is true, so the D-pad and the left
	stick reach its nudge (InputManager.nudge) instead of moving the selection away: a grabbed
	clip the arrows slide, a value being changed. While active, each of target's
	NextSelection* points at target itself (the engine keeps the selection where it is; a
	SelectionBehavior of Stop holds only at a SelectionGroup's edge); after, they are cleared.

		Lucy.useHoldArrows(clip, grabbed)    -- target: a GuiObject, ref or getter

	Games call this rather than setting NextSelection* themselves.
]]
local ARROW_LINKS = { "NextSelectionLeft", "NextSelectionRight", "NextSelectionUp", "NextSelectionDown" }

function Composables.useHoldArrows(target: Reactive.MaybeRef<GuiObject?>, active: Reactive.MaybeRef<boolean>)
	requireOwner("useHoldArrows")
	Reactive.watchEffect(function(onCleanup)
		local gui: GuiObject? = Reactive.toValue(target) :: any
		if not gui or not Reactive.toValue(active) then
			return
		end
		for _, link in ARROW_LINKS do
			(gui :: any)[link] = gui
		end
		onCleanup(function()
			for _, link in ARROW_LINKS do
				if (gui :: any)[link] == gui then
					(gui :: any)[link] = nil
				end
			end
		end)
	end)
end

--[[
	Maps the moments components report (activate, toggle, select, open, close) to
	the game's own functions, for components made inside this owner. Lucy plays no
	audio. The closest map that names an event wins and `false` silences it; a map
	in a top-level scope also covers components made with no owner. Stops with its
	owner. Each function gets (handle, value): toggle passes the new checked state,
	select the picked value.
]]
function Composables.useUiSound(app: any, map: UiEvents.Map)
	requireOwner("useUiSound")
	UiEvents.listen(app, map)
end

--[[
	Sorted rows from data and column definitions, for tables and anything list
	shaped (ADR 0025). Returns { rows, sorting, toggle, sortedBy, canSort,
	setSorting, columns }; see Core/TableModel for the options. Its computeds
	belong to the owner.
]]
--[[
	Any list, sorted by one column or several (Core/SortModel has the options):
	data (an array, a ref or a getter), columns, sorting, multi, sortable,
	removable, descFirst. Returns the sort model (sorting, list, toggle,
	sortedBy, priority, canSort, setSorting, columns, sort) and items, a
	computed of the data in order. With multi, a press on a new column adds it
	as the next tiebreaker. Its computed belongs to the owner.

		local dances = Lucy.useSort({
			data = owned,
			columns = { { key = "name" }, { key = "genre" }, { id = "rarity", get = rank, descFirst = true } },
			sorting = { { id = "rarity", desc = true } },
			multi = true,
		})
		Lucy.each(dances.items, tile)
]]
function Composables.useSort(options: { [string]: any })
	requireOwner("useSort")
	local model: any = SortModel.new(options)
	model.items = Reactive.computed(function(): { any }
		return model.sort(Reactive.toValue(options.data) or {})
	end)
	return model
end

function Composables.useTable(options: { [string]: any })
	requireOwner("useTable")
	return TableModel.new(options)
end

--[[
	Runs `setup` each time `condition` (a ref, getter or value) turns true, and
	cleans up what it made when it turns false or the owner stops. `setup` may
	return a cleanup function or an RBXScriptConnection, and may call onCleanup or
	make effects of its own. Its reads are not tracked, and a getter that reads
	something new but stays true does not restart it: only `condition` turning
	true or false does.

		Lucy.useWhile(function() return app:modalOpen() end, function()
			return app.actions:disable("gameplay", "movement")
		end)
]]
function Composables.useWhile(condition: Reactive.MaybeRef<boolean>, setup: () -> any)
	requireOwner("useWhile")
	-- A boolean the effect follows, so only a flip reruns it
	local active = Reactive.computed(function(): boolean
		return Reactive.toValue(condition) and true or false
	end)
	Reactive.watchEffect(function(onCleanup)
		if not active() then
			return
		end
		local scope = Reactive.effectScope(true)
		local result = Reactive.untrack(function()
			return scope:run(setup)
		end)
		if result ~= nil and type(result) ~= "function" and typeof(result) ~= "RBXScriptConnection" then
			scope:stop()
			error("[Lucy] useWhile: setup returns a cleanup function, a connection or nothing", 0)
		end
		onCleanup(function()
			scope:stop()
			if type(result) == "function" then
				result()
			elseif typeof(result) == "RBXScriptConnection" then
				result:Disconnect()
			end
		end)
	end)
end

--[[
	Whole seconds left until `endsAt` (a number, ref or getter in
	workspace:GetServerTimeNow() time, so every player sees the same count). Returns
	{ remaining, done }: `remaining` never goes below 0 and ticks once a second, on
	the second; `done` is true once it reaches 0. With no end time, remaining is 0
	and done is false. Follows `endsAt` when it changes. options.now replaces the
	clock (tests).
]]
function Composables.useCountdown(
	endsAt: Reactive.MaybeRef<number?>,
	options: { now: (() -> number)? }?
): { remaining: Reactive.Computed<number>, done: Reactive.Computed<boolean> }
	requireOwner("useCountdown")
	local now: () -> number = (options and options.now)
		or function()
			return workspace:GetServerTimeNow()
		end
	local left = Reactive.ref(0)
	local ended = Reactive.ref(false)
	Reactive.watchEffect(function(onCleanup)
		local target: number? = Reactive.toValue(endsAt) :: any
		local thread: thread? = nil
		local function update()
			thread = nil
			if target == nil then
				Reactive.batch(function()
					left(0)
					ended(false)
				end)
				return
			end
			local seconds = target - now()
			local whole = math.max(math.ceil(seconds), 0)
			Reactive.batch(function()
				left(whole)
				ended(whole == 0)
			end)
			if whole > 0 then
				-- Until the count drops by one.
				thread = task.delay(seconds - (whole - 1), update)
			end
		end
		Reactive.untrack(update)
		onCleanup(function()
			if thread then
				task.cancel(thread)
				thread = nil
			end
		end)
	end)
	return {
		remaining = Reactive.computed(function()
			return left()
		end),
		done = Reactive.computed(function()
			return ended()
		end),
	}
end

export type DragOptions = {
	onStart: ((point: Vector2) -> ())?,
	onMove: ((delta: Vector2, point: Vector2) -> ())?,
	onEnd: ((delta: Vector2) -> ())?,
	disabled: Reactive.MaybeRef<boolean>?,
	-- tests: the press signal (instead of target.InputBegan) and the input service
	began: RBXScriptSignal?,
	input: any?,
}

export type Drag = {
	dragging: Reactive.Computed<boolean>,
	delta: Reactive.Computed<Vector2>,
	cancel: () -> (),
}

local function pointOf(input: any): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

--[[
	Follows the mouse or a finger dragging from `target` (a GuiObject, or a ref or
	getter for one, such as h:ref), in screen pixels. A press on the target starts
	it; moving anywhere on the screen moves it; letting go ends it. Returns
	{ dragging, delta, cancel }: `delta` is how far it has moved since the press,
	back to zero after. options: onStart(point), onMove(delta, point), onEnd(delta),
	disabled (a ref or getter: no new drags, and turning it on ends one). Stopping
	the owner ends a drag too, calling onEnd.

	A gamepad has no pointer: give console players a stick or buttons for the same
	thing.
]]
function Composables.useDrag(target: Reactive.MaybeRef<GuiObject?>, options: DragOptions?): Drag
	requireOwner("useDrag")
	local opts: DragOptions = options or {}
	local input: any = opts.input or UserInputService
	local dragging = Reactive.ref(false)
	local delta = Reactive.ref(Vector2.zero)
	local origin = Vector2.zero
	local connections: { RBXScriptConnection } = {}

	local function stopListening()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function finish()
		stopListening()
		if not Reactive.peek(dragging) then
			return
		end
		local moved: Vector2 = Reactive.peek(delta :: any)
		Reactive.batch(function()
			dragging(false)
			delta(Vector2.zero)
		end)
		if opts.onEnd then
			opts.onEnd(moved)
		end
	end

	local function start(pressed: any)
		local kind = pressed.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if Reactive.untrack(function()
			return Reactive.toValue(opts.disabled)
		end) then
			return
		end
		finish()
		origin = pointOf(pressed)
		dragging(true)
		if opts.onStart then
			opts.onStart(origin)
		end
		table.insert(
			connections,
			input.InputChanged:Connect(function(changed: any)
				local moved = if kind == Enum.UserInputType.Touch
					then changed == pressed
					else changed.UserInputType == Enum.UserInputType.MouseMovement
				if moved then
					local point = pointOf(changed)
					delta(point - origin)
					if opts.onMove then
						opts.onMove(point - origin, point)
					end
				end
			end)
		)
		table.insert(
			connections,
			input.InputEnded:Connect(function(ended: any)
				local released = if kind == Enum.UserInputType.Touch
					then ended == pressed
					else ended.UserInputType == Enum.UserInputType.MouseButton1
				if released then
					finish()
				end
			end)
		)
	end

	-- Presses on the target, while there is one
	Reactive.watchEffect(function(onCleanup)
		local signal: RBXScriptSignal? = opts.began
		if not signal then
			local gui: GuiObject? = Reactive.toValue(target) :: any
			signal = if gui then gui.InputBegan else nil
		end
		if not signal then
			return
		end
		local connection = signal:Connect(start)
		onCleanup(function()
			connection:Disconnect()
		end)
	end)
	-- Turning disabled on ends a drag
	Reactive.watchEffect(function()
		if Reactive.toValue(opts.disabled) then
			Reactive.untrack(finish)
		end
	end)
	Reactive.onCleanup(finish)

	return {
		dragging = Reactive.computed(function()
			return dragging()
		end),
		delta = Reactive.computed(function()
			return delta()
		end),
		cancel = finish,
	}
end

-- How many characters a reader sees: rich text tags take none, an entity takes one
local ENTITIES = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }
local function visibleLength(text: string, rich: boolean): number
	if rich then
		text = text:gsub("<[^>]*>", ""):gsub("&(%a+);", function(name)
			return ENTITIES[name]
		end)
	end
	return utf8.len(text) or #text
end

export type Reveal = {
	visible: Reactive.Computed<number>,
	revealing: Reactive.Computed<boolean>,
	skip: () -> (),
	done: Signal.Signal,
}

--[[
	Types a text out: how many of its characters to show, rising at `rate` a second
	(default 40), from none each time the text changes. Bind `visible` to a
	TextLabel's MaxVisibleGraphemes: the whole text is laid out from the start, so
	words never jump to the next line as they appear. Returns { visible, revealing,
	skip, done }: `visible` is -1 once it is all out; `skip()` shows the rest at
	once; `done` (a Signal) fires each time a text is all out. options.rich: the
	text has rich text tags, which take no time. Runs on Animate's driver.
]]
function Composables.useReveal(
	text: Reactive.MaybeRef<string>,
	options: { rate: number?, rich: boolean? }?
): Reveal
	requireOwner("useReveal")
	local rate = math.max((options and options.rate) or 40, 1)
	local rich = options ~= nil and options.rich == true
	local shown = Reactive.ref(-1)
	local typing = Reactive.ref(false)
	local done = Signal.new()
	local stopDrive: (() -> ())? = nil
	local function halt()
		if stopDrive then
			stopDrive()
			stopDrive = nil
		end
	end
	local function finish()
		halt()
		shown(-1)
		if Reactive.peek(typing) then
			typing(false)
			done:Fire()
		end
	end
	Reactive.watch(function()
		return Reactive.toValue(text)
	end, function(value)
		halt()
		local total = visibleLength(tostring(value or ""), rich)
		if total == 0 then
			shown(-1)
			typing(false)
			return
		end
		local elapsed = 0
		shown(0)
		typing(true)
		stopDrive = Animate.drive(function(dt: number): boolean
			elapsed += dt
			local count = math.floor(elapsed * rate + 1e-6)
			if count >= total then
				stopDrive = nil
				finish()
				return true
			end
			shown(count)
			return false
		end)
	end, { immediate = true })
	Reactive.onCleanup(function()
		halt()
		done:DisconnectAll()
	end)
	return {
		visible = Reactive.computed(function()
			return shown()
		end),
		revealing = Reactive.computed(function()
			return typing()
		end),
		skip = finish,
		done = done,
	}
end

export type Count = {
	value: Reactive.Computed<number>,
	counting: Reactive.Computed<boolean>,
	skip: () -> (),
	done: Signal.Signal,
}

--[[
	Counts a number up (or down) to `value`: from `options.from` (default 0) at first,
	and from where it is whenever `value` changes, over `options.seconds` (default 0.8),
	easing out as it lands. Returns { value, counting, skip, done }: `value` is the
	number now (not rounded: round or format it to show it, Lucy.Format.number);
	`skip()` lands it at once; `done` (a Signal) fires each time it lands. Runs on
	Animate's driver.
]]
function Composables.useCount(
	value: Reactive.MaybeRef<number>,
	options: { seconds: number?, from: number? }?
): Count
	requireOwner("useCount")
	local seconds = math.max((options and options.seconds) or 0.8, 0)
	local shown = Reactive.ref((options and options.from) or 0)
	local moving = Reactive.ref(false)
	local done = Signal.new()
	local goal: number = Reactive.peek(shown :: any)
	local stopDrive: (() -> ())? = nil
	local function halt()
		if stopDrive then
			stopDrive()
			stopDrive = nil
		end
	end
	local function land()
		halt()
		shown(goal)
		if Reactive.peek(moving) then
			moving(false)
			done:Fire()
		end
	end
	Reactive.watch(function()
		return tonumber(Reactive.toValue(value)) or 0
	end, function(target)
		halt()
		goal = target
		local from: number = Reactive.peek(shown :: any)
		if from == goal or seconds <= 0 then
			shown(goal)
			moving(false)
			return
		end
		local elapsed = 0
		moving(true)
		stopDrive = Animate.drive(function(dt: number): boolean
			elapsed += dt
			local k = elapsed / seconds
			if k >= 1 then
				stopDrive = nil
				land()
				return true
			end
			shown(from + (goal - from) * (1 - (1 - k) ^ 3))
			return false
		end)
	end, { immediate = true })
	Reactive.onCleanup(function()
		halt()
		done:DisconnectAll()
	end)
	return {
		value = Reactive.computed(function()
			return shown()
		end),
		counting = Reactive.computed(function()
			return moving()
		end),
		skip = land,
		done = done,
	}
end

--[[
	Asks the server with app.server:call and keeps the answer as state, for a panel that
	shows what the server knows: a leaderboard, a shop's stock, a friend's profile.
	Returns { data, loading, error, refresh }.

		local board = Lucy.useRequest(app, "boards.get", function()
			return tab(), period()          -- read reactively: a new tab asks again
		end, { enabled = open, every = 30 })
		board.data()      -- the handler's answer, nil until the first one
		board.loading()   -- true while a call is out
		board.error()     -- the last call's error message, nil once one succeeds
		board.refresh()   -- ask again now, keeping the answer it has meanwhile

	`args` is a getter returning the call's arguments, a list of them, or nil for none.
	When the getter's reads change it asks again; data clears straight away, so a new tab
	never shows the old tab's rows, unless options.keep. Only the newest call's answer
	lands: one that comes late, after the arguments moved on or the owner stopped, is
	dropped. An error keeps the data it had.

	options:
		enabled  a boolean, ref or getter: no calls while false (a closed dialog)
		every    seconds: asks again this often while enabled, keeping the data
		keep     true to keep the last answer while the next arguments load
]]
type RequestOptions = { enabled: Reactive.MaybeRef<boolean>?, every: number?, keep: boolean? }

function Composables.useRequest(
	app: any,
	name: string,
	args: any?,
	options: RequestOptions?
): {
	data: Reactive.Computed<any>,
	loading: Reactive.Computed<boolean>,
	error: Reactive.Computed<string?>,
	refresh: () -> (),
}
	requireOwner("useRequest")
	local opts: RequestOptions = options or {}
	local answer = Reactive.ref(nil :: any)
	local busy = Reactive.ref(false)
	local failed = Reactive.ref(nil :: string?)
	-- Each call takes the next number; only the newest one's answer lands
	local latest = 0
	local stopped = false
	local current: { n: number, [number]: any }? = nil

	local function ask(pack: { n: number, [number]: any }, clear: boolean)
		latest += 1
		local mine = latest
		Reactive.batch(function()
			if clear then
				answer(nil)
			end
			busy(true)
		end)
		task.spawn(function()
			local ok, result = pcall(function()
				return app.server:call(name, table.unpack(pack, 1, pack.n))
			end)
			if stopped or mine ~= latest then
				return
			end
			Reactive.batch(function()
				busy(false)
				if ok then
					answer(result)
					failed(nil)
				else
					failed(tostring(result))
				end
			end)
		end)
	end

	local function argsNow(): { n: number, [number]: any }
		if type(args) == "function" then
			return table.pack(args())
		elseif type(args) == "table" then
			return table.pack(table.unpack(args))
		end
		return { n = 0 }
	end

	Reactive.watchEffect(function(onCleanup)
		local enabled = opts.enabled == nil or Reactive.toValue(opts.enabled) == true
		local pack = argsNow()
		if not enabled then
			current = nil
			latest += 1 -- a call still out no longer lands
			Reactive.untrack(busy, false)
			return
		end
		current = pack
		Reactive.untrack(ask, pack, not opts.keep)
		if opts.every then
			local every = opts.every
			local thread = task.spawn(function()
				while true do
					task.wait(every)
					if not Reactive.untrack(busy) then
						Reactive.untrack(ask, pack, false)
					end
				end
			end)
			onCleanup(function()
				task.cancel(thread)
			end)
		end
	end)
	Reactive.onCleanup(function()
		stopped = true
	end)

	return {
		data = Reactive.computed(function()
			return answer()
		end),
		loading = Reactive.computed(function()
			return busy()
		end),
		error = Reactive.computed(function()
			return failed()
		end),
		refresh = function()
			if current and not stopped then
				ask(current, false)
			end
		end,
	}
end

return Composables
