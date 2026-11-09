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
	returned as a getter too, so callers bind either the same way.
]]
function Composables.useResponsive(app: any, value: any): () -> any
	requireOwner("useResponsive")
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

return Composables
