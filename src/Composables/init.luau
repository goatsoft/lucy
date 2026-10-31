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
			Lucy.useWhile(open, function() return signal:Connect(onFire) end)  -- only while open
			local timer = Lucy.useCountdown(endsAt)              -- timer.remaining(), timer.done()
			...
		end

	Write your own the same way: take refs or getters, return refs or computeds,
	and register any cleanup with Lucy.onCleanup.
]]

local Component = require(script.Parent.Core.Component)
local Reactive = require(script.Parent.Core.Reactive)
local Responsive = require(script.Parent.Core.Responsive)
local TableModel = require(script.Parent.Core.TableModel)
local UiEvents = require(script.Parent.Core.UiEvents)

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

-- A control size token (ControlSm, ControlMd, ControlLg, ControlIcon) in pixels.
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

-- Puts `handler` on the back stack (Escape / ButtonB) while `active` is true.
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
function Composables.useTable(options: { [string]: any })
	requireOwner("useTable")
	return TableModel.new(options)
end

--[[
	Runs `setup` each time `condition` (a ref, getter or value) turns true, and
	cleans up what it made when it turns false or the owner stops. `setup` may
	return a cleanup function or an RBXScriptConnection, and may call onCleanup or
	make effects of its own. Its reads are not tracked, so only `condition` reruns
	it.

		Lucy.useWhile(function() return app:modalOpen() end, function()
			return app.actions:disable("gameplay", "movement")
		end)
]]
function Composables.useWhile(condition: Reactive.MaybeRef<boolean>, setup: () -> any)
	requireOwner("useWhile")
	Reactive.watchEffect(function(onCleanup)
		if not Reactive.toValue(condition) then
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

return Composables
