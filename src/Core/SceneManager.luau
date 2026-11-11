--!strict
--[[
	SceneManager: title screen, game HUD, menus and modals that never fight (ADR 0005).

	Roblox has no built-in "scene" for UI: every ScreenGui under PlayerGui is drawn
	at once, ordered by DisplayOrder, and anything left Enabled keeps taking input.
	So each scene owns exactly one ScreenGui, and the manager decides which are
	Enabled from AppState:

		scenes.current   the one "screen" scene shown (Title, Lobby, Game ...)
		scenes.stack     "modal"/"overlay" scenes pushed on top, last is topmost
		scenes.visible   { [name] = true } overlays shown independently (HUD, chat)

	Writing those paths navigates; goTo/push/pop/show/hide just write them.

		app.scenes:register("Title", {
			layer = "screen",            -- "screen" | "overlay" | "modal"
			keepAlive = true,            -- false destroys the gui on exit
			safeArea = true,             -- also make scene.safe: the part of the screen clear of
			                             -- Roblox's top bar and the device's cut-outs
			build = function(scene) ... parent things to scene.gui ... end,
			enter = function(scene, params) end,
			exit = function(scene) end,
			defaultFocus = function(scene) return scene.playButton end, -- gamepad/keyboard start
			returnFocus = nil,           -- focus when it exits: nil what had it before, an object,
			                             -- handle or function(scene), or false for nothing
			onBack = function(scene) end, -- a back key (B, Backspace) with nothing else to close
		})
		app.scenes:goTo("Title")
		app.scenes:push("Pause")   app.scenes:pop()
		app.scenes:show("Hud")     app.scenes:hide("Hud")

	Display orders: screen 10, overlay 100+, modal 200+ (stack position added),
	shared portals (modal dialogs 900, toasts 1000) sit above every scene.

	Input: entering a screen or modal scene pushes an InputManager focus scope, so
	Tab/arrows/gamepad stay inside the topmost one and its defaultFocus is selected
	when the player is on keyboard or gamepad. back() pops the top of the stack,
	else calls the current screen's onBack.
]]

local Maid = require(script.Parent.Maid)
local Reactive = require(script.Parent.Reactive)
local Scroll = require(script.Parent.Scroll)
local Signal = require(script.Parent.Signal)

local SceneManager = {}
SceneManager.__index = SceneManager

SceneManager.layerOrder = {
	screen = 10,
	overlay = 100,
	modal = 200,
}

-- How a scene that fails to build, enter or exit is reported. Specs swap it.
SceneManager._warn = warn

-- What a scene's build/enter/exit get. Games may keep their own parts on it too.
export type Scene = {
	name: string,
	layer: string,
	gui: ScreenGui,
	safe: Frame?,
	app: any,
	maid: Maid.Maid,
	params: any,
	popScope: (() -> ())?,
	[string]: any,
}

export type SceneManager = typeof(setmetatable(
	{} :: {
		app: any,
		Changed: Signal.Signal,
		_defs: { [string]: { [string]: any } },
		_scenes: { [string]: Scene },
		_active: { [string]: boolean },
		_params: { [string]: any },
		_current: string?,
		_unsubscribe: () -> (),
	},
	SceneManager
))

function SceneManager.new(app: any): SceneManager
	local self: SceneManager = setmetatable({
		app = app,
		Changed = Signal.new(),
		_defs = {},
		_scenes = {},
		_active = {},
		_params = {},
		_current = nil,
		_unsubscribe = function() end,
	}, SceneManager)
	self._unsubscribe = app.state:subscribe("scenes", function()
		self:_reconcile()
	end)
	return self
end

function SceneManager.register(self: SceneManager, name: string, def: { [string]: any })
	if self._defs[name] then
		error(`[Lucy] scene "{name}" is already registered`, 2)
	end
	local layer = def.layer or "screen"
	if SceneManager.layerOrder[layer] == nil then
		error(`[Lucy] scene "{name}" has unknown layer "{layer}"`, 2)
	end
	local copy = table.clone(def)
	copy.layer = layer
	self._defs[name] = copy
end

function SceneManager._def(self: SceneManager, name: string, level: number?): { [string]: any }
	local def = self._defs[name]
	if not def then
		error(`[Lucy] unknown scene "{name}"`, (level or 2) + 1)
	end
	return def
end

function SceneManager.get(self: SceneManager, name: string): Scene?
	return self._scenes[name]
end

function SceneManager.current(self: SceneManager): string?
	return self._current
end

function SceneManager.isVisible(self: SceneManager, name: string): boolean
	return self._active[name] == true
end

function SceneManager.goTo(self: SceneManager, name: string, params: any?)
	local def = self:_def(name)
	if def.layer ~= "screen" then
		error(`[Lucy] scene "{name}" is a {def.layer}; use push/show`, 2)
	end
	self._params[name] = params
	if self._current == name and params ~= nil then
		-- Re-entering the same screen with new params: exit then enter again.
		self:_exit(name)
		self:_enter(name)
		return
	end
	self.app.state:set("scenes.current", name)
end

function SceneManager.push(self: SceneManager, name: string, params: any?)
	local def = self:_def(name)
	if def.layer == "screen" then
		error(`[Lucy] scene "{name}" is a screen; use goTo`, 2)
	end
	self._params[name] = params
	local stack = table.clone(self.app.state:get("scenes.stack") or {})
	local index = table.find(stack, name)
	if index then
		table.remove(stack, index)
	end
	table.insert(stack, name)
	self.app.state:set("scenes.stack", stack)
end

function SceneManager.pop(self: SceneManager): string?
	local stack = table.clone(self.app.state:get("scenes.stack") or {})
	local top = table.remove(stack)
	if top then
		self.app.state:set("scenes.stack", stack)
	end
	return top
end

function SceneManager.show(self: SceneManager, name: string, params: any?)
	local def = self:_def(name)
	if def.layer == "screen" then
		error(`[Lucy] scene "{name}" is a screen; use goTo`, 2)
	end
	self._params[name] = params
	self.app.state:set(`scenes.visible.{name}`, true)
end

function SceneManager.hide(self: SceneManager, name: string)
	self:_def(name)
	self.app.state:set(`scenes.visible.{name}`, nil)
end

--[[
	The part of the screen clear of Roblox's top bar and the device's cut-outs
	(Enum.ScreenInsets.CoreUISafeInsets), as a Frame in `gui` sized in the gui's
	own units, so a panel in it keeps clear while the gui itself (a backdrop)
	still covers the whole screen. It draws above the gui's other children (ZIndex 2). A hidden probe gui with those insets is
	measured as the screen, the bar or the scale changes.
]]
function SceneManager.safeArea(gui: ScreenGui, maid: Maid.Maid): Frame
	local safe = Instance.new("Frame")
	safe.Name = "Safe"
	safe.BackgroundTransparency = 1
	-- Above what the scene puts straight in its gui (a backdrop, made after this frame)
	safe.ZIndex = 2
	safe.Size = UDim2.fromScale(1, 1)
	safe.Parent = gui

	local probe = Instance.new("ScreenGui")
	probe.Name = `{gui.Name}_SafeArea`
	probe.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	probe.ResetOnSpawn = false
	probe.Archivable = false
	probe.Parent = gui.Parent
	maid:give(probe)

	local function fit()
		if probe.Parent ~= gui.Parent then
			probe.Parent = gui.Parent
		end
		local scale = math.max(Scroll.scaleOf(gui), 0.001)
		if probe.AbsoluteSize.X <= 0 or probe.AbsoluteSize.Y <= 0 or gui.AbsoluteSize.Y <= 0 then
			safe.Position = UDim2.fromOffset(0, 0)
			safe.Size = UDim2.fromScale(1, 1)
			return
		end
		local at = (probe.AbsolutePosition - gui.AbsolutePosition) / scale
		local size = probe.AbsoluteSize / scale
		safe.Position = UDim2.fromOffset(math.floor(at.X), math.ceil(at.Y))
		safe.Size = UDim2.fromOffset(math.floor(size.X), math.floor(size.Y))
	end
	for _, object in { gui, probe } do
		maid:give(object:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
		maid:give(object:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit))
	end
	maid:give(gui:GetPropertyChangedSignal("Parent"):Connect(fit))
	-- Lucy's scale for the device (Adaptive) changes without the gui's size changing
	local function followScale(child: Instance)
		if child:IsA("UIScale") then
			maid:give(child:GetPropertyChangedSignal("Scale"):Connect(fit))
			fit()
		end
	end
	for _, child in gui:GetChildren() do
		followScale(child)
	end
	maid:give(gui.ChildAdded:Connect(followScale))
	fit()
	return safe
end

function SceneManager._build(self: SceneManager, name: string): Scene
	local def = self._defs[name]
	local existing = self._scenes[name]
	if existing then
		return existing
	end
	local gui = self.app:createGui("Scene_" .. name, {
		displayOrder = SceneManager.layerOrder[def.layer],
		enabled = false,
		ignoreGuiInset = def.ignoreGuiInset,
	})
	local scene: Scene = {
		name = name,
		layer = def.layer,
		gui = gui,
		app = self.app,
		maid = Maid.new(),
		params = nil,
		popScope = nil,
	}
	if def.layer == "modal" then
		-- Swallow clicks so nothing underneath reacts while a modal is up.
		local blocker = Instance.new("TextButton")
		blocker.Name = "Blocker"
		blocker.Text = ""
		blocker.AutoButtonColor = false
		blocker.BackgroundTransparency = 1
		blocker.Size = UDim2.fromScale(1, 1)
		blocker.ZIndex = 0
		blocker.Selectable = false
		blocker.Parent = gui
	end
	if def.safeArea then
		scene.safe = SceneManager.safeArea(gui, scene.maid)
	end
	self._scenes[name] = scene
	if def.build then
		-- Build runs in the scene's own scope, so composables work in it and what
		-- it makes lives until the scene is destroyed, whoever showed the scene.
		local scope = Reactive.effectScope(true)
		scene.maid:give(function()
			scope:stop()
		end)
		-- A failed build is dropped, so the next visit builds it again.
		local ok, err = xpcall(scope.run, function(message)
			return `{tostring(message)}\n{debug.traceback(nil, 2)}`
		end, scope, def.build, scene)
		if not ok then
			self._scenes[name] = nil
			scene.maid:clean()
			gui:Destroy()
			error(`[Lucy] scene "{name}" failed to build: {err}`, 0)
		end
	end
	return scene
end

function SceneManager._enter(self: SceneManager, name: string, displayOrder: number?)
	local def = self._defs[name]
	local scene = self:_build(name)
	if displayOrder then
		scene.gui.DisplayOrder = displayOrder
	end
	scene.params = self._params[name]
	scene.gui.Enabled = true
	self._active[name] = true
	if def.enter then
		def.enter(scene, scene.params)
	end
	if def.layer ~= "overlay" and self.app.input then
		scene.popScope = self.app.input:pushScope({
			root = scene.gui,
			defaultFocus = def.defaultFocus and function()
				return if type(def.defaultFocus) == "function"
					then def.defaultFocus(scene)
					else def.defaultFocus
			end,
			returnFocus = if def.returnFocus == false
				then false
				elseif type(def.returnFocus) == "function" then function()
					return def.returnFocus(scene)
				end
				else def.returnFocus,
		})
	end
end

function SceneManager._exit(self: SceneManager, name: string)
	local def = self._defs[name]
	local scene = self._scenes[name]
	self._active[name] = nil
	if not scene then
		return
	end
	if scene.popScope then
		scene.popScope()
		scene.popScope = nil
	end
	if def.exit then
		def.exit(scene)
	end
	scene.gui.Enabled = false
	if def.keepAlive == false then
		Maid.clean(scene.maid)
		scene.gui:Destroy()
		self._scenes[name] = nil
	end
end

-- Makes the set of enabled scene guis match AppState.
function SceneManager._reconcile(self: SceneManager)
	local state = self.app.state
	local current = state:get("scenes.current")
	local stack = state:get("scenes.stack") or {}
	local visible = state:get("scenes.visible") or {}

	if current ~= nil and (self._defs[current] == nil or self._defs[current].layer ~= "screen") then
		warn(`[Lucy] scenes.current "{current}" is not a registered screen`)
		state:set("scenes.current", self._current)
		return
	end

	local wanted, orders = {}, {}
	if current then
		wanted[current] = true
	end
	for name in visible do
		if self._defs[name] then
			wanted[name] = true
		end
	end
	for index, name in stack do
		local def = self._defs[name]
		if def then
			wanted[name] = true
			orders[name] = SceneManager.layerOrder[def.layer] + index
		end
	end

	-- One scene failing must not stop the others, or leave _current behind.
	local function safely(phase: string, name: string, fn: any, ...: any)
		local ok, err = pcall(fn, self, name, ...)
		if not ok then
			local message = tostring(err)
			if not string.find(message, `scene "{name}"`, 1, true) then
				message = `[Lucy] scene "{name}" failed to {phase}: {message}`
			end
			self._warn(message)
		end
	end
	for name in table.clone(self._active) do
		if not wanted[name] then
			safely("exit", name, SceneManager._exit)
		end
	end
	for name in wanted do
		if not self._active[name] then
			safely("enter", name, SceneManager._enter, orders[name])
		elseif orders[name] then
			self._scenes[name].gui.DisplayOrder = orders[name]
		end
	end

	if current ~= self._current then
		local previous = self._current
		self._current = current
		self.Changed:Fire(current, previous)
	end
end

-- How many modal scenes are pushed. Tracked, for App.modalOpen.
function SceneManager.modalCount(self: SceneManager): number
	local stack = self.app.state:_tracked({ "scenes", "stack" }) or {}
	local count = 0
	for _, name in stack do
		local def = self._defs[name]
		if def and def.layer == "modal" then
			count += 1
		end
	end
	return count
end

-- A back key: pop the top stacked scene, else ask the current screen.
function SceneManager.back(self: SceneManager): boolean
	local stack = self.app.state:get("scenes.stack") or {}
	if #stack > 0 then
		self:pop()
		return true
	end
	local current = self._current
	local def = if current then self._defs[current] else nil
	if current and def and def.onBack then
		return def.onBack(self._scenes[current]) ~= false
	end
	return false
end

function SceneManager.destroy(self: SceneManager)
	self._unsubscribe()
	self.Changed:DisconnectAll()
	for name, scene in self._scenes :: { [string]: any } do
		scene.maid:clean()
		scene.gui:Destroy()
		self._scenes[name] = nil
	end
	self._active = {}
end

return SceneManager
