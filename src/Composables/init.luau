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

-- A control size token (ControlSm, ControlMd, ControlLg, ControlIcon) in pixels.
function Composables.useMetric(app: any, token: string): Reactive.Computed<number>
	requireOwner("useMetric")
	local density = Composables.useDensity(app)
	return Reactive.computed(function()
		density()
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

return Composables
