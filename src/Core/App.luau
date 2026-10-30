--[[
	App: the root object a game creates once on the client.

		local Lucy = require(ReplicatedStorage.Packages.Lucy)
		local app = Lucy.App.new({ theme = "dark", baseColor = "zinc" })

		app.state   AppState, the single source of truth for UI (ADR 0004)
		app.theme   Theme, Universal Styling sheets (ADR 0003)
		app.input   InputManager, mouse/keyboard/gamepad/touch and device class (ADR 0007)
		app.scenes  SceneManager, title screen / game / menus (ADR 0005)
		app.toast   toast notifications, if the Toaster component is present

	config:
		theme         initial theme name ("dark")
		baseColor     base colour for the default themes ("zinc", "slate", ...)
		primary       palette hue to tint Primary ("blue", "rose", ...)
		primitives    token overrides (see Core/Tokens)
		themes        theme overrides (replaces baseColor/primary)
		densities     density overrides
		density       pin a density ("default" | "touch" | "tv"); otherwise follows the device
		parent        where ScreenGuis go (PlayerGui on a client, StarterGui otherwise)
		styleParent   where the StyleSheet folder goes (ReplicatedStorage)
		adaptive      false to disable scaling, or Adaptive options merged over the device profile
		input         InputManager options ({ caps, mode, watch } for tests)
		state         initial AppState tree
		namePrefix    prefix for created instances ("Lucy_")
		setCurrent    make this the default app for components (true)
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Adaptive = require(script.Parent.Adaptive)
local AppState = require(script.Parent.AppState)
local Context = require(script.Parent.Context)
local InputManager = require(script.Parent.InputManager)
local Maid = require(script.Parent.Maid)
local SceneManager = require(script.Parent.SceneManager)
local Theme = require(script.Parent.Theme)
local Tokens = require(script.Parent.Tokens)

local App = {}
App.__index = App

-- Display orders for shared portals. Scenes use 10-299 (see SceneManager).
App.portalOrder = {
	test = 400,
	popover = 800,
	modal = 900,
	toast = 1000,
}

local function defaultParent(): Instance
	local player = Players.LocalPlayer
	if player then
		return player:WaitForChild("PlayerGui")
	end
	return StarterGui
end

function App.new(config: { [string]: any }?)
	local options = config or {}
	local self = setmetatable({}, App)
	self.config = options
	self.namePrefix = options.namePrefix or "Lucy_"
	self.parent = options.parent or defaultParent()
	self.maid = Maid.new()
	self._ids = {}
	self._handles = {}
	self._guis = {}
	self._portals = {}
	self._adaptive = {}

	-- One blank template replaces Roblox's default selection ring everywhere.
	local blank = Instance.new("Frame")
	blank.Name = self.namePrefix .. "NoSelectionImage"
	blank.BackgroundTransparency = 1
	blank.BorderSizePixel = 0
	blank.Size = UDim2.fromScale(1, 1)
	self.selectionImage = blank
	self.maid:give(blank)
	if self.parent:IsA("PlayerGui") then
		local previous = self.parent.SelectionImageObject
		self.parent.SelectionImageObject = blank
		self.maid:give(function()
			if self.parent.SelectionImageObject == blank then
				self.parent.SelectionImageObject = previous
			end
		end)
	end

	self.theme = Theme.new({
		name = self.namePrefix .. "Styles",
		primitives = options.primitives,
		themes = options.themes or Tokens.themesFor(options.baseColor, { primary = options.primary }),
		densities = options.densities,
		default = options.theme,
		density = options.density,
		parent = options.styleParent,
	})
	self.maid:give(self.theme)

	local initial = table.clone(options.state or {})
	initial.theme = self.theme:get()
	initial.density = self.theme:getDensity()
	self.state = AppState.new(initial)
	self.maid:give(self.state)

	self:_bindSetting("theme", "set", "get", self.theme.Changed)
	self:_bindSetting("density", "setDensity", "getDensity", self.theme.DensityChanged)

	self.input = InputManager.new(self, options.input)
	self.maid:give(self.input)

	-- Density and scaling follow the device unless pinned in config.
	local function onDevice(device)
		if device == nil then
			return
		end
		if options.density == nil then
			self.state:set("density", InputManager.densityFor(device))
		end
		for _, handle in self._adaptive do
			handle:configure(self:_adaptiveOptions(handle.options.getViewport))
		end
	end
	self.maid:give(self.state:subscribe("input.device", onDevice))
	onDevice(self.state:get("input.device"))

	self.scenes = SceneManager.new(self)
	self.maid:give(self.scenes)

	-- Install optional services from components that are present (copy-in friendly).
	local components = script.Parent.Parent:FindFirstChild("Components")
	local toaster = components and components:FindFirstChild("Toaster")
	if toaster then
		require(toaster).install(self)
	end

	if options.setCurrent ~= false then
		Context.setCurrent(self)
	end
	return self
end

-- Two-way binding between a state key and a theme setting (theme, density).
function App:_bindSetting(key: string, setter: string, getter: string, changed)
	local theme = self.theme
	self.maid:give(self.state:subscribe(key, function(name)
		if name == theme[getter](theme) then
			return
		end
		local ok = pcall(theme[setter], theme, name)
		if not ok then
			warn(`[Lucy] unknown {key} "{tostring(name)}", keeping "{theme[getter](theme)}"`)
			self.state:set(key, theme[getter](theme))
		end
	end))
	self.maid:give(changed:Connect(function(name)
		self.state:set(key, name)
	end))
end

function App:_adaptiveOptions(getViewport)
	local device = self.state:get("input.device") or "desktop"
	local merged = table.clone(Adaptive.profiles[device] or Adaptive.defaults)
	if type(self.config.adaptive) == "table" then
		for key, value in self.config.adaptive do
			merged[key] = value
		end
	end
	merged.getViewport = getViewport
	return merged
end

function App:nextId(kind: string): string
	local n = (self._ids[kind] or 0) + 1
	self._ids[kind] = n
	return `{kind}-{n}`
end

-- Component handle registry (used for keyboard activation and debugging).
function App:registerHandle(handle)
	self._handles[handle.id] = handle
end

function App:unregisterHandle(handle)
	if self._handles[handle.id] == handle then
		self._handles[handle.id] = nil
	end
end

function App:handle(id: string)
	return self._handles[id]
end

function App:setTheme(name: string)
	self.theme:set(name)
end

function App:setDensity(name: string)
	self.theme:setDensity(name)
end

-- Creates a themed, adaptive ScreenGui. Used by portals and scenes.
function App:createGui(name: string, options: { [string]: any }?): ScreenGui
	local opts = options or {}
	local gui = Instance.new("ScreenGui")
	gui.Name = self.namePrefix .. name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = if opts.ignoreGuiInset == nil then true else opts.ignoreGuiInset
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = opts.displayOrder or 0
	gui.Enabled = if opts.enabled == nil then true else opts.enabled
	self.theme:link(gui)
	if self.config.adaptive ~= false then
		local adaptive = Adaptive.attach(gui, self:_adaptiveOptions(opts.getViewport))
		table.insert(self._adaptive, adaptive)
		gui.Destroying:Connect(function()
			local index = table.find(self._adaptive, adaptive)
			if index then
				table.remove(self._adaptive, index)
			end
			adaptive:destroy()
		end)
	end
	table.insert(self._guis, gui)
	gui.Destroying:Connect(function()
		local index = table.find(self._guis, gui)
		if index then
			table.remove(self._guis, index)
		end
	end)
	gui.Parent = opts.parent or self.parent
	return gui
end

-- Enabled app guis, topmost first (keyboard navigation searches these).
function App:activeGuis(): { ScreenGui }
	local out = {}
	for _, gui in self._guis do
		if gui.Enabled and gui.Parent then
			table.insert(out, gui)
		end
	end
	table.sort(out, function(a, b)
		return a.DisplayOrder > b.DisplayOrder
	end)
	return out
end

-- A shared, lazily created ScreenGui layer ("modal", "toast", ...), like a Vue Teleport target.
function App:portal(name: string, options: { [string]: any }?): ScreenGui
	local existing = self._portals[name]
	if existing and existing.Parent then
		return existing
	end
	local opts = table.clone(options or {})
	opts.displayOrder = opts.displayOrder or App.portalOrder[name] or 700
	local gui = self:createGui("Portal_" .. name, opts)
	self._portals[name] = gui
	self.maid:give(gui)
	return gui
end

function App:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.maid:clean()
	self._portals = {}
	self._handles = {}
	Context.clearIf(self)
end
App.Destroy = App.destroy

return App
