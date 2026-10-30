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
	action { label, onClick }, id.

	Toasts live in AppState at "toasts" (newest last) so the app can read, clear
	or drive them. Toaster.add / dismiss / expire are pure list functions.
	The list renders into the app's "toast" portal, above every scene and dialog,
	bottom-right on desktop and full width at the bottom on touch devices.
	Toasts are announced to gamepad/keyboard users but never steal focus.
]]

local RunService = game:GetService("RunService")

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Responsive = require(script.Parent.Parent.Core.Responsive)

local Toaster = {}

Toaster.kinds = { "default", "success", "error", "warning", "info" }
Toaster.defaults = { duration = 4, visibleToasts = 3, width = 356 }

Toaster.rules = {
	{ selector = ".ui-toast", priority = 0, properties = { BackgroundColor3 = "$Popover", BorderSizePixel = 0 } },
	{ selector = ".ui-toast::UICorner", priority = 0, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-toast::UIStroke",
		priority = 0,
		properties = { Color = "$Border", Thickness = "$StrokeThin", ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
	},
	{
		selector = ".ui-toast::UIPadding",
		priority = 0,
		properties = { PaddingTop = "$Space4", PaddingBottom = "$Space4", PaddingLeft = "$Space4", PaddingRight = "$Space4" },
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
	{ selector = ".ui-toast-accent", priority = 0, properties = { BackgroundTransparency = 1, BorderSizePixel = 0 } },
	{ selector = ".ui-toast-accent::UICorner", priority = 0, properties = { CornerRadius = "$RadiusFull" } },
}
for kind, token in { success = "$Success", error = "$Destructive", warning = "$Warning", info = "$Info" } do
	table.insert(Toaster.rules, {
		selector = `.ui-toast-accent-{kind}`,
		priority = 10,
		properties = { BackgroundColor3 = token, BackgroundTransparency = 0 },
	})
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
	local mounted = nil

	local function clock(): number
		return if app.clock then app.clock() else os.clock()
	end

	local function ensureMounted()
		if mounted == nil or mounted.destroyed then
			mounted = Toaster.new({ app = app, Parent = app:portal("toast") })
			app.maid:give(mounted)
		end
	end

	local function show(message: string, options: { [string]: any }?)
		local opts = options or {}
		local kind = opts.kind or "default"
		if not table.find(Toaster.kinds, kind) then
			error(`[Lucy] unknown toast kind "{kind}"`, 3)
		end
		local id = opts.id
		if id == nil then
			counter += 1
			id = "toast-" .. counter
		end
		ensureMounted()
		app.state:update("toasts", function(list)
			return Toaster.add(list or {}, {
				id = id,
				title = message,
				description = opts.description,
				kind = kind,
				duration = opts.duration or Toaster.defaults.duration,
				action = opts.action,
				createdAt = clock(),
			})
		end)
		return id
	end

	local api = setmetatable({}, {
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

local function buildToast(h, toast)
	local frame = Component.create("Frame", {
		Name = toast.id,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Tags = { "ui-toast" },
	})
	local row = Component.box({ Name = "Row", Parent = frame })
	Component.list({
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = Component.space(h.app, "Space3", 12),
		Parent = row,
	})

	local accent = Component.create("Frame", {
		Name = "Accent",
		Size = UDim2.new(0, 4, 0, 32),
		LayoutOrder = 1,
		Tags = { "ui-toast-accent" },
		Parent = row,
	})

	local body = Component.box({ Name = "Body", Size = UDim2.fromScale(0, 0), LayoutOrder = 2, Parent = row })
	body.AutomaticSize = Enum.AutomaticSize.Y
	Component.create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = body })
	Component.list({ Padding = UDim.new(0, 2), Parent = body })
	local title = Component.create("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Tags = { "ui-toast-title" },
		Parent = body,
	})
	local description = Component.create("TextLabel", {
		Name = "Description",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Tags = { "ui-toast-description" },
		Parent = body,
	})

	local entry = { frame = frame, accent = accent, title = title, description = description, buttons = {} }

	local close = Button.new({
		app = h.app,
		name = "Close",
		text = "×",
		variant = "ghost",
		size = "icon",
		layoutOrder = 4,
		onClick = function()
			h.app.toast.dismiss(toast.id)
		end,
	})
	close.Instance.Parent = row
	table.insert(entry.buttons, close)
	entry.close = close
	return entry
end

local function applyToast(h, entry, toast)
	entry.title.Text = toast.title or ""
	entry.description.Text = toast.description or ""
	entry.description.Visible = toast.description ~= nil and toast.description ~= ""
	for _, kind in Toaster.kinds do
		entry.accent:RemoveTag("ui-toast-accent-" .. kind)
	end
	entry.accent:AddTag("ui-toast-accent-" .. toast.kind)
	entry.accent.Visible = toast.kind ~= "default"

	local hasAction = toast.action ~= nil
	if hasAction and not entry.action then
		entry.action = Button.new({
			app = h.app,
			name = "Action",
			size = "sm",
			layoutOrder = 3,
			onClick = function()
				local action = entry.toast.action
				if action and action.onClick then
					action.onClick(entry.toast)
				end
				h.app.toast.dismiss(entry.toast.id)
			end,
		})
		entry.action.Instance.Parent = entry.frame.Row
		table.insert(entry.buttons, entry.action)
	end
	if entry.action then
		entry.action:set({ text = if hasAction then toast.action.label else "", visible = hasAction })
	end
	entry.toast = toast
end

local function destroyEntry(entry)
	for _, button in entry.buttons do
		button:destroy()
	end
	entry.frame:Destroy()
end

function Toaster.new(props: { [string]: any }?)
	local p = props or {}
	local entries = {}
	local heartbeat: RBXScriptConnection? = nil

	return Component.mount({
		kind = "toaster",
		props = p,
		defaults = { visible = true },
		rules = Toaster.rules,
		render = function(h)
			local container = Component.box({ Name = "Toaster", AutomaticSize = Enum.AutomaticSize.None })
			local layout = Component.list({
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = Component.space(h.app, "Space2", 8),
				Parent = container,
			})
			local padding = Component.create("UIPadding", { Parent = container })
			h.container, h.layout = container, layout

			-- Desktop: a 356px column bottom-right. Touch: full width at the bottom.
			local function place()
				local touch = Responsive.pick(h.app, { mobile = true, default = false })
				local inset = if touch then 12 else 24
				container.AnchorPoint = Vector2.new(1, 1)
				container.Position = UDim2.fromScale(1, 1)
				container.Size = if touch
					then UDim2.fromScale(1, 1)
					else UDim2.new(0, (p.width or Toaster.defaults.width) + inset * 2, 1, 0)
				padding.PaddingBottom = UDim.new(0, inset)
				padding.PaddingRight = UDim.new(0, inset)
				padding.PaddingLeft = UDim.new(0, inset)
			end
			place()
			h.maid:give(h.app.state:subscribe("input.device", place))

			-- Render from state.
			local function render(list)
				list = list or {}
				local visibleCount = p.visibleToasts or Toaster.defaults.visibleToasts
				local seen = {}
				for index, toast in list do
					seen[toast.id] = true
					local entry = entries[toast.id]
					if not entry then
						entry = buildToast(h, toast)
						entries[toast.id] = entry
						entry.frame.Parent = container
						Component.claimSelection(h.app, entry.frame)
					end
					applyToast(h, entry, toast)
					entry.frame.LayoutOrder = index
					entry.frame.Visible = index > #list - visibleCount
				end
				for id, entry in entries do
					if not seen[id] then
						destroyEntry(entry)
						entries[id] = nil
					end
				end

				-- Only tick while something can expire.
				local needsClock = false
				for _, toast in list do
					if toast.duration ~= math.huge then
						needsClock = true
						break
					end
				end
				if needsClock and not heartbeat and not h.app.clock then
					heartbeat = RunService.Heartbeat:Connect(function()
						h.app.toast.tick()
					end)
				elseif not needsClock and heartbeat then
					heartbeat:Disconnect()
					heartbeat = nil
				end
			end
			h.render = render
			h.maid:give(h.app.state:subscribe("toasts", render))
			h.maid:give(function()
				if heartbeat then
					heartbeat:Disconnect()
				end
				for id, entry in entries do
					destroyEntry(entry)
					entries[id] = nil
				end
			end)
			h.entries = entries
			render(h.app.state:get("toasts"))
			return container
		end,
		update = function(h, state)
			h.Instance.Visible = state.visible
		end,
	})
end

return Toaster
