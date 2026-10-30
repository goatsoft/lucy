--!strict
--[[
	Actions (ADR 0026): named actions on keys and buttons, grouped in sets that are
	switched on and off together. Each set is a Roblox InputContext, each action an
	InputAction, each key an InputBinding; a game describes them in tables.

		app.actions:define("gameplay", {
			inventory = { Enum.KeyCode.I, Enum.KeyCode.ButtonL1 },
			shop = { Enum.KeyCode.B, Enum.KeyCode.DPadRight },
		}, { priority = 1000, sink = false })            -- the options are optional

		local stop = app.actions:on("inventory", function() inventory:toggle() end)

		app.actions:bind("inventory", { Enum.KeyCode.Tab, Enum.KeyCode.ButtonL1 })
		app.actions:bind({ inventory = { ... }, shop = { ... } })    -- several at once
		app.actions:keys("inventory")        -- its keys for the current input mode (tracked)

		local release = app.actions:disable("gameplay", "movement")  -- counted
		app.actions:enabled("gameplay")      -- tracked

	Action names are unique per app. Keys are KeyCodes; gamepad ones (Button*,
	DPad*, Thumbstick*) are told apart by name for keys(). Actions are buttons
	(pressed and released); sticks are not supported yet. Actions do not fire while
	a TextBox is focused (the engine does this). A handler made inside an owner
	(a component's render, an effect) stops with it.

	The built in "movement" set holds the keys the default character controls use.
	While it is disabled the character does not walk or jump. Change its keys with
	app.actions:bind("movement", keys). It has no handlers, and Lucy never disables
	it on its own.

	config (App.new({ actions = { ... } })):
		parent          where the actions folder goes (PlayerScripts on a client)
		controls        "new" | "old": which default controls the game runs (detected)
		contextActions  stands in for ContextActionService (tests)
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local Element = require(script.Parent.Element)
local Reactive = require(script.Parent.Reactive)

local Actions = {}
Actions.__index = Actions

-- InputContext priority for a game's sets: above the default controls (150) so a
-- game's action wins where both bind a key.
Actions.priority = 1000
-- The movement set: above the default controls and a game's sets, sinking.
Actions.movementPriority = 2000

local K = Enum.KeyCode
Actions.movementKeys = table.freeze({
	K.W,
	K.A,
	K.S,
	K.D,
	K.Up,
	K.Down,
	K.Left,
	K.Right,
	K.Space,
	K.Thumbstick1,
})

local MOVEMENT = "movement"
local MODE_PATH = table.freeze({ "input", "mode" })
local STICKS = { [K.Thumbstick1] = true, [K.Thumbstick2] = true }

type Keys = { Enum.KeyCode }

type Entry = {
	set: string,
	keys: Reactive.Ref<Keys>,
	handlers: { [{}]: () -> () },
}

type Set = {
	context: InputContext,
	priority: Reactive.Ref<number>,
	sink: Reactive.Ref<boolean>,
}

export type Actions = typeof(setmetatable(
	{} :: {
		app: any,
		folder: Folder,
		_scope: any,
		_sets: { [string]: Set },
		_entries: { [string]: Entry },
		_counts: { [string]: Reactive.Ref<number> },
		_controls: string?,
		_cas: any,
		_sinkName: string,
	},
	Actions
))

local function isGamepad(code: Enum.KeyCode): boolean
	local name = code.Name
	return name:sub(1, 6) == "Button" or name:sub(1, 4) == "DPad" or name:sub(1, 10) == "Thumbstick"
end

local function sticksOf(keys: Keys, wanted: boolean): Keys
	local out = {}
	for _, code in keys do
		if (STICKS[code] == true) == wanted then
			table.insert(out, code)
		end
	end
	return out
end

local function defaultParent(app: any): Instance
	local player = Players.LocalPlayer
	local scripts = player and player:FindFirstChildOfClass("PlayerScripts")
	return scripts or app.parent
end

-- Which default controls run. Read when the movement block starts, not at
-- construction: the default player module may not exist yet.
local function detectControls(): string
	local module = StarterPlayer:FindFirstChild("PlayerModule")
	local contexts = module and module:FindFirstChild("InputContexts")
	return if contexts and contexts:FindFirstChild("CharacterContext") then "new" else "old"
end

-- One InputAction with a binding per key, kept in step with `keys`.
local function actionElement(name: string, kind: Enum.InputActionType, keys: () -> Keys): Instance
	return Element.new("InputAction", {
		Name = name,
		Type = kind,
		Element.each(keys, function(code: Enum.KeyCode)
			return Element.new("InputBinding", { Name = code.Name, KeyCode = code })
		end),
	})
end

function Actions.new(app: any, options: { [string]: any }?): Actions
	local opts: { [string]: any } = options or {}
	local folder = Instance.new("Folder")
	folder.Name = (app.namePrefix or "Lucy_") .. "Actions"
	local self: Actions = setmetatable({
		app = app,
		folder = folder,
		_scope = Reactive.effectScope(true),
		_sets = {},
		_entries = {},
		_counts = {},
		_controls = opts.controls,
		_cas = opts.contextActions or ContextActionService,
		_sinkName = folder.Name .. "MovementSink",
	}, Actions) :: any

	self:_defineMovement()
	folder.Parent = opts.parent or defaultParent(app)
	return self
end

function Actions._count(self: Actions, set: string): Reactive.Ref<number>
	local count = self._counts[set]
	if not count then
		count = Reactive.ref(0)
		self._counts[set] = count
	end
	return count
end

function Actions._controlsNow(self: Actions): string
	return self._controls or detectControls()
end

function Actions._set(self: Actions, set: string, options: { [string]: any }?, enabled: (() -> boolean)?): Set
	local existing = self._sets[set]
	if existing then
		if options and options.priority ~= nil then
			existing.priority(options.priority)
		end
		if options and options.sink ~= nil then
			existing.sink(options.sink)
		end
		return existing
	end
	local priority = Reactive.ref((options and options.priority) or Actions.priority)
	local sink = Reactive.ref(if options and options.sink ~= nil then options.sink else false)
	local count = self:_count(set)
	local context: InputContext
	self._scope:run(function()
		context = Element.new("InputContext", {
			Name = set,
			Priority = priority,
			Sink = sink,
			Enabled = enabled or function()
				return count() == 0
			end,
			Parent = self.folder,
		})
	end)
	local entry: Set = { context = context, priority = priority, sink = sink }
	self._sets[set] = entry
	return entry
end

function Actions._entry(self: Actions, name: string): Entry
	local entry = self._entries[name]
	if not entry then
		error(`[Lucy] no action named "{name}"; define it first with app.actions:define`, 3)
	end
	return entry
end

-- The movement set: one button action for the keys and one direction action for
-- the stick, so each binding matches its action's type.
function Actions._defineMovement(self: Actions)
	local keys = Reactive.ref(Actions.movementKeys :: Keys)
	self._entries[MOVEMENT] = { set = MOVEMENT, keys = keys, handlers = {} }
	local held = self:_count(MOVEMENT)

	local set = self:_set(MOVEMENT, { priority = Actions.movementPriority, sink = true }, function()
		return held() > 0 and self:_controlsNow() == "new"
	end)
	self._scope:run(function()
		local buttons = actionElement(MOVEMENT, Enum.InputActionType.Bool, function()
			return sticksOf(keys(), false)
		end)
		buttons.Parent = set.context
		local stick = actionElement(MOVEMENT .. "Stick", Enum.InputActionType.Direction2D, function()
			return sticksOf(keys(), true)
		end)
		stick.Parent = set.context

		-- Old default controls only. TODO(remove): when Roblox removes the old
		-- default controls (the Workspace.PlayerScriptsUseInputActionSystem setting,
		-- due mid 2027), delete this effect, `_sinks`, InputManager._heldByLucy and
		-- the contextActions option. An InputContext cannot stop the old controls, so
		-- the keys are sunk through ContextActionService instead.
		Reactive.watchEffect(function(onCleanup)
			if held() == 0 or self:_controlsNow() ~= "old" then
				return
			end
			local cas = self._cas
			local name = self._sinkName
			cas:BindActionAtPriority(name, function()
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 1000, table.unpack(keys()))
			onCleanup(function()
				cas:UnbindAction(name)
			end)
		end)
	end)
end

-- Old default controls only (remove with them, see _defineMovement): true while
-- the movement block sinks `key` through ContextActionService. InputManager reads
-- such keys although the engine marks them processed.
function Actions._sinks(self: Actions, key: Enum.KeyCode): boolean
	local held = (Reactive.peek(self:_count(MOVEMENT)) :: any) > 0
	if not held or self:_controlsNow() ~= "old" then
		return false
	end
	return table.find(Reactive.peek(self._entries[MOVEMENT].keys) :: any, key) ~= nil
end

function Actions.define(self: Actions, set: string, actions: { [string]: Keys }, options: { [string]: any }?)
	if set == MOVEMENT then
		error('[Lucy] "movement" is built in; change its keys with app.actions:bind("movement", keys)', 2)
	end
	for name, keys in actions do
		local existing = self._entries[name]
		if existing and existing.set ~= set then
			error(`[Lucy] action "{name}" already belongs to set "{existing.set}"`, 2)
		end
		for _, code in keys do
			if STICKS[code] then
				error(`[Lucy] action "{name}": sticks are not supported as action keys yet`, 2)
			end
		end
	end
	local entry = self:_set(set, options)
	for name, keys in actions do
		local existing = self._entries[name]
		if existing then
			existing.keys(table.clone(keys))
			continue
		end
		local keysRef = Reactive.ref(table.clone(keys))
		local handlers = {}
		self._entries[name] = { set = set, keys = keysRef, handlers = handlers }
		self._scope:run(function()
			local action = actionElement(name, Enum.InputActionType.Bool, keysRef)
			Element.hydrate(action, {
				[Element.on("Pressed")] = function()
					self:_press(name)
				end,
			})
			action.Parent = entry.context
		end)
	end
end

function Actions._press(self: Actions, name: string)
	local entry = self._entries[name]
	if not entry then
		return
	end
	local list = {}
	for _, handler in entry.handlers do
		table.insert(list, handler)
	end
	for _, handler in list do
		handler()
	end
end

function Actions.on(self: Actions, name: string, handler: () -> ()): () -> ()
	if name == MOVEMENT then
		error('[Lucy] "movement" has no handlers', 2)
	end
	local entry = self:_entry(name)
	local token = {}
	entry.handlers[token] = handler
	local function stop()
		entry.handlers[token] = nil
	end
	if Reactive._hasOwner() then
		Reactive.onCleanup(stop)
	end
	return stop
end

function Actions.bind(self: Actions, nameOrMap: string | { [string]: Keys }, keys: Keys?)
	local map: { [string]: Keys }
	if type(nameOrMap) == "string" then
		map = { [nameOrMap] = keys or {} }
	else
		map = nameOrMap
	end
	for name, list in map do
		self:_entry(name)
		if name ~= MOVEMENT then
			for _, code in list do
				if STICKS[code] then
					error(`[Lucy] action "{name}": sticks are not supported as action keys yet`, 2)
				end
			end
		end
	end
	Reactive.batch(function()
		for name, list in map do
			self._entries[name].keys(table.clone(list))
		end
	end)
end

-- The action's keys for the current input mode: gamepad keys on a gamepad, none on
-- touch, the rest otherwise. Tracked.
function Actions.keys(self: Actions, name: string): Keys
	local entry = self:_entry(name)
	local mode = self.app.state:_tracked(MODE_PATH)
	local out = {}
	if mode == "touch" then
		return out
	end
	local gamepad = mode == "gamepad"
	for _, code in entry.keys() do
		if isGamepad(code) == gamepad then
			table.insert(out, code)
		end
	end
	return out
end

function Actions.disable(self: Actions, ...: string): () -> ()
	local sets = { ... }
	Reactive.batch(function()
		for _, set in sets do
			local count = self:_count(set)
			count((Reactive.peek(count) :: any) + 1)
		end
	end)
	local released = false
	return function()
		if released then
			return
		end
		released = true
		Reactive.batch(function()
			for _, set in sets do
				local count = self:_count(set)
				count(math.max((Reactive.peek(count) :: any) - 1, 0))
			end
		end)
	end
end

function Actions.enabled(self: Actions, set: string): boolean
	return self:_count(set)() == 0
end

-- The InputContext for a set, or nil. For tests and tools.
function Actions._context(self: Actions, set: string): InputContext?
	local entry = self._sets[set]
	return entry and entry.context
end

function Actions.destroy(self: Actions)
	self._scope:stop()
	self.folder:Destroy()
end

return Actions
