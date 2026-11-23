--!strict
--[[
	InputManager: first-class mouse, keyboard, gamepad and touch (ADR 0007).

	Publishes to AppState at "input":
		mode         "mouse" | "keyboard" | "gamepad" | "touch"   last input used
		device       "desktop" | "console" | "tablet" | "mobile"  what we are running on
		density      "default" | "touch" | "tv"                   drives the density sheet
		orientation  "landscape" | "portrait"
		breakpoint   "Compact" | "Regular" | "Wide"               see Adaptive.bands
		height       "short" | "tall"                             see Adaptive.shortHeight
		viewport     Vector2

	Focus:
		Roblox draws a white selection image around the selected GuiObject. App
		replaces it with a blank one everywhere and this manager tags the selected
		object "ui-focus-visible" only while the player is navigating with keyboard
		or gamepad, like CSS :focus-visible. It also scrolls any ScrollingFrame above
		it to show it (Core/Scroll).

		The ring itself is three UIStrokes of the manager's own put inside what has
		focus (ui-focus-ring, ui-focus-feather, ui-focus-halo, all ui-focus-ring-part):
		sharp at the edge and fading inward, drawn over the element's own outline. A
		game's rule on the element's ::UIStroke (a coloured card's outline) never
		reaches them, so the ring always shows. Their looks are style rules
		(Core/Theme). None go on a row that rings one part (ui-ring-host) or on UI
		Lucy did not build (it has app.selectionRing).

	Following focus:
		app.input:focusRef() is a getter bindings can read: what has focus now (an
		instance, or nil), tracked, so a computed or a getter prop follows it. Games read
		it instead of following GuiService.SelectedObject themselves. Focus on something
		that is hidden (its panel closed under it) is let go a moment later
		(dropHidden, checked a few times a second), so the gamepad is never left on
		nothing and a hidden selection never holds the keys. When what has focus inside a
		focus scope is removed (a list filtered under it, a panel dropping its content),
		focus goes to the scope's default on the next frame, or back to what had it before
		the scope if the scope is closing.

	Tiles:
		A tile (an Item with focus = "tile", Core/Tiles) is one stop until the player steps
		into it: focus that lands inside a closed tile goes to the tile, and selectables()
		skips what is in it. Each time focus moves, Tiles.landed opens, closes and points the
		D-pad around tiles.

	Scopes:
		pushScope({ root, defaultFocus, returnFocus, ready }) confines Tab/arrow navigation
		to `root` (dialogs and modal scenes push one). When the player picks up a
		gamepad or presses Tab with nothing selected, the top scope's defaultFocus
		is selected, when it is pushed and again a frame later if focus ended up
		outside it (the engine can undo a selection made as a dialog first shows).
		When the scope pops with focus inside it, focus goes back to
		returnFocus (an object or a function returning one), or else to what had
		focus when the scope was pushed, if it can still take focus, or else to
		the control nearest where that was (a Buy button that disabled itself).
		returnFocus = false leaves nothing selected (a HUD whose buttons must not
		keep the gamepad's left stick).

	Right stick:
		With a gamepad, the right stick scrolls round the focus: up and down the nearest
		ScrollingFrame above it that scrolls that way, left and right the nearest that scrolls
		sideways (Scroll.byStick). While focus sits in something it can scroll, the stick is
		sunk, so the camera behind stays put. Focus scrolled out of view goes to the control
		nearest it that shows, so the D-pad carries on from what the player sees.

	Shoulder buttons:
		LB / RB call app.input:shoulder(-1 / 1): the nearest component around the
		focus with a shoulder method handles them (Tabs switch tab).

	Arrows:
		Arrow keys (keyboard), the D-pad and the left stick (gamepad) first call
		app.input:nudge(dx, dy, count): the nearest component around the focus
		with a nudge method that returns true takes them (a Slider changes its
		value), repeating while held, faster with `count`; letting go calls its
		release method. Otherwise arrows move focus as before: the engine moves gamepad
		selection, and keyboard arrows go where the focused object's NextSelection*
		points (a fan menu), else through the Tab order.

	Back:
		The back keys (ButtonB and Backspace; App option backKeys) call
		app.input:back(): the newest pushBack handler runs (an open dialog
		closes), otherwise the SceneManager pops or calls onBack. Backspace is
		left alone while a TextBox has focus. Escape is not a default: Roblox
		always opens its own menu on Escape and games cannot stop it (ADR 0031).

	Roblox menu:
		Opening the Roblox menu clears the selection and closing it does not put
		it back, so restoreFocus() runs when it closes.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Adaptive = require(script.Parent.Adaptive)
local Element = require(script.Parent.Element)
local Maid = require(script.Parent.Maid)
local Parts = require(script.Parent.Parts)
local Reactive = require(script.Parent.Reactive)
local Scroll = require(script.Parent.Scroll)
local Tiles = require(script.Parent.Tiles)

local InputManager = {}
InputManager.__index = InputManager

-- `holds` and `orphaned` are the manager's own: whether focus was last inside the scope, and
-- whether what had it there was removed (see _followScope)
export type Scope = {
	root: GuiObject | LayerCollector,
	defaultFocus: any?,
	returnFocus: any?,
	holds: boolean?,
	orphaned: boolean?,
	-- false while its controls are not where the player will see them (a panel waiting off the
	-- screen for the frame that measures it, ADR 0050): the default goes to the engine after
	ready: (() -> boolean)?,
}

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
		_rightStick: Vector2,
		_stickSunk: boolean,
		_backKeys: { Enum.KeyCode },
		_lastFocused: GuiObject?,
		_returning: boolean,
		_focusLive: boolean,
		_holding: boolean,
		_focusRef: Reactive.Ref<GuiObject?>,
		_ring: { UIStroke }?,
		_ringOn: boolean,
		_ringStyled: boolean,
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

-- Keys that go back when an App does not set backKeys. Not Escape (ADR 0031).
InputManager.backKeys = { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace }

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

local STICK_SINK = "LucyScrollStick"

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

-- What the device has now. Specs swap it to stand in for the engine.
InputManager._readCaps = readCaps

--[[
	options:
		caps    fixed capabilities (tests); otherwise read from UserInputService
		watch   listen to engine events (default true)
		backKeys  keys that go back (InputManager.backKeys)
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
		_rightStick = Vector2.zero,
		_stickSunk = false,
		_backKeys = (opts.backKeys or InputManager.backKeys) :: { Enum.KeyCode },
		_lastFocused = nil :: GuiObject?,
		_returning = false,
		_focusLive = false,
		_holding = false,
		_focusRef = Reactive.ref(nil :: GuiObject?),
		_ring = nil :: { UIStroke }?,
		_ringOn = false,
		_ringStyled = false,
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
		height = Adaptive.heightFor(viewport.Y),
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

--[[
	The player used an input of this type (the engine's LastInputTypeChanged). Keys or a mouse
	on a device that said it had none (a keyboard paired with a phone or tablet mid game) look
	again at what it has, so `input.keyboard` and the device follow; then the mode follows.
]]
function InputManager.inputUsed(self: InputManager, inputType: Enum.UserInputType)
	local mode = InputManager.modeFor(inputType)
	if mode == nil then
		return
	end
	if (mode == "keyboard" or mode == "mouse") and not self._caps[mode] then
		local caps = InputManager._readCaps()
		if caps[mode] then
			self:setCaps(caps)
		end
	end
	self:setMode(mode)
end

-- Focus ring -----------------------------------------------------------------

-- How many frames a focus scope waits for its default to be ready for the engine (see pushScope)
local SETTLE_FRAMES = 10

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

-- The ring's strokes, sharp at the edge first, then softer further in; drawn over the element's
-- own outline (ZIndex RING_Z down)
local RING_PARTS = { "ui-focus-ring", "ui-focus-feather", "ui-focus-halo" }
local RING_Z = 10
-- How many frames a new ring waits for its style before it shows anyway
local RING_STYLE_FRAMES = 30

--[[
	The ring's strokes, made once and moved to whatever has focus. A new stroke takes a few frames
	to get its style, and shows as a thin black line until then; a stroke moved from one element
	to another keeps its style. So the strokes start off (Enabled is not styled, so code owns it)
	and turn on once styled, and are only made again when what held them was destroyed.
]]
function InputManager._ringStrokes(self: InputManager): { UIStroke }
	local ring = self._ring
	if ring then
		local alive = true
		for _, stroke in ring do
			if stroke.Parent == nil then
				alive = false
			end
		end
		if alive then
			return ring
		end
		for _, stroke in ring do
			stroke:Destroy()
		end
	end
	local made = {}
	for index, tag in RING_PARTS do
		local stroke = Instance.new("UIStroke")
		stroke.Name = "LucyFocusRing"
		stroke.Enabled = false
		stroke.ZIndex = RING_Z - index + 1
		stroke:AddTag("ui-focus-ring-part")
		stroke:AddTag(tag)
		table.insert(made, stroke)
	end
	self._ring = made
	self._ringStyled = false
	return made
end

-- Whether the ring's style has reached its strokes: the sharp ring is past a default stroke's 1 px,
-- or the halo is see through
local function styled(ring: { UIStroke }): boolean
	local thickness = ring[1]:GetStyled("Thickness")
	local clear = ring[#ring]:GetStyled("Transparency")
	return (type(thickness) == "number" and thickness ~= 1) or (type(clear) == "number" and clear > 0)
end

function InputManager._showRing(self: InputManager, ring: { UIStroke })
	if self._ringStyled then
		for _, stroke in ring do
			stroke.Enabled = true
		end
		return
	end
	task.spawn(function()
		local frames = 0
		while frames < RING_STYLE_FRAMES and self._ring == ring and not styled(ring) do
			frames += 1
			RunService.Heartbeat:Wait()
		end
		if self._ring ~= ring then
			return
		end
		self._ringStyled = true
		if self._ringOn then
			for _, stroke in ring do
				stroke.Enabled = true
			end
		end
	end)
end

function InputManager._dropRing(self: InputManager)
	self._ringOn = false
	local ring = self._ring
	if ring then
		for _, stroke in ring do
			stroke.Enabled = false
		end
	end
end

-- Puts the ring's strokes in `object`, unless it rings one part instead (ui-ring-host) or Lucy
-- did not build it (app.selectionRing rings that)
function InputManager._drawRing(self: InputManager, object: GuiObject)
	local blank = self.app.selectionImage
	if object:HasTag("ui-ring-host") or blank == nil or object.SelectionImageObject ~= blank then
		self:_dropRing()
		return
	end
	local ring = self:_ringStrokes()
	for _, stroke in ring do
		stroke.Parent = object
	end
	self._ringOn = true
	self:_showRing(ring)
end

function InputManager._clearRing(self: InputManager)
	local focused = self._focused
	if focused and focused.Parent then
		focused:RemoveTag("ui-focus-visible")
	end
	self:_dropRing()
end

-- Records `object` as focused and shows the ring if the player is navigating.
function InputManager.markFocus(self: InputManager, object: GuiObject?)
	local previous = self._focused
	if previous and previous ~= object then
		previous:RemoveTag("ui-focus-visible")
	end
	-- Whether what had focus was in the game when it took focus: only then can it be removed
	local wasLive = self._focusLive
	self._focused = object
	self._focusLive = object ~= nil and object:IsDescendantOf(game)
	self._focusRef(object)
	if object then
		self._lastFocused = object
	end
	if object and self:isNavigating() then
		object:AddTag("ui-focus-visible")
		if object ~= previous or not self._ringOn then
			self:_drawRing(object)
		end
		-- The engine scrolls to the gamepad selection, but not to focus Lucy moves.
		Scroll.reveal(object)
	else
		self:_dropRing()
	end
	-- Tiles: a closed one takes focus that lands inside it, an open one closes when focus leaves
	if object ~= previous then
		Tiles.landed(self, object, previous)
		self:_followScope(object, previous, wasLive)
	end
end

--[[
	Keeps the top focus scope's `holds` (focus was last inside it) and tells the player leaving
	the scope from what had focus there being removed: a list filtered under the focus, a panel
	dropping its content as it closes. The engine then selects nothing, or whatever is nearest,
	which can be outside the scope. A removal marks the scope `orphaned`: if the scope pops it
	gives focus back as if it still had it, else focus goes to its default on the next frame
	(once what replaces the removed control exists), unless the engine found something inside.
]]
-- selene: allow(unused_variable)
function InputManager._followScope(
	self: InputManager,
	object: GuiObject?,
	previous: GuiObject?,
	wasLive: boolean
)
	local scope = self:topScope()
	if not scope then
		return
	end
	local root = scope.root
	local removed = previous ~= nil and wasLive and scope.holds == true and not previous:IsDescendantOf(game)
	if not removed then
		if object then
			scope.holds = object:IsDescendantOf(root)
		end
		return
	end
	if self._returning or scope.orphaned or not self:isNavigating() then
		return
	end
	scope.orphaned = true
	local tries = 0
	local function recover()
		if not scope.orphaned then
			return
		end
		if self._scopes[#self._scopes] ~= scope or not self:isNavigating() then
			scope.orphaned = nil
			return
		end
		local focused = self:_usable(self._focused)
		if focused and focused:IsDescendantOf(root) and GuiService.SelectedObject == focused then
			scope.orphaned = nil
			return
		end
		self._returning = true
		if not (focused and focused:IsDescendantOf(root)) then
			self._holding = true
			self:focusDefault()
			self._holding = false
		end
		-- The scope's default may not be there yet (what replaces a filtered list comes a frame
		-- later) or not laid out: then nothing is selected until it is
		local target = self:_usable(self._focused)
		local ready = target ~= nil
			and target:IsDescendantOf(root)
			and target.AbsoluteSize.X > 0
			and target.AbsoluteSize.Y > 0
		self:focus(if ready then target else nil)
		self._returning = false
		if ready or tries >= SETTLE_FRAMES then
			scope.orphaned = nil
		else
			tries += 1
			task.delay(0, recover)
		end
	end
	task.delay(0, recover)
end

-- What has focus, for bindings: a tracked getter (read only)
function InputManager.focusRef(self: InputManager): () -> GuiObject?
	local ref = self._focusRef
	return function(): GuiObject?
		return ref()
	end
end

-- Selects `object` for gamepad/keyboard navigation (no-op where the engine refuses).
function InputManager.focus(self: InputManager, object: GuiObject?)
	-- The engine refuses what is not shown, with a warning in the output. So something still
	-- hidden is recorded here and not handed to the engine, and so is a focus scope's default on
	-- the frame the scope opens (_holding); the scope hands it over once it is ready (pushScope).
	if object == nil or (not self._holding and isShown(object)) then
		pcall(function()
			GuiService.SelectedObject = object
		end)
	end
	self:markFocus(object)
end

-- Scopes ---------------------------------------------------------------------

function InputManager.pushScope(self: InputManager, scope: Scope): () -> ()
	local previous = self._focused
	-- Where the focus was, for when it can't go back to the same object.
	local previousAt: Vector2? = if previous
		then previous.AbsolutePosition + previous.AbsoluteSize / 2
		else nil
	table.insert(self._scopes, scope)
	if self:isNavigating() then
		-- On the frame a panel opens its controls are hidden, or shown but not laid out, and the
		-- engine refuses them with a warning in the output. So the default is only recorded now,
		-- and handed to the engine below, once it is shown and has a size.
		self._holding = true
		self:focusDefault()
		self._holding = false
		local tries = 0
		local function settle()
			if self._scopes[#self._scopes] ~= scope or not self:isNavigating() then
				return
			end
			local root = scope.root
			local focused = self._focused
			-- Roblox can undo a selection made as a panel first shows and put it back where it was:
			-- select the default again if focus ended up outside
			if root and not (focused and focused.Parent and focused:IsDescendantOf(root)) then
				self._holding = true
				self:focusDefault()
				self._holding = false
				focused = self._focused
			end
			if not focused or GuiService.SelectedObject == focused then
				return
			end
			local size = focused.AbsoluteSize
			-- The engine drops a selection off the screen: wait for the scope's panel to be placed
			local placed = scope.ready == nil or scope.ready()
			if placed and isShown(focused) and size.X > 0 and size.Y > 0 then
				self:focus(focused)
			elseif tries < SETTLE_FRAMES then
				tries += 1
				task.delay(0, settle)
			end
		end
		task.delay(0, settle)
	end
	return function()
		local index = table.find(self._scopes, scope)
		if index then
			table.remove(self._scopes, index)
		end
		local focused = self._focused
		-- What had focus in the scope was removed before the scope popped (a panel that drops its
		-- content as it closes): the focus is still this scope's to give back
		local orphaned = scope.orphaned == true
			or (
				focused ~= nil
				and self._focusLive
				and scope.holds == true
				and not focused:IsDescendantOf(game)
			)
		scope.orphaned = nil
		if orphaned or (focused and scope.root and focused:IsDescendantOf(scope.root)) then
			self._returning = true
			self:focus(nil)
			if scope.returnFocus ~= false and self:isNavigating() then
				local back = self:_usable(scope.returnFocus)
					or self:_usable(previous)
					or (previousAt and self:_nearest(previousAt))
				if back then
					self:focus(back)
				else
					self:focusDefault()
				end
			end
			self._returning = false
		end
	end
end

function InputManager.topScope(self: InputManager): Scope?
	return self._scopes[#self._scopes]
end

-- Lets go of focus on something no longer shown (its panel closed under it)
function InputManager.dropHidden(self: InputManager)
	local focused = self._focused
	if focused and (not focused.Parent or not isShown(focused)) then
		self:focus(nil)
	end
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
			-- A closed tile is one stop: what is in it waits until the player steps in
			and not Tiles.closedAround(descendant, root)
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

-- The control in the top scope whose centre is nearest `point`.
function InputManager._nearest(self: InputManager, point: Vector2): GuiObject?
	local best: GuiObject? = nil
	local bestDistance = math.huge
	for _, root in self:_scopeRoots() do
		for _, object in self:selectables(root) do
			local distance = (object.AbsolutePosition + object.AbsoluteSize / 2 - point).Magnitude
			if distance < bestDistance then
				best, bestDistance = object, distance
			end
		end
	end
	return best
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
	-- A component whose root is never selectable (a NumberField's frame): its
	-- first part that is. A target that is only not shown yet (a dialog opening)
	-- is kept.
	if typeof(target) == "Instance" and target:IsA("GuiObject") and not (target :: GuiObject).Selectable then
		target = self:selectables(target)[1] or target
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

-- The object `object` names for an arrow (`direction`, from ARROWS) in its NextSelection*
-- (a fan menu walks its own order this way); nil when it names none. The engine follows them for
-- the D-pad; keyboard arrows follow them here.
function InputManager.linked(_self: InputManager, object: GuiObject, direction: Vector2): GuiObject?
	local linked = if direction.Y < 0
		then object.NextSelectionUp
		elseif direction.Y > 0 then object.NextSelectionDown
		elseif direction.X < 0 then object.NextSelectionLeft
		else object.NextSelectionRight
	return linked
end

-- The object focus was last moved to, if any.
function InputManager.focused(self: InputManager): GuiObject?
	return self._focused
end

--[[
	The shoulder buttons (LB / RB): from the focused object up, the first
	component with a `shoulder(step)` method that returns true handles them, so
	only the tabs around the focus switch, the innermost first. Returns whether
	anything did. Up is the component tree (Core/Parts): a Tabs' bar in a Sheet's
	header goes up to its Tabs.
]]
function InputManager.shoulder(self: InputManager, step: number): boolean
	local node: Instance? = self._focused
	while node do
		local id = node:GetAttribute("LucyId")
		local handle: any = id and self.app:handle(id)
		if handle and handle.shoulder and handle:shoulder(step) then
			return true
		end
		node = Parts.parent(self.app, node)
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
		node = Parts.parent(self.app, node)
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
		return
	elseif handle and handle.toggle then
		handle:toggle()
		return
	end
	-- A part built with [Lucy.on "Activated"] (a Select row, a radio option, a
	-- sortable header): what a click on it runs.
	local onActivated = Element.activator(focused)
	if onActivated then
		onActivated()
		return
	end
	-- A part of a component (a header, a row): from the focused object up, the
	-- first component with a `press(object)` method that returns true takes it.
	local node: Instance? = focused
	while node do
		local nodeId = node:GetAttribute("LucyId")
		local owner: any = nodeId and self.app:handle(nodeId)
		if owner and owner.press and owner:press(focused) then
			return
		end
		node = Parts.parent(self.app, node)
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

-- A key the player pressed: goes back if it is a back key. Backspace is left
-- to a TextBox being typed in. Returns whether something went back.
function InputManager.keyBack(self: InputManager, key: Enum.KeyCode): boolean
	if not table.find(self._backKeys, key) then
		return false
	end
	if key == Enum.KeyCode.Backspace and UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	return self:back()
end

-- Puts focus back after something outside Lucy (the Roblox menu) cleared it:
-- the last focused object if it can still take focus inside the top scope,
-- else the default focus. Only while navigating with keys or a gamepad.
function InputManager.restoreFocus(self: InputManager)
	if not self:isNavigating() or self._focused ~= nil then
		return
	end
	local last = self:_usable(self._lastFocused)
	local top = self:topScope()
	if last and top and top.root and not last:IsDescendantOf(top.root) then
		last = nil
	end
	if last then
		self:focus(last)
	else
		self:focusDefault()
	end
end

-- Engine wiring --------------------------------------------------------------

function InputManager._watch(self: InputManager)
	local maid = self.maid

	maid:give(UserInputService.LastInputTypeChanged:Connect(function(inputType)
		self:inputUsed(inputType)
	end))

	maid:give(GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		self:markFocus(GuiService.SelectedObject)
	end))

	-- A panel closed under the focus: let go of it a moment later (a few checks a second). In
	-- any input mode: a hidden selection still keeps the keys for UI navigation, so the character
	-- would stand still
	local untilCheck = 0
	maid:give(RunService.Heartbeat:Connect(function(dt: number)
		untilCheck -= dt
		if untilCheck > 0 then
			return
		end
		untilCheck = 0.2
		if self._focused then
			self:dropHidden()
		end
	end))

	maid:give(GuiService.MenuClosed:Connect(function()
		-- The menu is still closing on this frame; select once it has gone.
		task.defer(function()
			self:restoreFocus()
		end)
	end))

	local function refreshCaps()
		self:setCaps(InputManager._readCaps())
	end
	maid:give(UserInputService.GamepadConnected:Connect(refreshCaps))
	maid:give(UserInputService.GamepadDisconnected:Connect(refreshCaps))
	local camera = Workspace.CurrentCamera
	if camera then
		maid:give(camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshCaps))
	end

	maid:give(UserInputService.InputBegan:Connect(function(input, processed)
		local key = input.KeyCode
		if self:keyBack(key) then
			return
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
		if processed and key ~= Enum.KeyCode.Tab and not self:_heldByLucy(key) then
			return
		end
		if key == Enum.KeyCode.Tab then
			self:setMode("keyboard")
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			self:move(if shift then -1 else 1)
		elseif self._mode == "keyboard" and self._focused then
			local linked = arrow and self:linked(self._focused, arrow)
			if linked then
				self:focus(linked)
			elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.Right then
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

	maid:give(RunService.RenderStepped:Connect(function(dt)
		self:_stickScroll(dt)
	end))
	maid:give(function()
		if self._stickSunk then
			self._stickSunk = false
			ContextActionService:UnbindAction(STICK_SINK)
		end
	end)

	maid:give(UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			self._rightStick = Vector2.zero
		end
		local held = self._held
		if held and input.KeyCode == held.key then
			self:_letGo()
		end
	end))

	maid:give(UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			self._rightStick = Vector2.new(input.Position.X, input.Position.Y)
			return
		end
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

-- The right stick, each frame: sinks it while focus is in something it can scroll, scrolls that,
-- and moves focus scrolled out of view to the control nearest it that shows
function InputManager._stickScroll(self: InputManager, dt: number)
	local focused = self._focused
	local live = focused ~= nil and self._mode == "gamepad" and focused:IsDescendantOf(game)
	local scrollable = live
		and focused ~= nil
		and (Scroll.along(focused, "Y") ~= nil or Scroll.along(focused, "X") ~= nil)
	if scrollable ~= self._stickSunk then
		self._stickSunk = scrollable
		if scrollable then
			ContextActionService:BindActionAtPriority(STICK_SINK, function()
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 1000, Enum.KeyCode.Thumbstick2)
		else
			ContextActionService:UnbindAction(STICK_SINK)
		end
	end
	if not scrollable or focused == nil or self._rightStick.Magnitude < Scroll.stickDeadzone then
		return
	end
	for _, frame in Scroll.byStick(focused, self._rightStick, dt) do
		self:_keepInView(frame)
	end
end

-- Focus that `frame` scrolled out of view goes to the control in it nearest where it was that
-- shows whole (with reveal's margin, so focusing it does not scroll back)
function InputManager._keepInView(self: InputManager, frame: ScrollingFrame)
	local focused = self._focused
	if not focused or not focused:IsDescendantOf(frame) then
		return
	end
	-- the margin only along the ways it scrolls: a list's controls sit flush with its sides
	local margin = Vector2.new(
		if frame.AbsoluteCanvasSize.X > frame.AbsoluteSize.X then 8 else 0,
		if frame.AbsoluteCanvasSize.Y > frame.AbsoluteSize.Y then 8 else 0
	)
	local low = frame.AbsolutePosition + margin
	local high = frame.AbsolutePosition + frame.AbsoluteWindowSize - margin
	local function shows(object: GuiObject): boolean
		local a, b = object.AbsolutePosition, object.AbsolutePosition + object.AbsoluteSize
		return a.X >= low.X - 0.5 and a.Y >= low.Y - 0.5 and b.X <= high.X + 0.5 and b.Y <= high.Y + 0.5
	end
	if shows(focused) then
		return
	end
	local centre = focused.AbsolutePosition + focused.AbsoluteSize / 2
	local best: GuiObject? = nil
	local bestDistance = math.huge
	for _, object in self:selectables(frame) do
		if shows(object) then
			local distance = (object.AbsolutePosition + object.AbsoluteSize / 2 - centre).Magnitude
			if distance < bestDistance then
				best, bestDistance = object, distance
			end
		end
	end
	if best then
		self:focus(best)
	end
end

--[[
	True if `key` arrives processed only because Lucy's own movement block sinks it
	(app.actions), so navigation still reads it inside a modal. Old default controls
	only. TODO(remove): delete with the old default controls (the
	Workspace.PlayerScriptsUseInputActionSystem setting, due mid 2027); see
	Actions._defineMovement.
]]
function InputManager._heldByLucy(self: InputManager, key: Enum.KeyCode): boolean
	local actions = self.app.actions
	return actions ~= nil and actions:_sinks(key)
end

function InputManager.destroy(self: InputManager)
	self._held = nil
	self._nudged = false
	self:_clearRing()
	local ring = self._ring
	self._ring = nil
	if ring then
		for _, stroke in ring do
			stroke:Destroy()
		end
	end
	self.maid:clean()
	self._scopes = {}
	self._back = {}
end

return InputManager
