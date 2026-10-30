--!strict
--[[
	Dialog and alert dialog

		local dialog = Dialog.new({
			id = "quit",
			title = "Leave match?",
			description = "You will drop your cash.",
			children = { ... },                     -- into dialog.body
			actions = {
				{ text = "Stay", variant = "outline" },
				{ text = "Leave", variant = "destructive", onClick = function(dialog) leave() end },
			},
			dismissible = true,       -- Escape / ButtonB / overlay / close button
			closeOnOverlay = true,
			modal = true,             -- false: no focus trap, presses reach what is behind
			scrim = true,             -- false: no dimmed backdrop
			showClose = true,
			maxWidth = 448,
			onOpenChange = function(open, dialog) end,
		})
		dialog:open()  dialog:close()  dialog:toggle()
		app.state:set("ui.quit.open", true)   -- same thing, from anywhere

		Dialog.alert({ title, description, confirmText, cancelText, destructive, onConfirm, onCancel })

	An action closes the dialog after its onClick unless onClick returns false.
	Dialogs mount into the app's "modal" portal (above every scene) unless Parent is given,
	and stack with sheets and popups by the order they open (Core/Overlay).

	Input: while open a modal dialog is a focus scope (Tab/arrows/gamepad stay inside,
	the primary action is selected when navigating), registers a back handler, and
	its content is a SelectionGroup so the gamepad cannot wander out. Focus goes
	back to whatever had it when the dialog closes.

	State keys: open, title, description.
]]

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Overlay = require(script.Parent.Parent.Core.Overlay)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Dialog = {}

local rules: { Component.Rule } = {
	{
		selector = ".ui-dialog-content",
		priority = 0,
		properties = { BackgroundColor3 = "$Background", BorderSizePixel = 0 },
	},
	{ selector = ".ui-dialog-content::UICorner", priority = 0, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-dialog-content::UIStroke",
		priority = 0,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	{
		selector = ".ui-dialog-inner::UIPadding",
		priority = 0,
		properties = {
			PaddingTop = "$Space6",
			PaddingBottom = "$Space6",
			PaddingLeft = "$Space6",
			PaddingRight = "$Space6",
		},
	},
	{
		selector = ".ui-dialog-inner",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-dialog-title",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontDisplay",
			TextSize = "$TextLg",
		},
	},
	{
		selector = ".ui-dialog-description",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
}
Dialog.rules = rules

-- A wrapped label bound to a text key; hidden while empty.
local function label(tag: string, order: number, text: () -> string)
	return Element.new("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Text = text,
		Visible = function()
			return text() ~= ""
		end,
		Tags = { tag },
	})
end

function Dialog.new(props: { [string]: any }?)
	local p: Component.Props = props or {}
	local dismissible = p.dismissible ~= false
	local modal = p.modal ~= false
	-- A modal closes on an outside press unless told not to; a non modal one only when asked.
	local closeOnOverlay = dismissible
		and (if modal then p.closeOnOverlay ~= false else p.closeOnOverlay == true)
	local showClose = dismissible and p.showClose ~= false
	local actionHandles = {}

	local handle
	handle = Component.mount({
		kind = "dialog",
		props = p,
		defaults = { open = false, title = "", description = "" },
		rules = Dialog.rules,
		render = function(h)
			local open = h:ref("open")
			local content = Component.create("Frame", {
				Name = "Content",
				Size = UDim2.new(1, -32, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Active = true,
				Tags = { "ui-dialog-content" },
			})
			Component.create(
				"UISizeConstraint",
				{ MaxSize = Vector2.new(p.maxWidth or 448, math.huge), Parent = content }
			)
			-- Padding and layout live on an inner frame, so the close button can sit in
			-- the content's own corner.
			local inner = Component.create("Frame", {
				Name = "Inner",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Tags = { "ui-dialog-inner" },
				Parent = content,
			})
			Component.list({ Padding = Component.space(h.app, "Space4", 16), Parent = inner })

			local header = Component.box({ Name = "Header", LayoutOrder = 1, Parent = inner })
			local text = Component.box({
				Name = "Text",
				Size = UDim2.new(1, if showClose then -44 else 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = header,
			})
			Component.list({ Padding = UDim.new(0, 6), Parent = text })
			h.titleLabel = label("ui-dialog-title", 1, h:ref("title"))
			h.titleLabel.Parent = text
			h.descriptionLabel = label("ui-dialog-description", 2, h:ref("description"))
			h.descriptionLabel.Parent = text

			if showClose then
				h.closeButton = Button.close({
					app = h.app,
					onClick = function()
						h:close()
					end,
				})
				local inset = Component.space(h.app, "Space1", 4).Offset
				h.closeButton.Instance.AnchorPoint = Vector2.new(1, 0)
				h.closeButton.Instance.Position = UDim2.new(1, -inset, 0, inset)
				h.closeButton.Instance.ZIndex = 3
				h.closeButton.Instance.Parent = content
				h.maid:give(h.closeButton)
			end

			local body = Component.box({ Name = "Body", LayoutOrder = 2, Parent = inner })
			Component.list({ Padding = Component.space(h.app, "Space4", 16), Parent = body })
			Component.adopt(body, p.children)
			body.Visible = p.children ~= nil

			local footer = Component.box({ Name = "Footer", LayoutOrder = 3, Parent = inner })
			Component.list({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = Component.space(h.app, "Space2", 8),
				Parent = footer,
			})
			for index, action in p.actions or {} do
				local actionHandle = Button.new({
					app = h.app,
					text = action.text,
					variant = action.variant or (if index == #p.actions then "default" else "outline"),
					disabled = action.disabled,
					layoutOrder = index,
					onClick = function()
						local keepOpen = action.onClick and action.onClick(h) == false
						if not keepOpen and action.close ~= false then
							h:close()
						end
					end,
				})
				actionHandle.Instance.Parent = footer
				table.insert(actionHandles, actionHandle)
				h.maid:give(actionHandle)
			end
			footer.Visible = #actionHandles > 0

			-- Stacking, back, focus and the dimmed backdrop (owned, so destroy pops them).
			local overlay = Overlay.use(h.app, {
				open = open,
				content = content,
				presentation = "center",
				modal = modal,
				scrim = if p.scrim == false then false else nil,
				dismissible = dismissible,
				closeOnOutside = closeOnOverlay,
				parent = false,
				id = h.id,
				name = "Dialog",
				tags = { "ui-dialog" },
				defaultFocus = function()
					local last = actionHandles[#actionHandles]
					return if last then last.Instance else (h.closeButton and h.closeButton.Instance)
				end,
			})
			local root = overlay.root
			h.overlay, h.content, h.body, h.footer, h.actions =
				overlay.scrim, content, body, footer, actionHandles
			Component.claimSelection(h.app, root)

			-- Side effects of opening: the owner hears.
			Reactive.watch(open, function(isOpen, previous)
				local wasOpen = previous == true
				if (isOpen == true) ~= wasOpen then
					if previous ~= nil then -- not at mount
						h:emit(if isOpen then "open" else "close")
					end
					if p.onOpenChange then
						p.onOpenChange(isOpen, h)
					end
				end
			end, { immediate = true })
			return root
		end,
	})

	function handle.open(h)
		h:set("open", true)
	end
	function handle.close(h)
		h:set("open", false)
	end
	function handle.toggle(h)
		h:set("open", not h:get("open"))
	end

	if not (p.Parent or p.parent) then
		handle.Instance.Parent = handle.app:portal("modal")
	end
	return handle
end

-- A confirm/cancel dialog that must be answered (no overlay or close button).
function Dialog.alert(props: { [string]: any })
	local p = table.clone(props)
	p.dismissible = false
	p.open = if p.open == nil then true else p.open
	p.actions = {
		{
			text = props.cancelText or "Cancel",
			variant = "outline",
			onClick = props.onCancel,
		},
		{
			text = props.confirmText or "Continue",
			variant = if props.destructive then "destructive" else "default",
			onClick = props.onConfirm,
		},
	}
	return Dialog.new(p)
end

return Dialog
