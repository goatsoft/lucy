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

	options: description, kind, duration (seconds, math.huge = until dismissed),
	action { label, onClick }, id, channel, quiet.

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
	How wide (desktop; touch runs full width): App.new({ toastWidth = 480 }), 356 by default.
	Where: App.new({ toastPosition = "top-center" }), or later
	app.state:set("ui.toaster.position", ...): top-left, top-center, top-right,
	bottom-left, bottom-center or bottom-right (the default). On touch devices
	toasts run full width at the top or bottom. The newest is nearest the edge.
	Toasts are announced to gamepad/keyboard users but never steal focus.
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Gradient = require(script.Parent.Gradient)
local PanelFrame = require(script.Parent.Parent.Core.PanelFrame)
local Reactive = require(script.Parent.Parent.Core.Reactive)

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
-- A toast with its kind's gradient: the fill goes white under it (over the kind's own fill, below),
-- so the gradient's colours show
table.insert(rules, {
	selector = ".ui-toast.ui-gradient-host",
	priority = 201,
	properties = { BackgroundColor3 = "$White" },
})
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
		} :: { any }
	do
		rule.priority = 200
		table.insert(Toaster.rules, rule)
	end
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
		if mounted == nil or mounted.destroyed then
			mounted = Toaster.new({
				app = app,
				id = "toaster",
				position = app.config.toastPosition,
				width = app.config.toastWidth,
				Parent = app:portal("toast"),
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
			duration = opts.duration or Toaster.defaults.duration,
			action = opts.action,
			channel = opts.channel or "default",
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
				label("Title", 1, "ui-toast-title", function()
					return toast().title or ""
				end),
				label("Description", 2, "ui-toast-description", function()
					return toast().description or ""
				end, function()
					local description = toast().description
					return description ~= nil and description ~= ""
				end),
			}),
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
	return frame
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

			-- Desktop: a 356px column at its position. Touch: full width at the top
			-- or bottom.
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

			h.layout = Element.new("UIListLayout", {
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
				Size = function()
					return if touch()
						then UDim2.fromScale(1, 1)
						else UDim2.new(0, width + inset().Offset * 2, 1, 0)
				end,
				Visible = h:ref("visible"),
				h.layout,
				Element.new("UIPadding", {
					-- At the top, clear Roblox's own buttons as well.
					PaddingTop = function()
						return if atTop()
							then UDim.new(0, inset().Offset + GuiService:GetGuiInset().Y)
							else UDim.new()
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

return Toaster
