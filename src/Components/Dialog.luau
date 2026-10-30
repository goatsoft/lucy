--!strict
--[[
	Dialog and alert dialog

		local dialog = Dialog.new({
			id = "quit",
			title = "Leave match?",
			description = "You will drop your cash.",
			children = { ... },                     -- into dialog.content
			actions = {
				{ text = "Stay", variant = "outline" },
				{ text = "Leave", variant = "destructive", onClick = function(dialog) leave() end },
			},
			dismissible = true,       -- Escape / ButtonB / overlay / close button
			closeOnOverlay = true,
			showClose = true,
			maxWidth = 448,
			onOpenChange = function(open, dialog) end,
		})
		dialog:open()  dialog:close()  dialog:toggle()
		app.state:set("ui.quit.open", true)   -- same thing, from anywhere

		Dialog.alert({ title, description, confirmText, cancelText, destructive, onConfirm, onCancel })

	An action closes the dialog after its onClick unless onClick returns false.
	Dialogs mount into the app's "modal" portal (above every scene) unless Parent is given.

	Input: while open the dialog is a focus scope (Tab/arrows/gamepad stay inside,
	the first action is selected when navigating), registers a back handler, and
	its content is a SelectionGroup so the gamepad cannot wander out.

	State keys: open, title, description.
]]

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)

local Dialog = {}

local rules: { Component.Rule } = {
	{
		selector = ".ui-dialog-overlay",
		priority = 0,
		properties = {
			BackgroundColor3 = "$Overlay",
			BackgroundTransparency = "$OverlayTransparency",
			BorderSizePixel = 0,
		},
	},
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
		selector = ".ui-dialog-content::UIPadding",
		priority = 0,
		properties = {
			PaddingTop = "$Space6",
			PaddingBottom = "$Space6",
			PaddingLeft = "$Space6",
			PaddingRight = "$Space6",
		},
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

local layer = 0

local function label(tag: string, order: number)
	return Component.create("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Tags = { tag },
	})
end

function Dialog.new(props: { [string]: any }?)
	local p: Component.Props = props or {}
	local dismissible = p.dismissible ~= false
	local closeOnOverlay = dismissible and p.closeOnOverlay ~= false
	local showClose = dismissible and p.showClose ~= false
	local actionHandles = {}
	local popScope, popBack = nil, nil

	local handle
	handle = Component.mount({
		kind = "dialog",
		props = p,
		defaults = { open = false, title = "", description = "" },
		rules = Dialog.rules,
		render = function(h)
			local root = Component.box({
				Name = "Dialog",
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.None,
				Visible = false,
				Tags = { "ui-dialog" },
			})

			local overlay = Component.create("TextButton", {
				Name = "Overlay",
				Text = "",
				AutoButtonColor = false,
				Selectable = false,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
				Tags = { "ui-dialog-overlay" },
				Parent = root,
			})
			h.maid:give(overlay.Activated:Connect(function()
				if closeOnOverlay then
					h:close()
				end
			end))

			local content = Component.create("Frame", {
				Name = "Content",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -32, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Active = true,
				ZIndex = 2,
				SelectionGroup = true,
				SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
				SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
				SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
				Tags = { "ui-dialog-content" },
				Parent = root,
			})
			Component.create(
				"UISizeConstraint",
				{ MaxSize = Vector2.new(p.maxWidth or 448, math.huge), Parent = content }
			)
			Component.list({ Padding = Component.space(h.app, "Space4", 16), Parent = content })

			local header = Component.box({ Name = "Header", LayoutOrder = 1, Parent = content })
			local text = Component.box({
				Name = "Text",
				Size = UDim2.new(1, if showClose then -44 else 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = header,
			})
			Component.list({ Padding = UDim.new(0, 6), Parent = text })
			h.titleLabel = label("ui-dialog-title", 1)
			h.titleLabel.Parent = text
			h.descriptionLabel = label("ui-dialog-description", 2)
			h.descriptionLabel.Parent = text

			if showClose then
				h.closeButton = Button.new({
					app = h.app,
					text = "×",
					variant = "ghost",
					size = "icon",
					name = "Close",
					onClick = function()
						h:close()
					end,
				})
				h.closeButton.Instance.AnchorPoint = Vector2.new(1, 0)
				h.closeButton.Instance.Position = UDim2.new(1, 0, 0, -4)
				h.closeButton.Instance.Parent = header
				h.maid:give(h.closeButton)
			end

			local body = Component.box({ Name = "Body", LayoutOrder = 2, Parent = content })
			Component.list({ Padding = Component.space(h.app, "Space4", 16), Parent = body })
			Component.adopt(body, p.children)
			body.Visible = p.children ~= nil

			local footer = Component.box({ Name = "Footer", LayoutOrder = 3, Parent = content })
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

			h.overlay, h.content, h.body, h.footer, h.actions = overlay, content, body, footer, actionHandles
			Component.claimSelection(h.app, root)
			return root
		end,
		watch = {
			title = function(h, title)
				h.titleLabel.Text = title
				h.titleLabel.Visible = title ~= ""
			end,
			description = function(h, description)
				h.descriptionLabel.Text = description
				h.descriptionLabel.Visible = description ~= ""
			end,
			open = function(h, open, previous, initial)
				local wasOpen = not initial and previous == true
				h.Instance.Visible = open
				if open and not wasOpen then
					layer += 1
					h.Instance.ZIndex = 10 + layer
					popBack = h.app.input:pushBack(function()
						if dismissible then
							h:close()
						end
						return true
					end)
					popScope = h.app.input:pushScope({
						root = h.content,
						defaultFocus = function()
							local last = actionHandles[#actionHandles]
							return if last then last.Instance else (h.closeButton and h.closeButton.Instance)
						end,
					})
				elseif not open and wasOpen then
					if popBack then
						popBack()
						popBack = nil
					end
					if popScope then
						popScope()
						popScope = nil
					end
				end
				if open ~= wasOpen and p.onOpenChange then
					p.onOpenChange(open, h)
				end
			end,
		},
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
	handle.maid:give(function()
		if popBack then
			popBack()
		end
		if popScope then
			popScope()
		end
	end)

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
