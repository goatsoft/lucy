--!strict
--[[
	Devtools: look at a running Lucy UI from Studio, and act on it the way a
	player would (ADR 0027, 0028). Made for agents calling Studio's
	execute_luau, and for the command bar.

		local Devtools = require(ReplicatedStorage.Packages.Lucy).Devtools
		Devtools.apps()                      -- the running apps
		Devtools.tree()                      -- components, nested, with state
		Devtools.tree({ root = "shop" })     -- from one component down
		Devtools.state("player.coins")       -- the store, or one path
		Devtools.focus()                     -- what is focused, and the input mode
		Devtools.overlays()                  -- open dialogs, sheets and popups
		Devtools.actions()                   -- action sets, keys, on or off
		Devtools.press("buy")                -- click it
		Devtools.press("theme", "light")     -- pick a value in a group, tabs or select
		Devtools.set("player.coins", 500)    -- write app state
		Devtools.focus("buy")                -- move focus to it
		Devtools.preview("Button")           -- show a story (edit mode)

	Code run by an agent gets its own copy of Lucy, so it cannot see the game's
	App. In Studio every App makes a BindableFunction (its bridge, tagged
	LucyDevtools) and these functions call through it. The last argument is an
	options table; `options.app` picks an app by its namePrefix, or is an App
	itself (specs and stories). Left out, it is the only app, or the game's main
	one (made with setCurrent) when several run. Results are plain tables.
]]

local CollectionService = game:GetService("CollectionService")

local Reactive = require(script.Parent.Reactive)

local Devtools = {}

Devtools.tag = "LucyDevtools"

-- Seconds to wait for an app to answer. A bridge with no game behind it would
-- otherwise keep the caller waiting for ever.
Devtools.timeout = 3

-- The ui-* flag tags reported on each node.
local FLAGS = { "disabled", "checked", "selected", "open", "focused", "focus-visible" }

type Options = { [string]: any }?

--[[ Plain copies ]]

-- `value` as strings, numbers, booleans and tables of them: Instances become
-- their full name, other Roblox values their tostring, functions are dropped.
-- A table that is not a plain list gets string keys, so it survives the bridge.
local function plain(value: any, depth: number, seen: { [any]: boolean }): any
	local kind = typeof(value)
	if kind == "nil" or kind == "string" or kind == "number" or kind == "boolean" then
		return value
	end
	if kind == "Instance" then
		return value:GetFullName()
	end
	if kind == "EnumItem" then
		return value.Name
	end
	if kind == "function" then
		return nil
	end
	if kind ~= "table" then
		return tostring(value)
	end
	if seen[value] or depth <= 0 then
		return "..."
	end
	seen[value] = true
	local count = 0
	for _ in value do
		count += 1
	end
	local isList = count == #value
	local out = {}
	for key, item in value do
		local copy = plain(item, depth - 1, seen)
		if copy ~= nil then
			out[if isList then key else tostring(key)] = copy
		end
	end
	seen[value] = nil
	return out
end

function Devtools.plain(value: any): any
	return plain(value, 12, {})
end

--[[ What runs inside the game (through the bridge) ]]

local function isShown(object: Instance): boolean
	if not object:IsDescendantOf(game) then
		return false
	end
	local node: Instance? = object
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return true
end

-- The component an instance belongs to: its own handle or the nearest above.
local function owner(app: any, object: Instance?, skipSelf: boolean?): any
	local node = if skipSelf and object then object.Parent else object
	while node do
		local id = node:GetAttribute("LucyId")
		if type(id) == "string" then
			local handle = app:handle(id)
			if handle and handle.Instance == node then
				return handle
			end
		end
		node = node.Parent
	end
	return nil
end

-- The first text in a component that is its own, not a nested component's.
local function ownText(root: Instance): string?
	local queue = { root }
	local index = 1
	while queue[index] do
		local node = queue[index]
		index += 1
		if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
			local text = (node :: any).Text
			if text ~= "" then
				return text
			end
		end
		for _, child in node:GetChildren() do
			if child:GetAttribute("LucyId") == nil then
				table.insert(queue, child)
			end
		end
	end
	return nil
end

local function handleOf(app: any, id: any): any
	if type(id) ~= "string" then
		error("[Lucy] Devtools: give a component id (a string)", 0)
	end
	local handle = app:handle(id)
	if handle == nil or handle.destroyed then
		error(`[Lucy] Devtools: no component "{id}" (Devtools.tree() lists them)`, 0)
	end
	return handle
end

local function summary(handle: any): { [string]: any }?
	if handle == nil then
		return nil
	end
	return { id = handle.id, kind = handle.kind }
end

local function node(handle: any): { [string]: any }
	local instance: Instance = handle.Instance
	local flags = {}
	for _, flag in FLAGS do
		if instance:HasTag("ui-" .. flag) then
			table.insert(flags, flag)
		end
	end
	local out: { [string]: any } = {
		id = handle.id,
		kind = handle.kind,
		name = instance.Name,
		shown = isShown(instance),
		flags = flags,
		text = ownText(instance),
		state = plain(handle:get(), 8, {}),
		children = {},
	}
	if instance:IsA("GuiObject") then
		local size, position = instance.AbsoluteSize, instance.AbsolutePosition
		out.size = { math.round(size.X), math.round(size.Y) }
		out.position = { math.round(position.X), math.round(position.Y) }
	end
	local gui = instance:FindFirstAncestorWhichIsA("LayerCollector")
	if gui then
		out.gui = gui.Name
	end
	return out
end

-- Reading order: top to bottom, then left to right.
local function byPosition(a: { [string]: any }, b: { [string]: any }): boolean
	local pa, pb = a.position or { 0, 0 }, b.position or { 0, 0 }
	if pa[2] ~= pb[2] then
		return pa[2] < pb[2]
	end
	return pa[1] < pb[1]
end

local function tree(app: any, args: { [string]: any }): { any }
	local nodes: { [any]: { [string]: any } } = {}
	local parents: { [any]: any } = {}
	for _, handle in app._handles do
		if not handle.destroyed and handle.Instance then
			if args.shownOnly and not isShown(handle.Instance) then
				continue
			end
			nodes[handle] = node(handle)
			parents[handle] = owner(app, handle.Instance, true)
		end
	end
	local roots = {}
	for handle, entry in nodes do
		local parent = parents[handle]
		local parentNode = parent and nodes[parent]
		if parentNode then
			table.insert(parentNode.children, entry)
		else
			table.insert(roots, entry)
		end
	end
	for _, entry in nodes do
		table.sort(entry.children, byPosition)
	end
	if args.root then
		local start = nodes[handleOf(app, args.root)]
		return if start then { start } else {}
	end
	table.sort(roots, byPosition)
	return roots
end

local function focusInfo(app: any): { [string]: any }
	local input = app.input
	local focused = input:focused()
	local handle = focused and owner(app, focused)
	local info = summary(handle)
	if info and handle then
		-- The components it sits inside, innermost first.
		local within = {}
		local outer = owner(app, handle.Instance, true)
		while outer do
			table.insert(within, outer.id)
			outer = owner(app, outer.Instance, true)
		end
		info.within = within
	end
	return {
		mode = input:mode(),
		device = input:device(),
		navigating = input:isNavigating(),
		focused = info,
		object = if focused then focused:GetFullName() else nil,
	}
end

local function press(app: any, args: { [string]: any }): { [string]: any }
	local handle = handleOf(app, args.id)
	if handle:get("disabled") == true then
		return { ok = false, reason = `"{handle.id}" is disabled` }
	end
	local value = args.value
	local did: string
	if value ~= nil then
		if handle.select then
			handle:select(value)
			did = "select"
		elseif handle.setValue then
			handle:setValue(value)
			did = "setValue"
		elseif handle.toggle then
			handle:toggle(value)
			did = "toggle"
		else
			error(`[Lucy] Devtools: a {handle.kind} takes no value; press it without one`, 0)
		end
	elseif handle.click then
		handle:click()
		did = "click"
	elseif handle.toggle then
		handle:toggle()
		did = "toggle"
	else
		error(`[Lucy] Devtools: a {handle.kind} can't be pressed`, 0)
	end
	return {
		ok = true,
		did = did,
		state = if handle.destroyed then nil else plain(handle:get(), 8, {}),
	}
end

local function overlays(app: any): { [string]: any }
	local open = {}
	for _, entry in app._lucyOverlays or {} do
		local handle = app:handle(entry.id)
		table.insert(open, { id = entry.id, kind = handle and handle.kind, modal = entry.modal })
	end
	return { modalOpen = app:modalOpen(), open = open }
end

local function actions(app: any): { [string]: any }
	local sets = {}
	local manager = app.actions
	for name, set in manager._sets do
		sets[name] = {
			enabled = manager:enabled(name),
			priority = Reactive.peek(set.priority),
			actions = {},
		}
	end
	for name, entry in manager._entries do
		local set = sets[entry.set]
		if set then
			local keys = {}
			for _, code in Reactive.peek(entry.keys) :: any do
				table.insert(keys, code.Name)
			end
			set.actions[name] = keys
		end
	end
	return { sets = sets }
end

local SERVE: { [string]: (app: any, args: { [string]: any }) -> any } = {
	summary = function(app)
		local count = 0
		for _ in app._handles do
			count += 1
		end
		return {
			name = app.namePrefix,
			theme = app.theme:get(),
			density = app.theme:getDensity(),
			mode = app.input:mode(),
			device = app.input:device(),
			scene = app.state:get("scenes.current"),
			stack = plain(app.state:get("scenes.stack"), 4, {}),
			modalOpen = app:modalOpen(),
			components = count,
		}
	end,
	tree = tree,
	state = function(app, args)
		return plain(app.state:get(args.path), 12, {})
	end,
	set = function(app, args)
		app.state:set(args.path, args.value)
		return { ok = true }
	end,
	focus = function(app, args)
		if args.id ~= nil then
			local handle = handleOf(app, args.id)
			-- The component itself, or the first part of it a gamepad can land on.
			local object = app.input:_usable(handle) or app.input:selectables(handle.Instance)[1]
			if not object then
				error(
					`[Lucy] Devtools: "{handle.id}" can't take focus now (hidden, disabled or not selectable)`,
					0
				)
			end
			-- Focus is moved with keys or a gamepad, so switch to keys first and
			-- the focus ring shows, unless the player is navigating already.
			if not app.input:isNavigating() then
				app.input:setMode("keyboard")
			end
			app.input:focus(object)
		end
		return focusInfo(app)
	end,
	press = press,
	overlays = overlays,
	actions = actions,
}

-- Runs `method` against `app`. Called by the app's bridge, and directly when
-- an App is passed as options.app.
function Devtools._serve(app: any, method: string, args: { [string]: any }?): any
	local serve = SERVE[method]
	if not serve then
		error(`[Lucy] Devtools: unknown call "{tostring(method)}"`, 0)
	end
	return serve(app, args or {})
end

--[[ What the agent calls ]]

-- The bridges of the apps running now.
local function bridges(): { BindableFunction }
	local out = {}
	for _, bridge in CollectionService:GetTagged(Devtools.tag) do
		if bridge:IsA("BindableFunction") and bridge:IsDescendantOf(game) then
			table.insert(out, bridge)
		end
	end
	table.sort(out, function(a, b)
		return (a:GetAttribute("LucyApp") or "") < (b:GetAttribute("LucyApp") or "")
	end)
	return out
end

local function names(list: { BindableFunction }): string
	local out = {}
	for _, bridge in list do
		table.insert(out, `"{bridge:GetAttribute("LucyApp")}"`)
	end
	return table.concat(out, ", ")
end

-- Invokes a bridge, giving up after Devtools.timeout. Returns ok, result.
local function invoke(bridge: BindableFunction, method: string, args: { [string]: any }): (boolean, any)
	local done, ok, result = false, false, nil
	task.spawn(function()
		ok, result = pcall(bridge.Invoke, bridge, method, args)
		done = true
	end)
	local waited = 0
	while not done and waited < Devtools.timeout do
		waited += task.wait(0.05)
	end
	if not done then
		return false, `[Lucy] Devtools: app "{bridge:GetAttribute("LucyApp")}" did not answer`
	end
	return ok, result
end

local function answer(bridge: BindableFunction, method: string, args: { [string]: any }): any
	local ok, result = invoke(bridge, method, args)
	if not ok then
		error(result, 0)
	end
	return result
end

local function call(method: string, args: { [string]: any }, options: Options): any
	local target = options and options.app
	if type(target) == "table" then
		return Devtools._serve(target, method, args)
	end
	local list = bridges()
	if target ~= nil then
		for _, bridge in list do
			if bridge:GetAttribute("LucyApp") == target then
				return answer(bridge, method, args)
			end
		end
		error(`[Lucy] Devtools: no app named "{tostring(target)}" (running: {names(list)})`, 0)
	end
	if #list == 1 then
		return answer(list[1], method, args)
	end
	-- Several (a dev place with a test app, say): the game's main app, made
	-- with setCurrent, is the one meant.
	local current = {}
	for _, bridge in list do
		if bridge:GetAttribute("LucyCurrent") == true then
			table.insert(current, bridge)
		end
	end
	if #current == 1 then
		return answer(current[1], method, args)
	end
	if #list == 0 then
		error(
			"[Lucy] Devtools: no Lucy app is running here. Apps are reachable in Studio only:"
				.. " in Play, run this on the Client data model",
			0
		)
	end
	error(`[Lucy] Devtools: several apps run ({names(list)}); pass \{ app = name \}`, 0)
end

-- Every running app: its name (namePrefix), theme, input mode, scene and size.
function Devtools.apps(): { any }
	local out = {}
	for _, bridge in bridges() do
		local ok, info = invoke(bridge, "summary", {})
		if ok then
			table.insert(out, info)
		end
	end
	return out
end

-- The components as a tree in reading order. options.root starts from one
-- component; options.shownOnly leaves out hidden ones.
function Devtools.tree(options: Options): { any }
	local opts: { [string]: any } = options or {}
	return call("tree", { root = opts.root, shownOnly = opts.shownOnly }, options)
end

-- A plain copy of the store, or of one path in it.
function Devtools.state(path: string?, options: Options): any
	return call("state", { path = path }, options)
end

-- Writes app state, as game code would.
function Devtools.set(path: string, value: any, options: Options): { [string]: any }
	return call("set", { path = path, value = value }, options)
end

-- With an id, moves focus to that component (or the first part of it that can
-- take focus) and switches to keyboard navigation if the player was not
-- navigating. Returns what is focused, the components around it, and the
-- input mode.
function Devtools.focus(id: string?, options: Options): { [string]: any }
	return call("focus", { id = id }, options)
end

-- Clicks a component, or with a value picks it (groups, tabs, selects, radio
-- groups), sets it (sliders, number fields) or opens that section (accordions).
-- A disabled component is left alone and reports ok = false.
function Devtools.press(id: string, value: any?, options: Options): { [string]: any }
	return call("press", { id = id, value = value }, options)
end

-- Open dialogs, sheets and popups, oldest first, and whether one is modal.
function Devtools.overlays(options: Options): { [string]: any }
	return call("overlays", {}, options)
end

-- Action sets: on or off, and each action's keys.
function Devtools.actions(options: Options): { [string]: any }
	return call("actions", {}, options)
end

-- Shows a story in edit mode, as Lucy.Preview.show does, for a screenshot.
function Devtools.preview(story: any, options: { [string]: any }?): { [string]: any }
	local Preview = require(script.Parent.Preview) :: any
	local mounted = Preview.show(story, options)
	return { ok = mounted ~= nil, story = if type(story) == "string" then story else story.title }
end

return Devtools
