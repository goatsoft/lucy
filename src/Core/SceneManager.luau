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
			build = function(scene) ... parent things to scene.gui ... end,
			enter = function(scene, params) end,
			exit = function(scene) end,
			defaultFocus = function(scene) return scene.playButton end, -- gamepad/keyboard start
			onBack = function(scene) end, -- Escape / ButtonB with nothing else to close
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
local Signal = require(script.Parent.Signal)

local SceneManager = {}
SceneManager.__index = SceneManager

SceneManager.layerOrder = {
	screen = 10,
	overlay = 100,
	modal = 200,
}

-- What a scene's build/enter/exit get. Games may keep their own parts on it too.
export type Scene = {
	name: string,
	layer: string,
	gui: ScreenGui,
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
	self._scenes[name] = scene
	if def.build then
		def.build(scene)
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

	for name in table.clone(self._active) do
		if not wanted[name] then
			self:_exit(name)
		end
	end
	for name in wanted do
		if not self._active[name] then
			self:_enter(name, orders[name])
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

-- Escape / ButtonB: pop the top stacked scene, else ask the current screen.
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
