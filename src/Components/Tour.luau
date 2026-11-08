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
			text = { next = "NEXT", skip = "SKIP", confirm = "Are you sure?", yes = "YES", no = "NO" },
			pointer = { variant = "arrow" },      -- Lucy.Arrow props for every step, or false for none
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
		         activated, toggled or selected (silenced ones too, and ones the press
		         hides or removes, such as a button that shuts its own panel)
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
		pointer  Lucy.Arrow props for this step (over the tour's), or false for no arrow

	While a step's target is shown, the tour layer (the "tour" portal, above dialogs and
	below toasts) blocks every press outside it with four buttons, dims the screen but
	for the target, rings it, points a callout at it and keeps gamepad focus on it. Until
	the target is shown the tour waits and draws and blocks nothing. A Lucy.Arrow
	(tour.pointer) points at the target from the side away from the callout.

	Motion: the cut-out and callout glide from one target to the next, the callout
	fades and slides in, a ring ripples out from the target, and the arrow grows in
	and bounces. With reduced motion the tour jumps between targets, the callout
	only fades and the ripple is off (the arrow fades in and stays still).

	SKIP and back ask first, in the callout (Lucy.InlineConfirm): "Are you sure?"
	YES skips, NO (or back again) goes back to the step. With skippable = false,
	back does nothing while a step is shown.

	With progress, the tour writes { step = n } there as it goes, and { finished = "done" }
	or { finished = "skipped" } at the end. One tour runs at a time; the app publishes
	tour = { id, step, index, waiting } while one runs.

	Parts: tour.root, tour.blockers (top, bottom, left, right), tour.ring, tour.pulse,
	tour.callout, tour.arrow (the callout's notch), tour.cover (fades the callout in),
	tour.pointer (Lucy.Arrow), tour.title, tour.text, tour.hint (Kbd), tour.next and
	tour.skipButton (Buttons), tour.confirm (Lucy.InlineConfirm).
]]

local RunService = game:GetService("RunService")

local Arrow = require(script.Parent.Arrow)
local Button = require(script.Parent.Button)
local Element = require(script.Parent.Parent.Core.Element)
local InlineConfirm = require(script.Parent.InlineConfirm)
local Kbd = require(script.Parent.Kbd)
local Maid = require(script.Parent.Parent.Core.Maid)
local Overlay = require(script.Parent.Parent.Core.Overlay)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local UiEvents = require(script.Parent.Parent.Core.UiEvents)

local Tour = {}
Tour.__index = Tour

Tour.defaults = { pad = 8, width = 300, arrow = 12, gap = 6 }
Tour.text = { next = "NEXT", skip = "SKIP", confirm = "Are you sure?", yes = "YES", no = "NO" }
-- Seconds: the glide between targets, the callout's entrance, one ripple of the ring.
Tour.timing = { glide = 0.3, enter = 0.25, pulse = 1.2 }
-- Pixels: how far the callout slides in, how far the ripple spreads, the gap
-- between the pointer's tip and the cut-out.
Tour.motion = { slide = 8, ripple = 14, pointerGap = 4 }
Tour.pointer = { variant = "arrow", motion = "bounce", size = "md", color = "Ring", icon = "" }
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
		selector = ".ui-tour-cover",
		priority = 0,
		properties = { BackgroundColor3 = "$Popover", BorderSizePixel = 0 },
	},
	{ selector = ".ui-tour-cover::UICorner", priority = 0, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-tour-callout >> .ui-inline-confirm-question",
		priority = 1,
		properties = { TextColor3 = "$PopoverForeground" },
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
	local scrim = Reactive.ref(true)

	self._index, self._running, self._waiting = index, running, waiting
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
		return self.confirm ~= nil and self.confirm.asking()
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

		-- A ripple out from the ring. Its stroke is its own (not a style rule), so
		-- its transparency can change every frame; its colour follows the theme.
		local themeTick = Reactive.ref(0)
		local themeConn = app.theme.Changed:Connect(function()
			themeTick(themeTick() + 1)
		end)
		Reactive.onCleanup(function()
			themeConn:Disconnect()
		end)
		self._pulseStroke = Element.new("UIStroke", {
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = function(): Color3
				themeTick()
				local ring = app.theme:resolve("Ring")
				return if typeof(ring) == "Color3" then ring else Color3.new(1, 1, 1)
			end,
		}) :: UIStroke
		self.pulse = Element.new("Frame", {
			Name = "Pulse",
			ZIndex = 2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			Element.new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			self._pulseStroke,
		}) :: Frame

		self.pointer = Arrow.new({ app = app, visible = false })
		self.pointer.Instance.ZIndex = 3

		self.cover = Element.new("Frame", {
			Name = "Cover",
			ZIndex = 5,
			Active = false,
			BackgroundTransparency = 1,
			Tags = { "ui-tour-cover" },
		}) :: Frame

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
				self.confirm:ask()
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
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		}) :: Frame

		-- SKIP and back ask here: the step's words step aside for "Are you sure?".
		self.confirm = InlineConfirm.new({
			app = app,
			question = text.confirm,
			yes = text.yes,
			no = text.no,
			-- NO is the solid one: the tour would rather the player stayed
			yesVariant = "outline",
			noVariant = "default",
			children = { self.title, self.text, footer },
			Parent = self.callout,
			onYes = function()
				self:skip()
			end,
		})

		self.root = Element.new("Frame", {
			Name = "Tour",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = function()
				return running() and not waiting()
			end,
			self.blockers.top,
			self.blockers.bottom,
			self.blockers.left,
			self.blockers.right,
			self.ring,
			self.pulse,
			self.pointer.Instance,
			self.arrow,
			self.callout,
			self.cover,
			Parent = portal,
		}) :: Frame
	end)
	return self
end

-- Placement ------------------------------------------------------------------

-- Lays the layer out around `target` (or centred with none). Rects are in the
-- root's own (unscaled) pixels; the blockers are written in shares of it.
function Tour._layout(self: any, step: Step, target: GuiObject?)
	local root: Frame = self.root
	local still = Preferences.reducedMotion()
	local since = os.clock() - (self._enterAt or 0)
	local function eased(seconds: number): number
		local p = math.clamp(since / seconds, 0, 1)
		return 1 - (1 - p) ^ 3
	end
	-- The callout's entrance: 0 just shown, 1 settled.
	local enter = eased(Tour.timing.enter)
	self.cover.BackgroundTransparency = enter
	self.cover.Visible = enter < 1
	self.arrow.BackgroundTransparency = 1 - enter
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
		self.pulse.Visible = false
		self.arrow.Visible = false
		self.pointer:set("visible", false)
		self._drawn = nil
		self.callout.AnchorPoint = Vector2.new(0.5, 0.5)
		self.callout.Position = UDim2.fromScale(0.5, 0.5)
		self:_cover()
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
	-- Glide from where the last step's cut-out was.
	local from = self._from
	if from and not still then
		local e = eased(Tour.timing.glide)
		if e < 1 then
			min = from.min:Lerp(min, e)
			max = from.max:Lerp(max, e)
		end
	end
	self._drawn = { min = min, max = max }

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

	-- The ripple: spreads out from the ring and fades, again and again.
	if still then
		self.pulse.Visible = false
	else
		local q = (since % Tour.timing.pulse) / Tour.timing.pulse
		local spread = math.round(q * Tour.motion.ripple)
		self.pulse.Visible = true
		self.pulse.Position = UDim2.fromOffset(min.X - spread, min.Y - spread)
		self.pulse.Size = UDim2.fromOffset(max.X - min.X + spread * 2, max.Y - min.Y + spread * 2)
		self._pulseStroke.Transparency = q
	end

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
	-- It slides in from the target's side (it only fades with reduced motion).
	local slide = if still then 0 else math.round((1 - enter) * Tour.motion.slide)
	local toward = ({
		top = Vector2.new(0, 1),
		bottom = Vector2.new(0, -1),
		left = Vector2.new(1, 0),
		right = Vector2.new(-1, 0),
	})[at.side or "bottom"] or Vector2.zero
	-- By scale, as the blockers are: Roblox caps a frame's automatic height at the room left
	-- below its offset position (and works that room out wrongly under a UIScale), which cut a
	-- low callout's text short.
	local placed = at.position + UDim2.fromOffset(toward.X * slide, toward.Y * slide)
	self.callout.Position = UDim2.fromScale(
		placed.X.Scale + placed.X.Offset / whole.X,
		placed.Y.Scale + placed.Y.Offset / whole.Y
	)
	self:_cover()

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
	self.arrow.Position = UDim2.fromOffset(point.X + toward.X * slide, point.Y + toward.Y * slide)

	self:_point(step, min, max, side, whole)
end

-- The cover sits over the callout and fades away as it comes in.
function Tour._cover(self: any)
	local callout: Frame = self.callout
	local scale = Scroll.scaleOf(self.root)
	if scale <= 0 then
		scale = 1
	end
	self.cover.AnchorPoint = callout.AnchorPoint
	self.cover.Position = callout.Position
	self.cover.Size = UDim2.fromOffset(callout.AbsoluteSize.X / scale, callout.AbsoluteSize.Y / scale)
end

-- The pointer's props for a step: Arrow defaults, then the tour's, then the step's.
function Tour._pointerProps(self: any, step: Step): { [string]: any }?
	if step.target == nil or step.pointer == false or self.options.pointer == false then
		return nil
	end
	local props = table.clone(Tour.pointer)
	for _, layer in { self.options.pointer, step.pointer } do
		if type(layer) == "table" then
			for key, value in layer do
				props[key] = value
			end
		end
	end
	return props
end

-- Points the arrow at the cut-out from the side away from the callout (the callout
-- side is `side`), or from the left or right when that side has no room.
function Tour._point(self: any, step: Step, min: Vector2, max: Vector2, side: string, whole: Vector2)
	local pointer = self.pointer
	if self:_pointerProps(step) == nil then
		pointer:set("visible", false)
		return
	end
	local length = pointer.Instance.Size.X.Offset * (1 + Arrow.travel) + Tour.motion.pointerGap
	local gap = Tour.motion.pointerGap
	local centre = (min + max) / 2
	local room = {
		down = min.Y - length >= 0,
		up = max.Y + length <= whole.Y,
		right = min.X - length >= 0,
		left = max.X + length <= whole.X,
	}
	local away = ({ bottom = "down", top = "up", left = "left", right = "right" })[side] or "down"
	local direction = if room[away]
		then away
		elseif room.right then "right"
		elseif room.left then "left"
		else nil
	if direction == nil then
		pointer:set("visible", false)
		return
	end
	local tip = if direction == "down"
		then Vector2.new(centre.X, min.Y - gap)
		elseif direction == "up" then Vector2.new(centre.X, max.Y + gap)
		elseif direction == "right" then Vector2.new(min.X - gap, centre.Y)
		else Vector2.new(max.X + gap, centre.Y)
	if pointer:get("direction") ~= direction then
		pointer:set("direction", direction)
	end
	pointer.Instance.Position = UDim2.fromOffset(math.round(tip.X), math.round(tip.Y))
	if not pointer:get("visible") then
		pointer:set("visible", true)
	end
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
	-- The target as last drawn: a press that hides or removes it (a button that shuts its own
	-- panel) still lands on what the player was shown.
	local lastTarget: GuiObject? = nil
	self.confirm:cancel()
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
			local target = resolve(app, step.target) or lastTarget
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
		if not shownOnce then
			-- The entrance and glide start now, from the last cut-out drawn.
			self._enterAt = os.clock()
			self._from = self._drawn
			local props = self:_pointerProps(step)
			if props then
				props.visible = nil
				self.pointer:set(props)
				self.pointer:replay()
			end
		end
		lastTarget = target
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
		if app.input:isNavigating() then
			local asking = Reactive.untrack(self.confirm.asking)
			local rest = if asking then self.confirm.no.Instance else self:_focusTarget(step, target)
			local focused = app.input:focused()
			local free = if asking then false else inside(focused, target or rest)
			if rest and not free and not inside(focused, self.callout) then
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
		if Reactive.peek(self._waiting) then
			return false
		end
		if self.options.skippable ~= false then
			self.confirm:ask()
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
	self.confirm:cancel()
	self.pointer:set("visible", false)
	self._drawn, self._from = nil, nil
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
