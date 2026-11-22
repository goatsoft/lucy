--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local useBackHandler = require(script.Parent.useBackHandler)
local useWhile = require(script.Parent.useWhile)
local requireOwner = require(script.Parent.requireOwner)

--[[
	A focus zone (ADR 0045): a group of controls on a screen that nothing selects until the
	player steps in with a key, such as a HUD card or a column of buttons beside the play area
	where the left stick has to keep walking the character. With nothing selected, a key in
	`options.keys` steps in: focus lands on the zone's first or last control (reading order),
	the D-pad and keys stay inside it (a focus scope, and the zone a SelectionGroup that stops
	at its edges; with `trap = false` the D-pad moves on past its edges instead), and B steps
	back out, leaving nothing selected. Focus going anywhere else
	(a click, a panel opening, the zone hiding) leaves it too.

		local zone = Lucy.useFocusZone(app, card, {
			name = "hudCard",                                  -- unique in the app (its action set)
			keys = { [Enum.KeyCode.DPadUp] = "first" },        -- "first" | "last" | (list) -> GuiObject?
			enabled = function() return not onStage() end,     -- when stepping in is allowed
			trap = true,                                       -- false: the D-pad can leave at its edges
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

local function useFocusZone(
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
	useWhile(function()
		local allowed = if options.enabled == nil then true else Reactive.toValue(options.enabled)
		return not (allowed and selected() == nil and not app:modalOpen() and Reactive.toValue(root) ~= nil)
	end, function()
		return app.actions:disable(set)
	end)

	-- Inside: a focus scope on the zone (Tab and arrows stay in it; it lands on `target`), the
	-- zone a SelectionGroup stopping at its edges (the D-pad), nothing selected after. With
	-- trap = false, none of that: focus lands on `target` and the D-pad moves on from the zone's
	-- edges to whatever is next to it, which leaves the zone
	local trap = options.trap ~= false
	Reactive.watchEffect(function(onCleanup)
		if not entered() then
			return
		end
		local zone = zoneNow()
		if not zone then
			entered(false)
			return
		end
		if not trap then
			if Reactive.untrack(selected) ~= target and target then
				app.input:focus(target)
			end
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
	useBackHandler(app, inside, function()
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

return useFocusZone
