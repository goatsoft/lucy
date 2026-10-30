--!strict
--[[
	InputManager: first-class mouse, keyboard, gamepad and touch (ADR 0007).

	Publishes to AppState at "input":
		mode         "mouse" | "keyboard" | "gamepad" | "touch"   last input used
		device       "desktop" | "console" | "tablet" | "mobile"  what we are running on
		density      "default" | "touch" | "tv"                   drives the density sheet
		orientation  "landscape" | "portrait"
		breakpoint   "Compact" | "Regular" | "Wide"               see Adaptive.bands
		viewport     Vector2

	Focus:
		Roblox draws a white selection image around the selected GuiObject. App
		replaces it with a blank one everywhere and this manager tags the selected
		object "ui-focus-visible" (a themed UIStroke ring) only while the player is
		navigating with keyboard or gamepad, like CSS :focus-visible. It also
		scrolls any ScrollingFrame above it to show it (Core/Scroll).

	Scopes:
		pushScope({ root, defaultFocus, returnFocus }) confines Tab/arrow navigation
		to `root` (dialogs and modal scenes push one). When the player picks up a
		gamepad or presses Tab with nothing selected, the top scope's defaultFocus
		is selected. When the scope pops with focus inside it, focus goes back to
		returnFocus (an object or a function returning one), or else to what had
		focus when the scope was pushed, if it is still shown.

	Shoulder buttons:
		LB / RB call app.input:shoulder(-1 / 1): the nearest component around the
		focus with a shoulder method handles them (Tabs switch tab).

	Arrows:
		Arrow keys (keyboard), the D-pad and the left stick (gamepad) first call
		app.input:nudge(dx, dy, count): the nearest component around the focus
		with a nudge method that returns true takes them (a Slider changes its
		value), repeating while held, faster with `count`; letting go calls its
		release method. Otherwise arrows move focus as before.

	Back:
		Escape / ButtonB call app.input:back(): the newest pushBack handler runs
		(an open dialog closes), otherwise the SceneManager pops or calls onBack.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Adaptive = require(script.Parent.Adaptive)
local Maid = require(script.Parent.Maid)
local Scroll = require(script.Parent.Scroll)

local InputManager = {}
InputManager.__index = InputManager

export type Scope = { root: GuiObject | LayerCollector, defaultFocus: any?, returnFocus: any? }

export type InputManager = typeof(setmetatable(
	{} :: {
		app: any,
		maid: Maid.Maid,
		_scopes: { Scope },
		_back: { () -> boolean? },
		_focused: GuiObject?,
		_caps: { [string]: any },
		_mode: string,
		_nudged: any,
		_held: { key: Enum.KeyCode, token: {} }?,
		_stick: Vector2,
	},
	InputManager
))

local MODES: { [Enum.UserInputType]: string } = {
	[Enum.UserInputType.MouseButton1] = "mouse",
	[Enum.UserInputType.MouseButton2] = "mouse",
	[Enum.UserInputType.MouseButton3] = "mouse",
	[Enum.UserInputType.MouseMovement] = "mouse",
	[Enum.UserInputType.MouseWheel] = "mouse",
	[Enum.UserInputType.Keyboard] = "keyboard",
	[Enum.UserInputType.Touch] = "touch",
}
for i = 1, 8 do
	MODES[(Enum.UserInputType :: any)["Gamepad" .. i]] = "gamepad"
end

-- How long an arrow is held before it repeats, and how often it then does.
InputManager.repeatDelay = 0.35
InputManager.repeatRate = 0.06

local ARROWS: { [Enum.KeyCode]: Vector2 } = {
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
	[Enum.KeyCode.Up] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, 1),
	[Enum.KeyCode.DPadLeft] = Vector2.new(-1, 0),
	[Enum.KeyCode.DPadRight] = Vector2.new(1, 0),
	[Enum.KeyCode.DPadUp] = Vector2.new(0, -1),
	[Enum.KeyCode.DPadDown] = Vector2.new(0, 1),
}

-- The left stick as an arrow: the stronger axis past 0.6, nothing under 0.3.
local function stickDirection(position: Vector3, current: Vector2): Vector2
	local x, y = position.X, position.Y
	if math.max(math.abs(x), math.abs(y)) < 0.3 then
		return Vector2.zero
	end
	if math.max(math.abs(x), math.abs(y)) < 0.6 then
		return current
	end
	if math.abs(x) >= math.abs(y) then
		return Vector2.new(math.sign(x), 0)
	end
	return Vector2.new(0, -math.sign(y))
end

-- Shorter side below this (in Roblox screen points) is a phone.
InputManager.mobileMaxShortSide = 600

function InputManager.modeFor(inputType: Enum.UserInputType): string?
	return MODES[inputType]
end

function InputManager.deviceFor(caps: { [string]: any }): string
	if caps.tenFoot then
		return "console"
	end
	if caps.touch and not caps.keyboard and not caps.mouse then
		local viewport: Vector2 = caps.viewport or Vector2.zero
		local short = math.min(viewport.X, viewport.Y)
		if short > 0 and short < InputManager.mobileMaxShortSide then
			return "mobile"
		end
		return "tablet"
	end
	if caps.gamepad and not caps.keyboard and not caps.mouse then
		return "console"
	end
	return "desktop"
end

function InputManager.densityFor(device: string): string
	if device == "console" then
		return "tv"
	elseif device == "mobile" or device == "tablet" then
		return "touch"
	end
	return "default"
end

function InputManager.defaultModeFor(device: string): string
	if device == "console" then
		return "gamepad"
	elseif device == "mobile" or device == "tablet" then
		return "touch"
	end
	return "mouse"
end

local function readCaps(): { [string]: any }
	local camera = Workspace.CurrentCamera
	local ok, tenFoot = pcall(function()
		return GuiService:IsTenFootInterface()
	end)
	return {
		tenFoot = ok and tenFoot or false,
		touch = UserInputService.TouchEnabled,
		keyboard = UserInputService.KeyboardEnabled,
		mouse = UserInputService.MouseEnabled,
		gamepad = UserInputService.GamepadEnabled,
		viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720),
	}
end

--[[
	options:
		caps    fixed capabilities (tests); otherwise read from UserInputService
		watch   listen to engine events (default true)
]]
function InputManager.new(app: any, options: { [string]: any }?): InputManager
	local opts: { [string]: any } = options or {}
	local caps: { [string]: any } = opts.caps or readCaps()
	local self: InputManager = setmetatable({
		app = app,
		maid = Maid.new(),
		_scopes = {} :: { Scope },
		_back = {} :: { () -> boolean? },
		_focused = nil :: GuiObject?,
		_caps = caps,
		_mode = (opts.mode or InputManager.defaultModeFor(InputManager.deviceFor(caps))) :: string,
		_nudged = false,
		_held = nil :: { key: Enum.KeyCode, token: {} }?,
		_stick = Vector2.zero,
	}, InputManager)
	self:_publish()

	if opts.watch ~= false then
		self:_watch()
	end
	return self
end

function InputManager._publish(self: InputManager)
	local caps = self._caps
	local viewport: Vector2 = caps.viewport or Vector2.zero
	local device = InputManager.deviceFor(caps)
	self.app.state:set("input", {
		mode = self._mode,
		device = device,
		density = InputManager.densityFor(device),
		orientation = if viewport.Y > viewport.X then "portrait" else "landscape",
		breakpoint = Adaptive.breakpointFor(viewport.X),
		viewport = viewport,
		touch = caps.touch == true,
		gamepad = caps.gamepad == true,
		keyboard = caps.keyboard == true,
	})
end

function InputManager.mode(self: InputManager): string
	return self._mode
end

function InputManager.device(self: InputManager): string
	return self.app.state:get("input.device")
end

function InputManager.isNavigating(self: InputManager): boolean
	return self._mode == "keyboard" or self._mode == "gamepad"
end

function InputManager.setMode(self: InputManager, mode: string)
	if mode == self._mode then
		return
	end
	self._mode = mode
	self:_publish()
	if self:isNavigating() then
		self:markFocus(self._focused)
	else
		self:_clearRing()
	end
end

function InputManager.setCaps(self: InputManager, caps: { [string]: any })
	self._caps = caps
	self:_publish()
end

-- Focus ring -----------------------------------------------------------------

function InputManager._clearRing(self: InputManager)
	local focused = self._focused
	if focused and focused.Parent then
		focused:RemoveTag("ui-focus-visible")
	end
end

-- Records `object` as focused and shows the ring if the player is navigating.
function InputManager.markFocus(self: InputManager, object: GuiObject?)
	local previous = self._focused
	if previous and previous ~= object then
		previous:RemoveTag("ui-focus-visible")
	end
	self._focused = object
	if object and self:isNavigating() then
		object:AddTag("ui-focus-visible")
		-- The engine scrolls to the gamepad selection, but not to focus Lucy moves.
		Scroll.reveal(object)
	end
end

-- Selects `object` for gamepad/keyboard navigation (no-op where the engine refuses).
function InputManager.focus(self: InputManager, object: GuiObject?)
	pcall(function()
		GuiService.SelectedObject = object
	end)
	self:markFocus(object)
end

-- Scopes ---------------------------------------------------------------------

function InputManager.pushScope(self: InputManager, scope: Scope): () -> ()
	local previous = self._focused
	table.insert(self._scopes, scope)
	if self:isNavigating() then
		self:focusDefault()
	end
	return function()
		local index = table.find(self._scopes, scope)
		if index then
			table.remove(self._scopes, index)
		end
		local focused = self._focused
		if focused and scope.root and focused:IsDescendantOf(scope.root) then
			self:focus(nil)
			if self:isNavigating() then
				local back = self:_usable(scope.returnFocus) or self:_usable(previous)
				if back then
					self:focus(back)
				else
					self:focusDefault()
				end
			end
		end
	end
end

function InputManager.topScope(self: InputManager): Scope?
	return self._scopes[#self._scopes]
end

local function isShown(object: GuiObject): boolean
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

-- `target` (an object, a handle or a function returning either) if it can take
-- focus now: selectable, interactable and shown.
-- selene: allow(unused_variable)
function InputManager._usable(self: InputManager, target: any): GuiObject?
	if type(target) == "function" then
		target = target()
	end
	if type(target) == "table" and target.Instance then
		target = target.Instance
	end
	if typeof(target) ~= "Instance" or not target:IsA("GuiObject") or not target.Parent then
		return nil
	end
	local object = target :: GuiObject
	if object.Selectable and object.Interactable and isShown(object) then
		return object
	end
	return nil
end

-- Selectable, visible, interactable GuiObjects under `root`, in reading order.
-- selene: allow(unused_variable)
function InputManager.selectables(self: InputManager, root: Instance): { GuiObject }
	local out = {}
	for _, descendant in root:GetDescendants() do
		if
			descendant:IsA("GuiObject")
			and descendant.Selectable
			and descendant.Interactable
			and isShown(descendant)
		then
			table.insert(out, descendant)
		end
	end
	table.sort(out, function(a, b)
		local pa, pb = a.AbsolutePosition, b.AbsolutePosition
		if math.abs(pa.Y - pb.Y) > 4 then
			return pa.Y < pb.Y
		end
		return pa.X < pb.X
	end)
	return out
end

function InputManager._scopeRoots(self: InputManager): { Instance }
	local top = self:topScope()
	if top then
		return { top.root }
	end
	return self.app:activeGuis()
end

function InputManager.focusDefault(self: InputManager)
	local top = self:topScope()
	local target = top and top.defaultFocus
	if type(target) == "function" then
		target = target()
	end
	if type(target) == "table" and target.Instance then
		target = target.Instance
	end
	if typeof(target) ~= "Instance" then
		for _, root in self:_scopeRoots() do
			target = self:selectables(root)[1]
			if target then
				break
			end
		end
	end
	if typeof(target) == "Instance" then
		self:focus(target :: GuiObject)
	end
end

-- Moves keyboard focus by `step` through the current scope, wrapping around.
function InputManager.move(self: InputManager, step: number)
	local all = {}
	for _, root in self:_scopeRoots() do
		for _, object in self:selectables(root) do
			table.insert(all, object)
		end
	end
	if #all == 0 then
		return
	end
	local index = table.find(all, self._focused :: any)
	local nextIndex = if index then ((index - 1 + step) % #all) + 1 elseif step > 0 then 1 else #all
	self:focus(all[nextIndex])
end

-- The object focus was last moved to, if any.
function InputManager.focused(self: InputManager): GuiObject?
	return self._focused
end

--[[
	The shoulder buttons (LB / RB): from the focused object up, the first
	component with a `shoulder(step)` method that returns true handles them, so
	only the tabs around the focus switch, the innermost first. Returns whether
	anything did.
]]
function InputManager.shoulder(self: InputManager, step: number): boolean
	local node: Instance? = self._focused
	while node do
		local id = node:GetAttribute("LucyId")
		local handle: any = id and self.app:handle(id)
		if handle and handle.shoulder and handle:shoulder(step) then
			return true
		end
		node = node.Parent
	end
	return false
end

--[[
	An arrow (dx, dy of -1, 0 or 1; dy = -1 is up), `count` times while held:
	from the focused object up, the first component with a `nudge(dx, dy, count)`
	method that returns true takes it. Returns whether anything did.
]]
function InputManager.nudge(self: InputManager, dx: number, dy: number, count: number?): boolean
	local node: Instance? = self._focused
	while node do
		local id = node:GetAttribute("LucyId")
		local handle: any = id and self.app:handle(id)
		if handle and handle.nudge and handle:nudge(dx, dy, count or 1) then
			self._nudged = handle
			return true
		end
		node = node.Parent
	end
	return false
end

-- The held arrow was let go: the component that took it hears `release()`.
function InputManager.release(self: InputManager)
	local handle = self._nudged
	self._nudged = false
	if handle and handle.release and not handle.destroyed then
		handle:release()
	end
end

-- Nudges once; if taken, repeats until `key` is let go (see _watch).
function InputManager._hold(self: InputManager, key: Enum.KeyCode, direction: Vector2): boolean
	if not self:nudge(direction.X, direction.Y, 1) then
		return false
	end
	local token = {}
	self._held = { key = key, token = token }
	task.delay(InputManager.repeatDelay, function()
		local count = 1
		while self._held and self._held.token == token do
			count += 1
			if not self:nudge(direction.X, direction.Y, count) then
				break
			end
			task.wait(InputManager.repeatRate)
		end
	end)
	return true
end

function InputManager._letGo(self: InputManager)
	if self._held then
		self._held = nil
		self:release()
	end
end

-- Activates the focused element (Enter / Space on keyboard).
function InputManager.activate(self: InputManager)
	local focused = self._focused
	if not focused then
		return
	end
	local id = focused:GetAttribute("LucyId")
	local handle: any = id and self.app:handle(id)
	if handle and handle.click then
		handle:click()
	elseif handle and handle.toggle then
		handle:toggle()
	end
end

-- Back -----------------------------------------------------------------------

-- Registers a back handler; return true from it to stop further handling.
function InputManager.pushBack(self: InputManager, handler: () -> boolean?): () -> ()
	table.insert(self._back, handler)
	return function()
		local index = table.find(self._back, handler)
		if index then
			table.remove(self._back, index)
		end
	end
end

function InputManager.back(self: InputManager): boolean
	for index = #self._back, 1, -1 do
		local handler = self._back[index]
		if handler() ~= false then
			return true
		end
	end
	if self.app.scenes then
		return self.app.scenes:back()
	end
	return false
end

-- Engine wiring --------------------------------------------------------------

function InputManager._watch(self: InputManager)
	local maid = self.maid

	maid:give(UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local mode = InputManager.modeFor(inputType)
		if mode then
			self:setMode(mode)
		end
	end))

	maid:give(GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		self:markFocus(GuiService.SelectedObject)
	end))

	local function refreshCaps()
		self:setCaps(readCaps())
	end
	maid:give(UserInputService.GamepadConnected:Connect(refreshCaps))
	maid:give(UserInputService.GamepadDisconnected:Connect(refreshCaps))
	local camera = Workspace.CurrentCamera
	if camera then
		maid:give(camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshCaps))
	end

	maid:give(UserInputService.InputBegan:Connect(function(input, processed)
		local key = input.KeyCode
		if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Escape then
			if self:back() then
				return
			end
		end
		if key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.ButtonR1 then
			if self:shoulder(if key == Enum.KeyCode.ButtonL1 then -1 else 1) then
				return
			end
		end
		-- Arrows go to a component around the focus first (a Slider), even when the
		-- engine already used them to move gamepad selection.
		local arrow = ARROWS[key]
		if
			arrow
			and self._focused
			and self:isNavigating()
			and UserInputService:GetFocusedTextBox() == nil
			and self:_hold(key, arrow)
		then
			return
		end
		if processed and key ~= Enum.KeyCode.Tab then
			return
		end
		if key == Enum.KeyCode.Tab then
			self:setMode("keyboard")
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			self:move(if shift then -1 else 1)
		elseif self._mode == "keyboard" and self._focused then
			if key == Enum.KeyCode.Down or key == Enum.KeyCode.Right then
				self:move(1)
			elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.Left then
				self:move(-1)
			elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.Space then
				self:activate()
			end
		elseif
			self._mode == "gamepad"
			and GuiService.SelectedObject == nil
			and input.UserInputType.Name:find("Gamepad")
		then
			self:focusDefault()
		end
	end))

	maid:give(UserInputService.InputEnded:Connect(function(input)
		local held = self._held
		if held and input.KeyCode == held.key then
			self:_letGo()
		end
	end))

	maid:give(UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.Thumbstick1 then
			return
		end
		local direction = stickDirection(input.Position, self._stick)
		if direction == self._stick then
			return
		end
		self._stick = direction
		local held = self._held
		if held and held.key == Enum.KeyCode.Thumbstick1 then
			self:_letGo()
		end
		if
			direction ~= Vector2.zero
			and self._focused
			and self:isNavigating()
			and UserInputService:GetFocusedTextBox() == nil
		then
			self:_hold(Enum.KeyCode.Thumbstick1, direction)
		end
	end))
end

function InputManager.destroy(self: InputManager)
	self._held = nil
	self._nudged = false
	self:_clearRing()
	self.maid:clean()
	self._scopes = {}
	self._back = {}
end

return InputManager
