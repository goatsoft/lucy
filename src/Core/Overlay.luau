--!strict
--[[
	Overlay (ADR 0024): the one floating layer that dialogs, sheets and popups
	share. Internal: components call it from their render.

		local overlay = Overlay.use(h.app, {
			open = h:ref("open"),       -- a writable ref; back and outside presses write false
			content = frame,            -- what floats; placed by the overlay
			presentation = "auto",      -- auto | popup | panel | drawer | center
			prefer = "popup",           -- auto off touch: popup | panel (touch is always drawer)
			anchor = trigger,           -- popup: place next to this (an instance, handle or getter)
			side = "bottom",            -- popup: bottom | top, flips when the other has more room
			align = "start",            -- popup: start | center | end
			width = 240,                -- popup: at least this (and the anchor's width); panel: this
			panelSide = "right",        -- panel: left | right
			modal = true,               -- false: no focus trap, presses pass through
			scrim = nil,                -- the dim backdrop; defaults to modal and not a popup
			dismissible = true,         -- back closes it (and outside presses, when modal)
			onBack = nil,               -- runs on back in place of closing (an alert's cancel)
			closeOnOutside = nil,       -- defaults to dismissible when modal, false otherwise
			defaultFocus = fn,          -- what keyboard and gamepad select first
			onClose = fn,               -- (reason) "back" | "outside" | "anchor" | "code"
			parent = nil,               -- defaults to the app's "modal" portal; false leaves it
			id = "settings",            -- shown as overlay.top in app state
			name = "Settings",          -- the root's Name; tags = { ... } adds tags to it
		})
		overlay.root  overlay.scrim  overlay.content
		overlay.presentation()          -- decided each time it opens
		overlay.maxHeight()             -- the height the content may use; bind a ScrollArea to it
		overlay.safeBottom()            -- a drawer's bottom safe area (home bar); leave room for it
		overlay.close(reason?)

	Every overlay stacks by the order it opened, newest on top, whatever its
	kind. While open, modal ones are a focus scope whose selection group stops
	at its edges, and focus returns to the anchor (or whatever had it) when they
	close. The app publishes overlay.count, overlay.modal and overlay.top.
	Placement follows the viewport, the anchor and the content's size while
	open; the presentation does not change until it opens again.

	The dimming fades in when it opens and out when it closes (Overlay.fadeTime,
	through a UIGradient, so the theme rule keeps its colour and transparency).
	The overlay itself hides at once; a short-lived copy of the dimming, named
	ScrimFade, fades out in its place and never takes presses.

	A drawer slides up from the bottom when it opens and back down before it
	hides (Overlay.slideTime; no slide with reduced motion). Its background runs
	to the screen edge; the component leaves safeBottom() of room at its foot
	so nothing sits under a phone's home bar.
]]

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Element)
local Maid = require(script.Parent.Maid)
local Preferences = require(script.Parent.Preferences)
local Reactive = require(script.Parent.Reactive)
local Scroll = require(script.Parent.Scroll)

local Overlay = {}

Overlay.margin = 8 -- popup distance from the viewport edges
Overlay.gap = 4 -- popup distance from its anchor
Overlay.centerMargin = 32
Overlay.drawerShare = 0.85 -- of the viewport height
Overlay.slideTime = 0.2 -- seconds a drawer takes to slide in or out
Overlay.fadeTime = 0.15 -- seconds the dimming takes to fade in or out
Overlay.panelWidth = 360
Overlay.panelShare = 0.9 -- of the viewport width

Overlay.rules = {
	{
		selector = ".ui-overlay",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-overlay-clear",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-overlay-scrim",
		priority = 1,
		properties = {
			BackgroundColor3 = "$Overlay",
			BackgroundTransparency = "$OverlayTransparency",
			BorderSizePixel = 0,
		},
	},
} :: { any }

export type Rect = { position: Vector2, size: Vector2 }

export type PlaceInput = {
	view: Vector2,
	content: Vector2,
	anchor: Rect?,
	width: number?,
	side: string?,
	align: string?,
	panelSide: string?,
}

export type Placement = {
	anchorPoint: Vector2,
	position: UDim2,
	maxHeight: number,
	width: number?,
	widthScale: number?,
	fullHeight: boolean?,
	side: string?,
}

-- The presentation for this opening: touch always gets a drawer; elsewhere the preferred shape.
function Overlay.resolve(presentation: string?, prefer: string?, mode: string?): string
	local p = presentation or "center"
	if p ~= "auto" then
		return p
	end
	if mode == "touch" then
		return "drawer"
	end
	return prefer or "popup"
end

local function centered(view: Vector2): Placement
	return {
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		maxHeight = math.max(0, view.Y - Overlay.centerMargin * 2),
	}
end

-- Where the content goes, in the overlay's own (unscaled) coordinates. Pure.
function Overlay.place(presentation: string, input: PlaceInput): Placement
	local view = input.view
	if presentation == "drawer" then
		return {
			anchorPoint = Vector2.new(0, 1),
			position = UDim2.fromScale(0, 1),
			widthScale = 1,
			maxHeight = math.floor(view.Y * Overlay.drawerShare),
		}
	elseif presentation == "panel" then
		local left = input.panelSide == "left"
		return {
			anchorPoint = Vector2.new(if left then 0 else 1, 0),
			position = UDim2.fromScale(if left then 0 else 1, 0),
			width = math.floor(math.min(input.width or Overlay.panelWidth, view.X * Overlay.panelShare)),
			fullHeight = true,
			maxHeight = view.Y,
		}
	end

	local anchor = input.anchor
	if presentation ~= "popup" or anchor == nil then
		return centered(view)
	end

	local m, gap = Overlay.margin, Overlay.gap
	local top = anchor.position.Y
	local bottom = top + anchor.size.Y
	local below = view.Y - bottom - gap - m
	local above = top - gap - m
	local side = if input.side == "top" then "top" else "bottom"
	local want = input.content.Y
	if side == "bottom" and want > below and above > below then
		side = "top"
	elseif side == "top" and want > above and below > above then
		side = "bottom"
	end

	local width = math.max(input.width or 0, anchor.size.X)
	width = math.max(0, math.min(width, view.X - m * 2))
	local x
	if input.align == "end" then
		x = anchor.position.X + anchor.size.X - width
	elseif input.align == "center" then
		x = anchor.position.X + (anchor.size.X - width) / 2
	else
		x = anchor.position.X
	end
	x = math.clamp(x, m, math.max(m, view.X - width - m))

	local y = if side == "bottom" then bottom + gap else top - gap
	return {
		anchorPoint = Vector2.new(0, if side == "bottom" then 0 else 1),
		position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5)),
		width = width,
		maxHeight = math.max(0, math.floor(if side == "bottom" then below else above)),
		side = side,
	}
end

-- Open overlays per app, oldest first, and what the app publishes about them.
type Entry = { id: string, modal: boolean }

local function entries(app: any): { Entry }
	local list = app._lucyOverlays
	if not list then
		list = {}
		app._lucyOverlays = list
	end
	return list
end

local function publish(app: any)
	local list = entries(app)
	local modal = 0
	for _, entry in list do
		if entry.modal then
			modal += 1
		end
	end
	local top = list[#list]
	Reactive.batch(function()
		app.state:set("overlay.count", #list)
		app.state:set("overlay.modal", modal)
		app.state:set("overlay.top", if top then top.id else nil)
	end)
end

local function forget(app: any, entry: Entry)
	local list = entries(app)
	local index = table.find(list, entry)
	if index then
		table.remove(list, index)
	end
end

local function resolveAnchor(anchor: any): GuiObject?
	local target = anchor
	if type(target) == "function" then
		target = target()
	end
	if type(target) == "table" and target.Instance then
		target = target.Instance
	end
	if typeof(target) == "Instance" and target:IsA("GuiObject") then
		return target
	end
	return nil
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
	return true
end

local function inside(object: GuiObject?, point: Vector2): boolean
	if not object then
		return false
	end
	local p, s = object.AbsolutePosition, object.AbsoluteSize
	return point.X >= p.X and point.Y >= p.Y and point.X <= p.X + s.X and point.Y <= p.Y + s.Y
end

-- The first selectable object under `root` in tree order, judged only by its own
-- visibility up to `root`: the overlay may not be shown yet when focus is pushed.
function Overlay.firstSelectable(root: Instance): GuiObject?
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") and descendant.Selectable and descendant.Interactable then
			local visible = true
			local node: Instance? = descendant
			while node and node ~= root do
				if node:IsA("GuiObject") and not node.Visible then
					visible = false
					break
				end
				node = node.Parent
			end
			if visible then
				return descendant
			end
		end
	end
	return nil
end

-- The newest overlay goes on top (shared by every app: ZIndex is per gui).
local layer = 0

-- One hidden ScreenGui per overlay gui, inset to the device's safe area, to
-- measure how much of the bottom edge a phone keeps (the home bar).
local probes: { [ScreenGui]: ScreenGui } = setmetatable({} :: any, { __mode = "k" })

-- The bottom safe area under `root`, in the overlay's own units (screen pixels
-- divided by `scale`). Studio has none. Specs replace this function.
function Overlay.measureSafeBottom(root: GuiObject, scale: number): number
	local gui = root:FindFirstAncestorWhichIsA("ScreenGui")
	if not gui or not gui.Parent then
		return 0
	end
	local probe = probes[gui]
	if not probe or probe.Parent ~= gui.Parent then
		local made = Instance.new("ScreenGui")
		made.Name = "LucySafeArea"
		made.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		made.IgnoreGuiInset = gui.IgnoreGuiInset
		made.ResetOnSpawn = false
		made.Archivable = false
		made.Parent = gui.Parent
		gui.Destroying:Once(function()
			made:Destroy()
		end)
		probes[gui] = made
		probe = made
	end
	local edge = probe :: ScreenGui
	if edge.AbsoluteSize.Y <= 0 or gui.AbsoluteSize.Y <= 0 then
		return 0
	end
	local inset = (gui.AbsolutePosition.Y + gui.AbsoluteSize.Y)
		- (edge.AbsolutePosition.Y + edge.AbsoluteSize.Y)
	return math.floor(math.clamp(inset, 0, gui.AbsoluteSize.Y / 4) / math.max(scale, 0.01))
end

export type Overlay = {
	root: Frame,
	scrim: GuiObject,
	content: GuiObject,
	presentation: () -> string,
	maxHeight: () -> number,
	safeBottom: () -> number,
	close: (reason: string?) -> (),
}

function Overlay.use(app: any, options: { [string]: any }): Overlay
	if not Reactive._hasOwner() then
		error("[Lucy] Overlay.use needs an owner: call it in a component's render or an effectScope", 2)
	end
	app.theme:addRules("overlay", Overlay.rules)
	if app.state:get("overlay") == nil then
		app.state:set("overlay", { count = 0, modal = 0 })
	end

	local open: Reactive.Ref<boolean> = options.open
	local content: GuiObject = options.content
	local modal = options.modal ~= false
	local dismissible = options.dismissible ~= false
	local closeOnOutside = if options.closeOnOutside ~= nil
		then options.closeOnOutside == true
		else modal and dismissible
	local entry: Entry = { id = options.id or app:nextId("overlay"), modal = modal }

	local function mode(): string
		return if app.input then app.input:mode() else "mouse"
	end
	local presentation = Reactive.ref(Overlay.resolve(options.presentation, options.prefer, mode()))
	local maxHeight = Reactive.ref(math.huge)
	local safeBottom = Reactive.ref(0)
	local zIndex = Reactive.ref(10)
	-- A drawer stays shown while it slides out.
	local closing = Reactive.ref(false)

	local function scrimOn(): boolean
		if options.scrim ~= nil then
			return Reactive.toValue(options.scrim) == true
		end
		return modal and presentation() ~= "popup"
	end

	local scrim = Element.new(if modal then "TextButton" else "Frame", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Active = modal,
		Selectable = false,
		Visible = function()
			return modal or scrimOn()
		end,
		Tags = {
			["ui-overlay-scrim"] = scrimOn,
			["ui-overlay-clear"] = function()
				return not scrimOn()
			end,
		},
	})
	if modal then
		local button = scrim :: any
		button.Text = ""
		button.AutoButtonColor = false
	end

	local root: Frame -- made below, holding the scrim

	-- The dimming fades through a gradient laid over the rule's own transparency.
	local scrimFade = Instance.new("UIGradient")
	scrimFade.Name = "Fade"
	scrimFade.Transparency = NumberSequence.new(0)
	scrimFade.Parent = scrim
	local fadeLevel = Instance.new("NumberValue")
	local fadeConnection = fadeLevel.Changed:Connect(function(value: number)
		scrimFade.Transparency = NumberSequence.new(math.clamp(value, 0, 1))
	end)
	local fadeTween: Tween? = nil
	local function fadeTo(target: number, time: number)
		if fadeTween then
			fadeTween:Cancel()
		end
		local tween =
			TweenService:Create(fadeLevel, TweenInfo.new(time, Enum.EasingStyle.Quad), { Value = target })
		fadeTween = tween
		tween:Play()
	end
	Reactive.onCleanup(function()
		fadeConnection:Disconnect()
		if fadeTween then
			fadeTween:Cancel()
		end
		fadeLevel:Destroy()
	end)

	-- Fades a copy of the dimming out where the overlay was, then removes it.
	local function fadeAfterimage()
		local parent = root.Parent
		if not parent or not scrimOn() then
			return
		end
		local ghost = Instance.new("Frame")
		ghost.Name = "ScrimFade"
		ghost.Size = UDim2.fromScale(1, 1)
		ghost.ZIndex = root.ZIndex
		ghost.Active = false
		ghost.BorderSizePixel = 0
		ghost.BackgroundColor3 = scrim:GetStyled("BackgroundColor3")
		ghost.BackgroundTransparency = scrim:GetStyled("BackgroundTransparency")
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new(math.clamp(fadeLevel.Value, 0, 1))
		gradient.Parent = ghost
		local level = Instance.new("NumberValue")
		level.Value = fadeLevel.Value
		level.Changed:Connect(function(value: number)
			gradient.Transparency = NumberSequence.new(math.clamp(value, 0, 1))
		end)
		ghost.Parent = parent
		local tween =
			TweenService:Create(level, TweenInfo.new(Overlay.fadeTime, Enum.EasingStyle.Quad), { Value = 1 })
		tween.Completed:Once(function()
			level:Destroy()
			ghost:Destroy()
		end)
		tween:Play()
	end

	local tags: { any } = { "ui-overlay" }
	for _, tag in options.tags or {} do
		table.insert(tags, tag)
	end
	root = Element.new("Frame", {
		Name = options.name or "Overlay",
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
		Visible = function(): boolean
			return open() or closing()
		end,
		Tags = tags,
		scrim,
	}) :: Frame

	local natural = content.Size
	content.ZIndex = math.max(content.ZIndex, 2)
	if modal then
		content.SelectionGroup = true
		content.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
		content.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
		content.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
		content.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	end
	content.Parent = root

	local reason: string? = nil
	local function close(why: string?)
		if not Reactive.peek(open) then
			return
		end
		reason = why or "code"
		open(false)
	end

	if modal then
		local button = scrim :: any
		local connection = button.Activated:Connect(function()
			if closeOnOutside then
				close("outside")
			end
		end)
		Reactive.onCleanup(function()
			connection:Disconnect()
		end)
	end

	-- How far below its place a drawer is while it slides (overlay units).
	local slide = Instance.new("NumberValue")
	local slideTween: Tween? = nil
	local placedAt: UDim2? = nil
	local slideConnection = slide.Changed:Connect(function()
		if placedAt then
			content.Position = placedAt + UDim2.fromOffset(0, slide.Value)
		end
	end)
	Reactive.onCleanup(function()
		slideConnection:Disconnect()
		if slideTween then
			slideTween:Cancel()
		end
		slide:Destroy()
	end)

	-- Placement, from engine measurements while open.
	local placing = false
	local anchorObject: GuiObject? = nil
	local function place()
		if placing then
			return
		end
		placing = true
		local scale = Scroll.scaleOf(root)
		if scale <= 0 then
			scale = 1
		end
		local origin = root.AbsolutePosition
		local anchorRect: Rect? = nil
		if anchorObject then
			anchorRect = {
				position = (anchorObject.AbsolutePosition - origin) / scale,
				size = anchorObject.AbsoluteSize / scale,
			}
		end
		local at = Overlay.place(presentation(), {
			view = root.AbsoluteSize / scale,
			content = content.AbsoluteSize / scale,
			anchor = anchorRect,
			width = options.width,
			side = options.side,
			align = options.align,
			panelSide = options.panelSide,
		})
		content.AnchorPoint = at.anchorPoint
		placedAt = at.position
		content.Position = at.position + UDim2.fromOffset(0, slide.Value)
		safeBottom(if presentation() == "drawer" then Overlay.measureSafeBottom(root, scale) else 0)
		-- Whatever this presentation does not set comes from the content's own size,
		-- so a drawer opened after a panel is not left full height.
		local x = if at.width
			then UDim.new(0, at.width)
			elseif at.widthScale then UDim.new(at.widthScale, 0)
			else natural.X
		local y = if at.fullHeight then UDim.new(1, 0) else natural.Y
		content.Size = UDim2.new(x, y)
		maxHeight(at.maxHeight)
		placing = false
	end

	local live = Maid.new()
	local opener: GuiObject? = nil

	local function opened()
		live:clean()
		presentation(Overlay.resolve(options.presentation, options.prefer, mode()))
		anchorObject = resolveAnchor(options.anchor)
		opener = anchorObject
		layer += 1
		zIndex(10 + layer)
		forget(app, entry)
		table.insert(entries(app), entry)
		publish(app)

		-- A drawer starts below the screen and slides up.
		if slideTween then
			slideTween:Cancel()
			slideTween = nil
		end
		closing(false)
		slide.Value = 0
		place()
		fadeLevel.Value = 1
		fadeTo(0, Overlay.fadeTime)
		if presentation() == "drawer" and not Preferences.reducedMotion() then
			local scale = Scroll.scaleOf(root)
			local height = if scale > 0 then content.AbsoluteSize.Y / scale else 0
			slide.Value = if height > 0 then height else (Reactive.peek(maxHeight) :: any) :: number
			slideTween = TweenService:Create(
				slide,
				TweenInfo.new(Overlay.slideTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Value = 0 }
			);
			(slideTween :: Tween):Play()
		end
		live:give(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
		live:give(root.AncestryChanged:Connect(place))
		live:give(content:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
		local anchor = anchorObject
		if anchor then
			live:give(anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(place))
			live:give(anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
			local function check()
				if not isShown(anchor) then
					close("anchor")
				end
			end
			live:give(anchor:GetPropertyChangedSignal("Visible"):Connect(check))
			live:give(anchor.AncestryChanged:Connect(check))
			live:give(anchor.Destroying:Connect(function()
				close("anchor")
			end))
		end
		if not modal and closeOnOutside then
			live:give(UserInputService.InputBegan:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
					return
				end
				local point = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
				if not inside(content, point) and not inside(anchorObject, point) then
					close("outside")
				end
			end))
		end
	end

	local function closed()
		live:clean()
		anchorObject = nil
		forget(app, entry)
		publish(app)
		local why = reason or "code"
		reason = nil
		if options.onClose then
			options.onClose(why)
		end
	end

	-- A drawer slides back down, then hides.
	local function slideOut()
		if presentation() ~= "drawer" or Preferences.reducedMotion() then
			return
		end
		local scale = Scroll.scaleOf(root)
		local height = if scale > 0 then content.AbsoluteSize.Y / scale else 0
		if height <= 0 then
			return
		end
		closing(true)
		local tween = TweenService:Create(
			slide,
			TweenInfo.new(Overlay.slideTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Value = height }
		)
		slideTween = tween
		tween.Completed:Once(function()
			if slideTween == tween and not Reactive.peek(open) then
				slideTween = nil
				closing(false)
			end
		end)
		tween:Play()
	end

	Reactive.watch(open, function(isOpen, previous)
		if isOpen and not previous then
			opened()
		elseif not isOpen and previous then
			closed()
			slideOut()
			-- A sliding drawer stays shown and fades with the slide; anything
			-- else is hidden now, so a copy of its dimming fades out instead.
			if Reactive.peek(closing) then
				fadeTo(1, Overlay.slideTime)
			else
				fadeAfterimage()
				fadeLevel.Value = 1
			end
		end
	end, { immediate = true })

	Reactive.onCleanup(function()
		live:clean()
		forget(app, entry)
		publish(app)
	end)

	-- Back and focus, after the open watcher so the opener is known first.
	Composables.useBackHandler(app, function()
		return open() and (modal or dismissible)
	end, function()
		if options.onBack then
			options.onBack()
		elseif dismissible then
			close("back")
		end
		return true
	end)
	if modal then
		Composables.useFocusScope(app, open, {
			root = content,
			defaultFocus = function(): any
				local target = options.defaultFocus
				if type(target) == "function" then
					target = target()
				end
				return target or Overlay.firstSelectable(content)
			end,
			returnFocus = function()
				return opener
			end,
		})
	end

	local parent = options.parent
	if parent ~= false then
		root.Parent = if parent then parent else app:portal("modal")
	end

	return {
		root = root,
		scrim = scrim :: GuiObject,
		content = content,
		presentation = function(): string
			return presentation()
		end,
		maxHeight = function(): number
			return maxHeight()
		end,
		safeBottom = function(): number
			return safeBottom()
		end,
		close = close,
	}
end

return Overlay
