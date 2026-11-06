--!strict
--[[
	Tour (ADR 0038): a guided walk through the game's own UI, one step at a time.

		local tour = Lucy.Tour.new(app, {
			id = "first-show",
			steps = {
				{ id = "menu", target = "hud-menu", text = "Tap the menu to get started.", side = "top" },
				{ id = "join", target = "menu-signup", text = "Join the show.",
				  waitFor = { state = "server.me.competition.signedUp", equals = true } },
				{ id = "hi", text = "Hey, I'm Lucy!" },          -- no target: centred, waits for NEXT
			},
			progress = "save.tours.first-show",  -- optional state path the game persists
			quiet = true,                         -- the default: app.quiet for the run, allowing "tour"
			skippable = true,
			text = { next = "NEXT", skip = "SKIP", confirm = "Skip the tour?", keepGoing = "KEEP GOING" },
			onStep = function(step, index) end,   -- a step is on screen (play its voice line here)
			onDone = function() end,
			onSkip = function() end,
		})
		tour:start(at?)   -- resumes from progress; false for a finished tour unless `at` is given
		tour:advance()  tour:skip()  tour:stop()  tour:destroy()
		tour.index()  tour.step()  tour.running()  tour.waiting()  tour.confirming()   -- tracked

	A step:
		id, text, title
		target   a LucyId, a GuiObject, a handle or a getter returning one; none: centred text
		waitFor  "press" (the default with a target): the target, or a component in it, is
		         activated, toggled or selected (silenced ones too)
		         "next" (the default without one): the callout's NEXT button
		         { action = name }                      an app.actions action is pressed
		         { state = path, equals = value }       a state key equals a value
		         { state = path, where = fn(value) }    a state key passes a test
		         { when = getter }                      any tracked condition
		         A condition that already holds advances at once.
		side     auto | top | bottom | left | right: where the callout sits (auto: where it fits)
		action   an action whose keys show as a key cap in the callout
		scrim    false: no dimming (presses outside the target are still blocked)
		pad      the cut-out's margin around the target (8)

	While a step's target is shown, the tour layer (the "tour" portal, above dialogs and
	below toasts) blocks every press outside it with four buttons, dims the screen but
	for the target, rings it, points a callout at it and keeps gamepad focus on it. Until
	the target is shown the tour waits and draws and blocks nothing.

	Back asks to skip: a "Skip the tour?" dialog, KEEP GOING first. The tour layer hides
	while it is open. With skippable = false, back does nothing while a step is shown.

	With progress, the tour writes { step = n } there as it goes, and { finished = "done" }
	or { finished = "skipped" } at the end. One tour runs at a time; the app publishes
	tour = { id, step, index, waiting } while one runs.

	Parts: tour.root, tour.blockers (top, bottom, left, right), tour.ring, tour.callout,
	tour.arrow, tour.title, tour.text, tour.hint (Kbd), tour.next and tour.skipButton
	(Buttons), tour.confirm (the Dialog).
]]

local RunService = game:GetService("RunService")

local Button = require(script.Parent.Button)
local Dialog = require(script.Parent.Dialog)
local Element = require(script.Parent.Parent.Core.Element)
local Kbd = require(script.Parent.Kbd)
local Maid = require(script.Parent.Parent.Core.Maid)
local Overlay = require(script.Parent.Parent.Core.Overlay)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local UiEvents = require(script.Parent.Parent.Core.UiEvents)

local Tour = {}
Tour.__index = Tour

Tour.defaults = { pad = 8, width = 300, arrow = 12, gap = 6 }
Tour.text = { next = "NEXT", skip = "SKIP", confirm = "Skip the tour?", keepGoing = "KEEP GOING" }
Tour.channel = "tour"
Tour.sides = { "auto", "top", "bottom", "left", "right" }

local PRESS_EVENTS = { activate = true, toggle = true, select = true }

Tour.rules = {
	{
		selector = ".ui-tour-scrim",
		priority = 0,
		properties = {
			BackgroundColor3 = "$Overlay",
			BackgroundTransparency = "$OverlayTransparency",
			BorderSizePixel = 0,
		},
	},
	{
		selector = ".ui-tour-clear",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-tour-ring",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	-- Small: the cut-out is square, so a round ring would leave its corners undimmed
	{ selector = ".ui-tour-ring::UICorner", priority = 0, properties = { CornerRadius = "$RadiusXs" } },
	{
		selector = ".ui-tour-ring::UIStroke",
		priority = 0,
		properties = {
			Color = "$Ring",
			Thickness = "$FocusRing",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-tour-callout",
		priority = 0,
		properties = { BackgroundColor3 = "$Popover", BorderSizePixel = 0 },
	},
	{ selector = ".ui-tour-callout::UICorner", priority = 0, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-tour-callout::UIStroke",
		priority = 0,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-tour-callout::UIPadding",
		priority = 0,
		properties = {
			PaddingTop = "$Space4",
			PaddingBottom = "$Space4",
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
		},
	},
	{
		selector = ".ui-tour-arrow",
		priority = 0,
		properties = { BackgroundColor3 = "$Popover", BorderSizePixel = 0 },
	},
	{
		selector = ".ui-tour-title",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSansSemibold",
			TextSize = "$TextLg",
		},
	},
	{
		selector = ".ui-tour-text",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSans",
			TextSize = "$TextBase",
		},
	},
} :: { any }

export type Step = { [string]: any }

-- Checks a step and fills in its waitFor default.
local function checkStep(step: Step, index: number): Step
	if type(step) ~= "table" then
		error(`[Lucy] Tour step {index} must be a table`, 3)
	end
	if step.text == nil and step.title == nil then
		error(`[Lucy] Tour step {index} needs text or a title`, 3)
	end
	local side = step.side or "auto"
	if not table.find(Tour.sides, side) then
		error(
			`[Lucy] Tour step {index}: unknown side "{side}" (expected {table.concat(Tour.sides, ", ")})`,
			3
		)
	end
	local out = table.clone(step)
	out.side = side
	local wait = step.waitFor
	if wait == nil then
		wait = if step.target ~= nil then "press" else "next"
	end
	if wait == "press" and step.target == nil then
		error(`[Lucy] Tour step {index} waits for a press but has no target`, 3)
	end
	if type(wait) == "table" then
		if not (wait.action or wait.state or wait.when) then
			error(`[Lucy] Tour step {index}: waitFor needs action, state or when`, 3)
		end
	elseif wait ~= "press" and wait ~= "next" then
		error(`[Lucy] Tour step {index}: unknown waitFor "{tostring(wait)}"`, 3)
	end
	out.waitFor = wait
	return out
end

local function isShown(object: GuiObject): boolean
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
	return false
end

-- The step's target now: a GuiObject that is shown, or nil.
local function resolve(app: any, target: any): GuiObject?
	if type(target) == "function" then
		target = target()
	end
	if type(target) == "string" then
		local handle = app:handle(target)
		target = if handle and not handle.destroyed then handle.Instance else nil
	elseif type(target) == "table" then
		target = if target.destroyed then nil else target.Instance
	end
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("GuiObject") then
		return nil
	end
	local object = target :: GuiObject
	if object.AbsoluteSize.X <= 0 or object.AbsoluteSize.Y <= 0 or not isShown(object) then
		return nil
	end
	return object
end

-- The part of `object` not clipped away, in absolute pixels; nil when none is left.
local function visibleRect(object: GuiObject): (Vector2?, Vector2?)
	local min = object.AbsolutePosition
	local max = min + object.AbsoluteSize
	local node = object.Parent
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and (node:IsA("ScrollingFrame") or node.ClipsDescendants) then
			local frame = node :: GuiObject
			local size = if node:IsA("ScrollingFrame")
				then (node :: ScrollingFrame).AbsoluteWindowSize
				else frame.AbsoluteSize
			local fmin = frame.AbsolutePosition
			min = min:Max(fmin)
			max = max:Min(fmin + size)
		end
		node = node.Parent
	end
	if max.X - min.X <= 0 or max.Y - min.Y <= 0 then
		return nil, nil
	end
	return min, max
end

local function inside(object: Instance?, root: Instance): boolean
	return object ~= nil and (object == root or object:IsDescendantOf(root))
end

function Tour.new(app: any, options: { [string]: any })
	assert(type(options) == "table", "[Lucy] Tour.new(app, options)")
	if type(options.id) ~= "string" then
		error("[Lucy] Tour needs an id (a string)", 2)
	end
	if type(options.steps) ~= "table" or #options.steps == 0 then
		error("[Lucy] Tour needs at least one step", 2)
	end
	local steps = {}
	for index, step in options.steps do
		steps[index] = checkStep(step, index)
	end
	local text = table.clone(Tour.text)
	for key, value in options.text or {} do
		text[key] = value
	end

	app.theme:addRules("tour", Tour.rules)

	local self: any = setmetatable({}, Tour)
	self.app = app
	self.id = options.id
	self.options = options
	self.steps = steps

	local index = Reactive.ref(0)
	local running = Reactive.ref(false)
	local waiting = Reactive.ref(true)
	local confirming = Reactive.ref(false)
	local scrim = Reactive.ref(true)

	self._index, self._running, self._waiting, self._confirming = index, running, waiting, confirming
	self._scrim = scrim
	self.index = function(): number
		return index()
	end
	self.running = function(): boolean
		return running()
	end
	self.waiting = function(): boolean
		return waiting()
	end
	self.confirming = function(): boolean
		return confirming()
	end
	self.step = function(): Step?
		return if running() then steps[index()] else nil
	end
	local current = self.step

	local scope = Reactive.effectScope(true)
	self._scope = scope
	scope:run(function()
		local portal = app:portal("tour")
		local function blocker(name: string): TextButton
			local button = Element.new("TextButton", {
				Name = name,
				Text = "",
				AutoButtonColor = false,
				Selectable = false,
				Active = true,
				ZIndex = 1,
				Tags = {
					["ui-tour-scrim"] = function()
						return scrim()
					end,
					["ui-tour-clear"] = function()
						return not scrim()
					end,
				},
			}) :: TextButton
			return button
		end
		self.blockers = {
			top = blocker("BlockTop"),
			bottom = blocker("BlockBottom"),
			left = blocker("BlockLeft"),
			right = blocker("BlockRight"),
		}

		self.ring = Element.new("Frame", {
			Name = "Ring",
			ZIndex = 2,
			Tags = { "ui-tour-ring" },
		})

		self.arrow = Element.new("Frame", {
			Name = "Arrow",
			Rotation = 45,
			ZIndex = 3,
			Size = UDim2.fromOffset(Tour.defaults.arrow, Tour.defaults.arrow),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Tags = { "ui-tour-arrow" },
		})

		self.title = Element.new("TextLabel", {
			Name = "Title",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = function()
				local step = current()
				return if step and step.title then step.title else ""
			end,
			Visible = function()
				local step = current()
				return step ~= nil and step.title ~= nil
			end,
			Tags = { "ui-tour-title" },
		}) :: TextLabel

		self.text = Element.new("TextLabel", {
			Name = "Text",
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = function()
				local step = current()
				return if step and step.text then step.text else ""
			end,
			Visible = function()
				local step = current()
				return step ~= nil and step.text ~= nil
			end,
			Tags = { "ui-tour-text" },
		}) :: TextLabel

		local footer = Element.new("Frame", {
			Name = "Footer",
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Element.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
		}) :: Frame

		self.hint = Kbd.new({
			app = app,
			action = function()
				local step = current()
				return if step and step.action then step.action else ""
			end,
			visible = function()
				local step = current()
				return step ~= nil and step.action ~= nil
			end,
			layoutOrder = 1,
			Parent = footer,
		})

		local spacer = Element.new("Frame", {
			Name = "Spacer",
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 0),
			Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		spacer.Parent = footer

		self.skipButton = Button.new({
			app = app,
			text = text.skip,
			variant = "ghost",
			size = "sm",
			hint = { keyboard = Enum.KeyCode.Backspace, gamepad = Enum.KeyCode.ButtonB },
			visible = options.skippable ~= false,
			layoutOrder = 3,
			Parent = footer,
			onClick = function()
				self:skip()
			end,
		})

		self.next = Button.new({
			app = app,
			text = text.next,
			size = "sm",
			visible = function()
				local step = current()
				return step ~= nil and step.waitFor == "next"
			end,
			layoutOrder = 4,
			Parent = footer,
			onClick = function()
				local step = current()
				if step and step.waitFor == "next" then
					self:advance()
				end
			end,
		})

		self.callout = Element.new("Frame", {
			Name = "Callout",
			ZIndex = 4,
			Size = UDim2.fromOffset(Tour.defaults.width, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Active = true,
			Tags = { "ui-tour-callout" },
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			self.title,
			self.text,
			footer,
		}) :: Frame

		self.root = Element.new("Frame", {
			Name = "Tour",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return running() and not waiting() and not confirming()
			end,
			self.blockers.top,
			self.blockers.bottom,
			self.blockers.left,
			self.blockers.right,
			self.ring,
			self.arrow,
			self.callout,
			Parent = portal,
		}) :: Frame

		self.confirm = Dialog.new({
			app = app,
			title = text.confirm,
			size = "sm",
			showClose = false,
			actions = {
				{ text = text.keepGoing },
				{
					text = text.skip,
					variant = "outline",
					onClick = function()
						self:skip()
					end,
				},
			},
			defaultFocus = function(dialog)
				return dialog.actions[1]
			end,
			onOpenChange = function(open)
				confirming(open)
			end,
		})
	end)
	return self
end

-- Placement ------------------------------------------------------------------

-- Lays the layer out around `target` (or centred with none). Rects are in the
-- root's own (unscaled) pixels; the blockers are written in shares of it.
function Tour._layout(self: any, step: Step, target: GuiObject?)
	local root: Frame = self.root
	local scale = Scroll.scaleOf(root)
	if scale <= 0 then
		scale = 1
	end
	local whole = root.AbsoluteSize / scale
	if whole.X <= 0 or whole.Y <= 0 then
		return
	end
	local blockers = self.blockers

	local function share(x: number, y: number): UDim2
		return UDim2.fromScale(x / whole.X, y / whole.Y)
	end

	if target == nil then
		blockers.top.Position = UDim2.fromScale(0, 0)
		blockers.top.Size = UDim2.fromScale(1, 1)
		blockers.top.Visible = true
		for _, name in { "bottom", "left", "right" } do
			blockers[name].Visible = false
		end
		self.ring.Visible = false
		self.arrow.Visible = false
		self.callout.AnchorPoint = Vector2.new(0.5, 0.5)
		self.callout.Position = UDim2.fromScale(0.5, 0.5)
		return
	end

	local amin, amax = visibleRect(target)
	if amin == nil or amax == nil then
		return
	end
	local origin = root.AbsolutePosition
	local pad = if step.pad ~= nil then step.pad else Tour.defaults.pad
	local min = ((amin - origin) / scale - Vector2.new(pad, pad)):Max(Vector2.zero)
	local max = ((amax - origin) / scale + Vector2.new(pad, pad)):Min(whole)

	blockers.top.Position = UDim2.fromScale(0, 0)
	blockers.top.Size = share(whole.X, min.Y)
	blockers.bottom.Position = share(0, max.Y)
	blockers.bottom.Size = share(whole.X, whole.Y - max.Y)
	blockers.left.Position = share(0, min.Y)
	blockers.left.Size = share(min.X, max.Y - min.Y)
	blockers.right.Position = share(max.X, min.Y)
	blockers.right.Size = share(whole.X - max.X, max.Y - min.Y)
	for _, name in { "top", "bottom", "left", "right" } do
		blockers[name].Visible = true
	end

	self.ring.Visible = true
	self.ring.Position = UDim2.fromOffset(min.X, min.Y)
	self.ring.Size = UDim2.fromOffset(max.X - min.X, max.Y - min.Y)

	-- The callout: the side is picked against the whole cut-out; above or below,
	-- it is then centred on it rather than stretched to its width.
	local width = math.min(Tour.defaults.width, whole.X - Overlay.margin * 2)
	local content = Vector2.new(width, self.callout.AbsoluteSize.Y / scale)
	local gap = Tour.defaults.gap + Tour.defaults.arrow / 2
	local saved = Overlay.gap
	Overlay.gap = gap
	local cut = { position = min, size = max - min }
	local first = Overlay.place("popup", {
		view = whole,
		content = content,
		anchor = cut,
		width = width,
		side = step.side,
		align = "center",
	})
	local at = first
	if first.side == "top" or first.side == "bottom" then
		local centre = (min.X + max.X) / 2
		at = Overlay.place("popup", {
			view = whole,
			content = content,
			anchor = { position = Vector2.new(centre - 0.5, min.Y), size = Vector2.new(1, max.Y - min.Y) },
			width = width,
			side = first.side,
			align = "center",
		})
	end
	Overlay.gap = saved
	self.callout.Size = UDim2.fromOffset(width, 0)
	self.callout.AnchorPoint = at.anchorPoint
	self.callout.Position = at.position

	-- The arrow sits on the callout's near edge, in line with the target's centre.
	local corner = 12
	local side = at.side or "bottom"
	local cx, cy = at.position.X.Offset, at.position.Y.Offset
	local height = content.Y
	local left = cx - at.anchorPoint.X * width
	local top = cy - at.anchorPoint.Y * height
	local centre = (min + max) / 2
	local point: Vector2
	if side == "top" then
		point = Vector2.new(math.clamp(centre.X, left + corner, left + width - corner), top + height)
	elseif side == "bottom" then
		point = Vector2.new(math.clamp(centre.X, left + corner, left + width - corner), top)
	elseif side == "left" then
		point = Vector2.new(left + width, math.clamp(centre.Y, top + corner, top + height - corner))
	else
		point = Vector2.new(left, math.clamp(centre.Y, top + corner, top + height - corner))
	end
	self.arrow.Visible = true
	self.arrow.Position = UDim2.fromOffset(point.X, point.Y)
end

-- Running --------------------------------------------------------------------

function Tour._publish(self: any)
	local step = self.steps[Reactive.peek(self._index)]
	self.app.state:set("tour", {
		id = self.id,
		step = step and step.id,
		index = Reactive.peek(self._index),
		waiting = Reactive.peek(self._waiting),
	})
end

function Tour._save(self: any, value: { [string]: any })
	local path = self.options.progress
	if type(path) == "string" then
		self.app.state:set(path, value)
	end
end

-- The thing focus should rest on for this step.
function Tour._focusTarget(self: any, step: Step, target: GuiObject?): GuiObject?
	if target == nil then
		return if step.waitFor == "next" then self.next.Instance else nil
	end
	if target.Selectable and target.Interactable then
		return target
	end
	return self.app.input:selectables(target)[1]
end

function Tour._showStep(self: any, at: number)
	if self._step then
		self._step:destroy()
		self._step = nil
	end
	local app = self.app
	local step: Step = self.steps[at]
	local live = Maid.new()
	self._step = live
	local shownOnce = false
	self._index(at)
	self._waiting(true)
	self:_save({ step = at })
	self:_publish()

	local function advance()
		if self._step == live then
			self:advance()
		end
	end

	-- What the step waits for.
	local wait = step.waitFor
	local watchers = Reactive.effectScope(true)
	live:give(function()
		watchers:stop()
	end)
	if wait == "press" then
		live:give(UiEvents.observe(app, function(handle, event)
			if not PRESS_EVENTS[event] then
				return
			end
			local target = resolve(app, step.target)
			if target and inside(handle.Instance, target) then
				advance()
			end
		end))
	elseif type(wait) == "table" then
		watchers:run(function()
			if wait.action then
				live:give(app.actions:on(wait.action, advance))
			else
				local test: () -> boolean
				if wait.when then
					test = function()
						return Reactive.toValue(wait.when) == true
					end
				else
					local value = app.state:ref(wait.state)
					test = function()
						local now = value()
						if wait.where then
							return wait.where(now) == true
						end
						return now == wait.equals
					end
				end
				Reactive.watchEffect(function()
					if test() then
						Reactive.untrack(advance)
					end
				end)
			end
		end)
	end
	if self._step ~= live then
		return -- the step was over before it started
	end

	-- What the player sees, every frame.
	local function check()
		if self._step ~= live then
			return
		end
		local target = if step.target ~= nil then resolve(app, step.target) else nil
		local shown = step.target == nil or (target ~= nil and visibleRect(target) ~= nil)
		if shown ~= not Reactive.peek(self._waiting) then
			self._waiting(not shown)
			self:_publish()
		end
		if not shown then
			return
		end
		self:_layout(step, target)
		if not shownOnce then
			shownOnce = true
			if target then
				Scroll.reveal(target)
			end
			if self.options.onStep then
				task.spawn(self.options.onStep, step, at)
			end
		end
		-- Hold focus on the step while the player navigates.
		if app.input:isNavigating() and not Reactive.peek(self._confirming) then
			local rest = self:_focusTarget(step, target)
			local focused = app.input:focused()
			if rest and not inside(focused, target or rest) and not inside(focused, self.callout) then
				app.input:focus(rest)
			end
		end
	end
	self._check = check
	self._scrim(step.scrim ~= false)
	check()
end

function Tour.start(self: any, at: number?): boolean
	local app = self.app
	local first = at
	if first == nil then
		local saved = if type(self.options.progress) == "string"
			then app.state:get(self.options.progress)
			else nil
		if type(saved) == "table" and saved.finished ~= nil then
			return false
		end
		first = if type(saved) == "table" and type(saved.step) == "number" then saved.step else 1
	end
	local index = math.clamp(first :: number, 1, #self.steps)

	local other = app._lucyTour
	if other and other ~= self and Reactive.peek(other._running) then
		other:stop()
	end
	if Reactive.peek(self._running) then
		self:stop()
	end
	app._lucyTour = self

	local run = Maid.new()
	self._run = run
	self._previousFocus = app.input:focused()
	if self.options.quiet ~= false then
		local scope = Reactive.effectScope(true)
		scope:run(function()
			app.quiet:push("tour:" .. self.id, { allow = { Tour.channel } })
		end)
		run:give(function()
			scope:stop()
		end)
	end
	run:give(app.input:pushBack(function(): boolean?
		if Reactive.peek(self._waiting) or Reactive.peek(self._confirming) then
			return false
		end
		if self.options.skippable ~= false then
			self.confirm:open()
		end
		return true
	end))
	local beat = if RunService:IsClient() and RunService:IsRunning()
		then RunService.PreRender
		else RunService.Heartbeat
	run:give(beat:Connect(function()
		if self._check then
			self._check()
		end
	end))

	self._running(true)
	self:_showStep(index)
	return true
end

function Tour.advance(self: any)
	if not Reactive.peek(self._running) then
		return
	end
	local at = Reactive.peek(self._index)
	if at >= #self.steps then
		self:_finish("done")
	else
		self:_showStep(at + 1)
	end
end

function Tour._finish(self: any, how: string?)
	if not Reactive.peek(self._running) then
		return
	end
	if self._step then
		self._step:destroy()
		self._step = nil
	end
	self._check = nil
	if self._run then
		self._run:destroy()
		self._run = nil
	end
	if Reactive.peek(self._confirming) then
		self.confirm:close()
	end
	self._running(false)
	self._waiting(true)
	local app = self.app
	if app._lucyTour == self then
		app._lucyTour = nil
		app.state:set("tour", nil)
	end
	if how then
		self:_save({ finished = how })
	end
	local previous = self._previousFocus
	self._previousFocus = nil
	if app.input:isNavigating() and previous and app.input:_usable(previous) then
		app.input:focus(previous)
	end
	if how == "done" and self.options.onDone then
		self.options.onDone()
	elseif how == "skipped" and self.options.onSkip then
		self.options.onSkip()
	end
end

function Tour.skip(self: any)
	self:_finish("skipped")
end

-- Ends the tour without a callback, keeping its progress where it was.
function Tour.stop(self: any)
	self:_finish(nil)
end

function Tour.destroy(self: any)
	self:stop()
	self._scope:stop()
	if self.root then
		self.root:Destroy()
	end
end

return Tour
