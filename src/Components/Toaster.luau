--!strict
--[[
	Toaster: toast notifications.

	Installed on every App automatically, so game code just calls:

		app.toast("Saved")
		app.toast.success("Round won", { description = "+$250" })
		app.toast.error("Disconnected")
		app.toast.warning("Low ammo")   app.toast.info("New map in rotation")
		local id = app.toast("Uploading...", { duration = math.huge })
		app.toast("Uploaded", { id = id })      -- update in place (resets its timer)
		app.toast("Invite from JB", { action = { label = "Join", onClick = join } })
		app.toast.dismiss(id)                    -- or app.toast.dismiss() for all

	options: description, kind, media, duration (seconds, math.huge = until dismissed),
	action { label, onClick }, id, channel, quiet, content, bare, dismissOnTap, swipe.

	media is a slot (as Item's): an Icon, an image, a handle, an instance, a builder or a list,
	before the title and description. An Icon in it takes the toast's text colour.

		app.toast.success("You're in", { media = Lucy.Icon.new({ icon = "lucide:sparkles", size = 36 }) })

	Your own UI in a toast (a show's status card, a countdown): `content` is a function
	called once with a getter for the toast (it follows updates in place by id) that returns
	an Instance or a handle, put where the title and description go. With `bare = true` it
	stands alone: no panel, shadow or close button round it, so it keeps its own look, as wide
	as it is. A bare toast slides in from its edge (appears in place with reduced motion).

		app.toast("Show", { content = function(toast) return card end, bare = true,
			duration = math.huge, dismissOnTap = true, id = "show-status" })

	On touch a toast is thrown away with a swipe: up off the top (down at the bottom), or
	sideways (`swipe = false` keeps it). `dismissOnTap = true` dismisses it with a tap too,
	for a toast with nothing in it to press.

	Quiet mode (app.quiet, ADR 0038): a toast on a channel the app is quiet for
	(channel defaults to "default") follows its quiet option:
		quiet = "hold"   the default: shown once the channel is allowed again,
		                 the newest visibleToasts only, timed from then
		quiet = "drop"   thrown away (news that goes stale)
		quiet = "show"   shown anyway (errors, disconnects)

	Toasts live in AppState at "toasts" (newest last) so the app can read, clear
	or drive them. Toaster.add / dismiss / expire are pure list functions.
	The list renders into the app's "toast" portal, above every scene and dialog.

	Each toast sits in a panel frame, as a dialog does (Core/PanelFrame): with the PanelShadow token
	set, a hard shadow is drawn that many pixels right and down behind it (ui-toast-shadow, black
	unless a rule colours it; the frame is tagged ui-toast-frame-kind-<kind>, so a game can colour
	each kind's shadow). A theme that has a GradientToast<Kind> token (GradientToastSuccess,
	GradientToastError, GradientToastDefault and so on) fills that kind's toasts with it, by
	Lucy.Gradient; a kind without one keeps its flat fill.
	How wide: App.new({ toastWidth = 480 }), 356 by default; on a screen narrower than that they
	fill its width.
	Where: App.new({ toastPosition = "top-center" }), or later
	app.state:set("ui.toaster.position", ...): top-left, top-center, top-right,
	bottom-left, bottom-center or bottom-right (the default). On touch devices
	toasts sit centred at the top or bottom. The newest is nearest the edge.
	Toasts are announced to gamepad/keyboard users but never steal focus.
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Button = require(script.Parent.Button)
local Slot = require(script.Parent.Slot)
local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Gradient = require(script.Parent.Gradient)
local PanelFrame = require(script.Parent.Parent.Core.PanelFrame)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Theme = require(script.Parent.Parent.Core.Theme)

local Toaster = {}

Toaster.kinds = { "default", "success", "error", "warning", "info" }
Toaster.defaults = { duration = 4, visibleToasts = 3, width = 356 }
Toaster.positions = { "top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right" }
Toaster.quietRules = { "hold", "drop", "show" }

local function checkPosition(position: string)
	if not table.find(Toaster.positions, position) then
		error(
			`[Lucy] unknown toast position "{position}" (expected {table.concat(Toaster.positions, ", ")})`,
			0
		)
	end
end

-- How each side of a position anchors: x and y fractions, and the layout.
-- The free part of Roblox's top bar, right of its buttons (GuiService.TopbarInset). Specs swap it
Toaster._topbar = function(): Rect
	return GuiService.TopbarInset
end

-- Whether toasts spanning `left` to `right` (screen pixels) fit the free part of the top bar, so
-- they can sit at the very top. A bar with no height (a console, or no top bar): nothing to clear
function Toaster.clearsTopbar(left: number, right: number, free: Rect): boolean
	if free.Height <= 0 then
		return true
	end
	return left >= free.Min.X and right <= free.Max.X
end

local HORIZONTAL: { [string]: { any } } = {
	left = { 0, Enum.HorizontalAlignment.Left },
	center = { 0.5, Enum.HorizontalAlignment.Center },
	right = { 1, Enum.HorizontalAlignment.Right },
}

local rules: { Component.Rule } = {
	{
		selector = ".ui-toast",
		priority = 0,
		properties = { BackgroundColor3 = "$Popover", BorderSizePixel = 0 },
	},
	{ selector = ".ui-toast::UICorner", priority = 0, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-toast::UIStroke",
		priority = 0,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-toast::UIPadding",
		priority = 0,
		properties = {
			PaddingTop = "$Space4",
			PaddingBottom = "$Space4",
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
		},
	},
	{
		selector = ".ui-toast-title",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$PopoverForeground",
			FontFace = "$FontSansSemibold",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-toast-description",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
}
for _, rule in PanelFrame.rules("toast") do
	table.insert(rules, rule)
end
-- The shadow's corners match the toast's (a rule, so there is no UICorner for the frame to copy):
-- a theme that rounds toasts differently rounds both
table.insert(
	rules,
	{ selector = ".ui-toast-shadow::UICorner", priority = 0, properties = { CornerRadius = "$RadiusLg" } }
)
Toaster.rules = rules
-- A kind colours the whole toast: background, border, text and the close icon
-- (above the Button icon rules, which go up to 100).
local KIND_COLOURS: { [string]: { string } } = {
	success = { "$Success", "$SuccessForeground" },
	error = { "$Destructive", "$DestructiveForeground" },
	warning = { "$Warning", "$WarningForeground" },
	info = { "$Info", "$InfoForeground" },
}
for kind, colours in KIND_COLOURS do
	local fill, text = colours[1], colours[2]
	local base = `.ui-toast-kind-{kind}`
	for _, rule in
		{
			{ selector = base, properties = { BackgroundColor3 = fill } },
			{ selector = base .. "::UIStroke", properties = { Color = fill } },
			{ selector = base .. " >> .ui-toast-title", properties = { TextColor3 = text } },
			{
				selector = base .. " >> .ui-toast-description",
				properties = { TextColor3 = text, TextTransparency = 0.15 },
			},
			{ selector = base .. " >> .ui-button-icon", properties = { ImageColor3 = text } },
			{ selector = base .. " >> .ui-toast-media >> .ui-icon", properties = { ImageColor3 = text } },
		} :: { any }
	do
		rule.priority = 200
		table.insert(Toaster.rules, rule)
	end
end

-- How far a touch drags a toast before it is thrown away, in pixels (twice as far sideways)
Toaster.SWIPE = 32
-- A press that moves less than this is a tap
Toaster.TAP = 8
-- A bare toast sliding in from its edge: eased out, no overshoot, so it reads as a slide and
-- not a pop
Toaster.DROP = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Whether a drag by `delta` throws a toast away: past its edge (up at the top, down at the
-- bottom) by SWIPE, or sideways by twice that
function Toaster.swiped(delta: Vector2, atTop: boolean): boolean
	if math.abs(delta.X) >= Toaster.SWIPE * 2 then
		return true
	end
	return if atTop then delta.Y <= -Toaster.SWIPE else delta.Y >= Toaster.SWIPE
end

-- Pure list operations -------------------------------------------------------

-- Adds a toast, or replaces the one with the same id (keeping its place).
function Toaster.add(list: { any }, toast: { [string]: any }): { any }
	local out = table.clone(list)
	for index, existing in out do
		if existing.id == toast.id then
			out[index] = toast
			return out
		end
	end
	table.insert(out, toast)
	return out
end

-- Removes one toast by id, or all with no id.
function Toaster.dismiss(list: { any }, id: string?): { any }
	if id == nil then
		return if #list == 0 then list else {}
	end
	local out = {}
	for _, toast in list do
		if toast.id ~= id then
			table.insert(out, toast)
		end
	end
	return if #out == #list then list else out
end

-- Drops toasts whose time is up. Returns the same table when nothing expired.
function Toaster.expire(list: { any }, now: number): { any }
	local out = {}
	for _, toast in list do
		if toast.duration == math.huge or now < toast.createdAt + toast.duration then
			table.insert(out, toast)
		end
	end
	return if #out == #list then list else out
end

-- API ------------------------------------------------------------------------

function Toaster.install(app)
	local counter = 0
	local mounted: Component.Handle? = nil

	local function clock(): number
		return if app.clock then app.clock() else os.clock()
	end

	local function ensureMounted()
		-- A toaster whose portal was taken out of the screen (not destroyed) is in a gui nobody
		-- sees: the app makes a new portal then, and the toaster goes in it again
		local portal = app:portal("toast")
		if mounted ~= nil and not mounted.destroyed and not mounted.Instance:IsDescendantOf(portal) then
			mounted:destroy()
		end
		if mounted == nil or mounted.destroyed then
			mounted = Toaster.new({
				app = app,
				id = "toaster",
				position = app.config.toastPosition,
				width = app.config.toastWidth,
				Parent = portal,
			})
			app.maid:give(mounted)
		end
	end

	-- Toasts held while their channel is quiet, oldest first.
	local held: Reactive.Ref<{ any }> = Reactive.ref({})

	local function publish(toast: { [string]: any })
		ensureMounted()
		toast.createdAt = clock()
		app.state:update("toasts", function(list)
			return Toaster.add(list or {}, toast)
		end)
	end

	-- Lets held toasts out once their channel is allowed again.
	local release = Reactive.effectScope(true)
	release:run(function()
		Reactive.watchEffect(function()
			local waiting = held()
			local out, keep = {}, {}
			for _, toast in waiting do
				if app.quiet:allows(toast.channel) then
					table.insert(out, toast)
				else
					table.insert(keep, toast)
				end
			end
			if #out == 0 then
				return
			end
			Reactive.untrack(function()
				held(keep)
				local first = math.max(1, #out - Toaster.defaults.visibleToasts + 1)
				for index = first, #out do
					publish(out[index])
				end
			end)
		end)
	end);
	(app.maid :: any):give(function()
		release:stop()
	end)

	local function show(message: string, options: { [string]: any }?)
		local opts: { [string]: any } = options or {}
		local kind = opts.kind or "default"
		if not table.find(Toaster.kinds, kind) then
			error(`[Lucy] unknown toast kind "{kind}"`, 3)
		end
		local rule = opts.quiet or "hold"
		if not table.find(Toaster.quietRules, rule) then
			error(`[Lucy] unknown toast quiet rule "{rule}" (expected hold, drop, show)`, 3)
		end
		local id = opts.id
		if id == nil then
			counter += 1
			id = "toast-" .. counter
		end
		local toast = {
			id = id,
			title = message,
			description = opts.description,
			kind = kind,
			media = opts.media,
			duration = opts.duration or Toaster.defaults.duration,
			action = opts.action,
			channel = opts.channel or "default",
			content = opts.content,
			bare = opts.bare == true and opts.content ~= nil,
			dismissOnTap = opts.dismissOnTap == true,
			swipe = opts.swipe ~= false,
		}
		local allowed = Reactive.untrack(function()
			return app.quiet:allows(toast.channel)
		end)
		if rule == "show" or allowed then
			publish(toast)
		elseif rule == "hold" then
			held(Toaster.add(
				Reactive.untrack(function()
					return held()
				end),
				toast
			))
		end
		return id
	end

	local api: any = setmetatable({}, {
		__call = function(_, message, options)
			return show(message, options)
		end,
	})
	for _, kind in Toaster.kinds do
		api[kind] = function(message, options)
			local opts = table.clone(options or {})
			opts.kind = kind
			return show(message, opts)
		end
	end
	api.message = api.default
	function api.dismiss(id: string?)
		held(Toaster.dismiss(
			Reactive.untrack(function()
				return held()
			end),
			id
		))
		app.state:update("toasts", function(list)
			return Toaster.dismiss(list or {}, id)
		end)
	end
	function api.list()
		return app.state:get("toasts") or {}
	end
	-- Advance expiry by hand (tests, or games that pause time).
	function api.tick(now: number?)
		app.state:update("toasts", function(list)
			return Toaster.expire(list or {}, now or clock())
		end)
	end

	app.toast = api
	app.state:set("toasts", app.state:get("toasts") or {})
	return api
end

-- Rendering ------------------------------------------------------------------

local EMPTY = table.freeze({})

-- A kind's gradient token's name, after "Gradient": ToastSuccess, ToastDefault
local function gradientName(kind: string): string
	return "Toast" .. string.upper(string.sub(kind, 1, 1)) .. string.sub(kind, 2)
end

local function label(name: string, order: number, tag: string, text: () -> string, visible: any?): TextLabel
	return Element.new("TextLabel", {
		Name = name,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Text = text,
		Visible = visible,
		Tags = { tag },
	})
end

--[[
	One toast. `item` is the toast as first seen; `toast()` follows it by id, so an
	update in place (same id) re-binds only what changed. A row stops, destroying
	its buttons, when its toast leaves the list.
]]
local function renderToast(h, toasts: () -> { any }, item: { [string]: any }, index: () -> number)
	local app = h.app
	local id = item.id
	local visibleCount = h.props.visibleToasts or Toaster.defaults.visibleToasts
	local toast = Reactive.computed(function(): { [string]: any }
		for _, candidate in toasts() do
			if candidate.id == id then
				return candidate
			end
		end
		return item
	end)

	local entry: { [string]: any } = {}
	h.entries[id] = entry

	-- The game's own UI for this toast, made once (an update in place keeps it)
	local function built(): Instance
		local made = Reactive.untrack(function()
			return item.content(toast)
		end)
		if type(made) == "table" and made.Instance then
			Reactive.onCleanup(function()
				if not made.destroyed and made.destroy then
					made:destroy()
				end
			end)
			return made.Instance
		end
		return made :: Instance
	end

	if item.bare then
		return Toaster._bare(h, toasts, toast, item, index, entry, built())
	end
	Reactive.onCleanup(function()
		if h.entries[id] == entry then
			h.entries[id] = nil
		end
	end)

	entry.close = Button.new({
		app = app,
		name = "Close",
		icon = "lucy:close",
		variant = "ghost",
		size = "icon",
		layoutOrder = 4,
		onClick = function()
			app.toast.dismiss(id)
		end,
	})

	local action = Element.show(function()
		return toast().action ~= nil
	end, function()
		local button = Button.new({
			app = app,
			name = "Action",
			size = "sm",
			layoutOrder = 3,
			text = function()
				local current = toast().action
				return if current then current.label else ""
			end,
			onClick = function()
				local current = toast()
				if current.action and current.action.onClick then
					current.action.onClick(current)
				end
				app.toast.dismiss(id)
			end,
		})
		entry.action = button
		Reactive.onCleanup(function()
			if entry.action == button then
				entry.action = nil
			end
		end)
		return button
	end)

	-- The media slot, before the title and description (not beside the game's own UI): made
	-- once, as the toast is first seen
	local media: Frame? = nil
	if item.media ~= nil and not item.content then
		media = Component.box({
			Name = "Media",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 1,
			Tags = { "ui-toast-media" },
		})
		Component.list({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Parent = media,
		})
		Slot.fill(media :: Frame, item.media, { app = app })
	end

	local panel = Element.new("Frame", {
		Name = id,
		AutomaticSize = Enum.AutomaticSize.Y,
		Tags = {
			"ui-toast" :: any,
			function(): string
				return "ui-toast-kind-" .. toast().kind
			end,
		},
		Element.new("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Component.list({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = Component.space(app, "Space3", 12),
			}) :: any,
			Element.new("Frame", {
				Name = "Body",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Component.create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) :: any,
				Component.list({ Padding = UDim.new(0, 2) }) :: any,
				-- The game's own UI, or the title over the description
				if item.content
					then built() :: any
					else label("Title", 1, "ui-toast-title", function()
						return toast().title or ""
					end),
				if item.content
					then nil
					else label("Description", 2, "ui-toast-description", function()
						return toast().description or ""
					end, function()
						local description = toast().description
						return description ~= nil and description ~= ""
					end),
			}),
			media :: any,
			action,
			entry.close,
		}),
	})

	-- The kind's gradient, when the theme has one
	local function hasGradient(): boolean
		return app.theme:resolve("Gradient" .. gradientName(toast().kind)) ~= nil
	end
	Gradient.new({
		app = app,
		gradient = function(): string
			return if hasGradient() then gradientName(toast().kind) else "Surface"
		end,
		visible = hasGradient,
		Parent = panel,
	})

	-- The frame the list lays out: the panel, and its shadow when the theme draws one
	local parts = PanelFrame.new(app, panel, { kind = "toast", placement = "inside" })
	local frame = parts.frame
	Element.hydrate(frame, {
		Name = id .. "-frame",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		-- Only the newest visibleToasts show, and the newest is nearest the edge.
		Visible = function()
			return index() > #toasts() - visibleCount
		end,
		LayoutOrder = function()
			return if h.atTop() then -index() else index()
		end,
		Tags = {
			"ui-toast-frame" :: any,
			function(): string
				return "ui-toast-frame-kind-" .. toast().kind
			end,
		},
	})
	Component.claimSelection(app, panel)
	entry.frame = frame
	entry.panel = panel
	Toaster._gestures(h, toast, frame, nil)
	return frame
end

-- A bare toast: the game's UI alone, as wide as it is, sliding in from the toaster's edge
function Toaster._bare(
	h,
	toasts: () -> { any },
	toast: () -> { [string]: any },
	item: { [string]: any },
	index: () -> number,
	entry: { [string]: any },
	content: Instance
)
	local app = h.app
	local id = item.id
	local visibleCount = h.props.visibleToasts or Toaster.defaults.visibleToasts
	-- The content moves in this (the drop, a drag); the frame the list lays out stays put
	local slide = Element.new("Frame", {
		Name = "Slide",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
	})
	content.Parent = slide
	local frame = Element.new("Frame", {
		Name = id .. "-frame",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = function()
			return index() > #toasts() - visibleCount
		end,
		LayoutOrder = function()
			return if h.atTop() then -index() else index()
		end,
		Tags = { "ui-toast-frame" :: any, "ui-toast-bare" },
		slide,
	})
	Component.claimSelection(app, content)
	entry.frame = frame
	entry.panel = content
	entry.slide = slide
	-- In from the edge it sits at
	if not Preferences.reducedMotion() then
		local from = if h.atTop() then -1 else 1
		slide.Position = UDim2.new(0, 0, from, from * 12)
		TweenService:Create(slide, Toaster.DROP, { Position = UDim2.new() }):Play()
	end
	Toaster._gestures(h, toast, frame, slide)
	return frame
end

-- Touch on a toast: a swipe past its edge or sideways throws it away (the content follows the
-- finger when it can move), a tap dismisses it when it asks for that
function Toaster._gestures(h, toast: () -> { [string]: any }, frame: GuiObject, slide: GuiObject?)
	local app = h.app
	local maid: { RBXScriptConnection } = {}
	local function stop()
		for _, connection in maid do
			connection:Disconnect()
		end
		table.clear(maid)
	end
	Reactive.onCleanup(stop)
	local began = frame.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local current = Reactive.untrack(toast)
		if not current.swipe and not current.dismissOnTap then
			return
		end
		stop()
		local start = Vector2.new(input.Position.X, input.Position.Y)
		local moved = Vector2.zero
		table.insert(
			maid,
			UserInputService.TouchMoved:Connect(function(touch: InputObject)
				if touch ~= input then
					return
				end
				moved = Vector2.new(touch.Position.X, touch.Position.Y) - start
				if slide and current.swipe then
					-- Follows the finger outwards and sideways, never in past where it sits
					local y = if h.atTop() then math.min(0, moved.Y) else math.max(0, moved.Y)
					slide.Position = UDim2.fromOffset(moved.X, y)
				end
			end)
		)
		table.insert(
			maid,
			UserInputService.TouchEnded:Connect(function(touch: InputObject)
				if touch ~= input then
					return
				end
				stop()
				local latest = Reactive.untrack(toast)
				-- Thrown away (a swipe past its edge) or tapped (when it asks for that): gone
				local swiped = latest.swipe and Toaster.swiped(moved, h.atTop())
				local tapped = latest.dismissOnTap and moved.Magnitude < Toaster.TAP
				if swiped or tapped then
					app.toast.dismiss(latest.id)
				elseif slide then
					TweenService:Create(slide, Toaster.DROP, { Position = UDim2.new() }):Play()
				end
			end)
		)
	end)
	Reactive.onCleanup(function()
		began:Disconnect()
	end)
end

function Toaster.new(props: { [string]: any }?)
	local p: Component.Props = props or {}

	return Component.mount({
		kind = "toaster",
		props = p,
		defaults = { visible = true, position = "bottom-right" },
		rules = Toaster.rules,
		render = function(h)
			local app = h.app
			h.entries = {}
			local list = app.state:ref("toasts")
			local function toasts(): { any }
				return list() or EMPTY
			end

			-- Side effect: tick the clock only while something can expire.
			local needsClock = Reactive.computed(function(): boolean
				for _, toast in toasts() do
					if toast.duration ~= math.huge then
						return true
					end
				end
				return false
			end)
			Reactive.watchEffect(function(onCleanup)
				if needsClock() and not app.clock then
					local heartbeat = RunService.Heartbeat:Connect(function()
						app.toast.tick()
					end)
					onCleanup(function()
						heartbeat:Disconnect()
					end)
				end
			end)

			-- A column as wide as toastWidth (356 by default), never wider than the screen: at its
			-- position on desktop, centred at the top or bottom on touch.
			checkPosition(h:get("position"))
			local position = h:ref("position")
			local touch = Composables.useResponsive(app, { mobile = true, default = false })
			local width = p.width or Toaster.defaults.width
			local function inset(): UDim
				return UDim.new(0, if touch() then 12 else 24)
			end
			local function parts(): (boolean, { any })
				local value = position()
				checkPosition(value)
				local vertical, horizontal = string.match(value, "^(%a+)-(%a+)$")
				return vertical == "top", HORIZONTAL[if touch() then "center" else horizontal :: string]
			end
			local function atTop(): boolean
				return (parts())
			end
			h.atTop = atTop
			local function anchor(): Vector2
				local top, side = parts()
				return Vector2.new(side[1], if top then 0 else 1)
			end

			-- At the top, where the toasts would sit against what Roblox's top bar has free: they sit
			-- just off the very top where they clear its buttons (the top centre, mostly), and under
			-- the bar only where they would reach them (JB 2026-11-16)
			local bar = Reactive.ref(Toaster._topbar())
			h.maid:give(GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
				bar(Toaster._topbar())
			end))
			local contentSize = Reactive.ref(Vector2.zero)
			local columnAt = Reactive.ref(Vector2.zero)
			local columnSize = Reactive.ref(Vector2.zero)
			local function clearsBar(): boolean
				local _, side = parts()
				local at, size, wide = columnAt(), columnSize(), contentSize().X
				local left = at.X + (size.X - wide) * side[1]
				return Toaster.clearsTopbar(left, left + wide, bar())
			end
			local function barHeight(): number
				local free = bar()
				return if free.Height > 0 then free.Max.Y else GuiService:GetGuiInset().Y
			end

			h.layout = Element.new("UIListLayout", {
				[Element.out("AbsoluteContentSize")] = contentSize,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = function()
					return if atTop() then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
				end,
				HorizontalAlignment = function()
					local _, side = parts()
					return side[2]
				end,
				Padding = Component.space(app, "Space2", 8),
			})
			local container = Element.new("Frame", {
				Name = "Toaster",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = anchor,
				Position = function()
					local a = anchor()
					return UDim2.fromScale(a.X, a.Y)
				end,
				Size = UDim2.fromScale(1, 1),
				Visible = h:ref("visible"),
				[Element.out("AbsolutePosition")] = columnAt,
				[Element.out("AbsoluteSize")] = columnSize,
				h.layout,
				Element.new("UISizeConstraint", {
					MaxSize = function()
						return Vector2.new(width + inset().Offset * 2, math.huge)
					end,
				}),
				Element.new("UIPadding", {
					-- At the top, under Roblox's top bar only where they would reach its buttons
					PaddingTop = function()
						if not atTop() then
							return UDim.new()
						end
						return UDim.new(0, inset().Offset + (if clearsBar() then 0 else barHeight()))
					end,
					PaddingBottom = function()
						return if atTop() then UDim.new() else inset()
					end,
					PaddingRight = inset,
					PaddingLeft = inset,
				}),
				Element.each(toasts, function(item, index)
					return renderToast(h, toasts, item, index)
				end, {
					key = function(item)
						return item.id
					end,
				}),
			})
			h.container = container
			return container
		end,
	})
end

-- Its rules are Lucy's from the start (ADR 0052): its spec is made in Toaster.new
Theme.declare("toaster", Toaster.rules)

return Toaster
