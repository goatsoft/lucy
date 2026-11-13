--!strict
--[[
	Dialog and alert dialog

		local dialog = Dialog.new({
			id = "quit",
			title = "Leave match?",
			description = "You will drop your cash.",
			header = { ... },                       -- under the title, stays put (dialog.headerSlot)
			children = { ... },                     -- into dialog.body, which scrolls
			footer = { ... },                       -- above the actions, stays put (dialog.footerSlot)
			actions = {
				{ text = "Stay", variant = "outline" },
				{ text = "Leave", variant = "destructive", onClick = function(dialog) leave() end },
			},
			dismissible = true,       -- back keys / overlay / close button
			closeOnOverlay = true,
			modal = true,             -- false: no focus trap, presses reach what is behind
			scrim = true,             -- false: no dimmed backdrop
			showClose = true,
			defaultFocus = function(dialog) return dialog.actions[1] end, -- or an object or handle;
			                          -- a non modal dialog takes focus only when this is given
			returnFocus = nil,        -- focus on close: nil what opened it, an object, handle or
			                          -- getter, or false for nothing
			size = "md",              -- sm | md | lg | xl | full: how wide it gets
			titlePlacement = nil,     -- "inside" | "edge": the title on a plate standing on the top
			                          -- edge; nil: the PanelTitleEdge token (Lucy's themes: 0, inside)
			maxWidth = nil,           -- pixels, instead of size
			maxHeight = nil,          -- pixels (a number, ref or getter); the body scrolls past it
			onOpenChange = function(open, dialog) end,
		})
		dialog:open()  dialog:close()  dialog:toggle()
		app.state:set("ui.quit.open", true)   -- same thing, from anywhere

		Dialog.alert({ title, description, confirmText, cancelText, destructive, onConfirm, onCancel })
		-- back presses Cancel (backCancels = false to block it); destroyed once closed

	An action closes the dialog after its onClick unless onClick returns false.
	The body (dialog.body holds the children) scrolls when the dialog would be
	taller than maxHeight or the screen; the title, the header and footer slots
	and the actions stay put (a slot whose children all hide drops out, gap and all). dialog.bodyRoom() is the height the body may take before it
	scrolls, in the dialog's own units (a getter that follows the screen; math.huge until
	mounted): for a body that should fit its room rather than scroll.
	Dialogs mount into the app's "modal" portal (above every scene) unless Parent is given,
	and stack with sheets and popups by the order they open (Core/Overlay).

	Input: while open a modal dialog is a focus scope (Tab/arrows/gamepad stay inside,
	the primary action is selected when navigating), registers a back handler, and
	its content is a SelectionGroup so the gamepad cannot wander out. Focus goes
	back to whatever had it when the dialog closes, or the control nearest it
	when that can't take focus any more. A non modal dialog given defaultFocus takes
	focus and gives it back the same way, but traps nothing.

	The panel sits in a frame (dialog.frame, Core/PanelFrame): with the PanelShadow token set, a
	shadow offset behind it (dialog.shadow, ui-dialog-shadow); with the title on the edge, a plate
	(dialog.plate, ui-dialog-plate) whose label is dialog.titleLabel. dialog.content is the panel.

	State keys: open, title, description.
]]

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Heading = require(script.Parent.Heading)
local Overlay = require(script.Parent.Parent.Core.Overlay)
local PanelFrame = require(script.Parent.Parent.Core.PanelFrame)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local ScrollArea = require(script.Parent.ScrollArea)

local Dialog = {}

-- How wide each size gets, in pixels.
Dialog.sizes = { sm = 384, md = 448, lg = 512, xl = 640, full = math.huge }

local OUT_SIZE = Element.out("AbsoluteSize")

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
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
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
		-- A short screen (a phone held sideways) has little height to give to padding
		selector = ".ui-dialog-inner.ui-dialog-short::UIPadding",
		priority = 1,
		properties = {
			PaddingTop = "$Space4",
			PaddingBottom = "$Space4",
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
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
for _, rule in PanelFrame.rules("dialog") do
	table.insert(rules, rule)
end
Dialog.rules = rules

function Dialog.new(props: { [string]: any }?)
	local p: Component.Props = props or {}
	local dismissible = p.dismissible ~= false
	local modal = p.modal ~= false
	-- A modal closes on an outside press unless told not to; a non modal one only when asked.
	local closeOnOverlay = dismissible
		and (if modal then p.closeOnOverlay ~= false else p.closeOnOverlay == true)
	local showClose = dismissible and p.showClose ~= false
	local actionHandles = {}
	local sizeName = p.size or "md"
	local width = p.maxWidth or Dialog.sizes[sizeName]
	if width == nil then
		error(`[Lucy] unknown Dialog size "{tostring(sizeName)}" (sm, md, lg, xl or full)`, 2)
	end

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
				AutomaticSize = Enum.AutomaticSize.Y,
				Active = true,
				Tags = { "ui-dialog-content" },
			})
			-- The frame the overlay places: the panel, its shadow and an edge title's plate
			local parts = PanelFrame.new(h.app, content, {
				kind = "dialog",
				title = h:ref("title"),
				placement = p.titlePlacement,
			})
			local frame = parts.frame
			Element.hydrate(frame, {
				Size = UDim2.new(1, -32, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			})
			Element.new("UISizeConstraint", {
				MaxSize = function(): Vector2
					return Vector2.new(width + parts.offset(), math.huge)
				end,
			}).Parent =
				frame
			-- Padding and layout live on an inner frame, so the close button can sit in
			-- the content's own corner.
			local short = Composables.useResponsive(h.app, { short = true, default = false })
			local inner = Element.new("Frame", {
				Name = "Inner",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Tags = { "ui-dialog-inner" :: any, ["ui-dialog-short"] = short },
			}) :: Frame
			inner.Parent = content
			local gap = Component.space(h.app, "Space4", 16)
			Component.list({ Padding = gap, Parent = inner })

			-- Measured, so the body knows how much height is left for it.
			local headerSize = Reactive.ref(Vector2.zero)
			local footerSize = Reactive.ref(Vector2.zero)
			-- Set once the footer is made; bodyCap reads it
			local footerShown: () -> boolean = function()
				return false
			end
			local header = Element.new("Frame", {
				Name = "Header",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
				[OUT_SIZE] = headerSize :: any,
			})
			header.Parent = inner
			Component.list({ Padding = gap, Parent = header })
			-- The title over its description (beside it on a short screen: Components/Heading)
			-- (with the title on the edge, the description alone)
			local titleRef = h:ref("title")
			local text, titleLabel, descriptionLabel, headingShown = Heading.new(h.app, {
				title = function(): string
					return if parts.edge then "" else titleRef()
				end,
				description = h:ref("description"),
				titleTag = "ui-dialog-title",
				descriptionTag = "ui-dialog-description",
			})
			-- The close button sits in the top right corner: the top row stops short of it
			local closeRoom = if showClose then 44 else 0
			text.Size = UDim2.new(1, -closeRoom, 0, 0)
			text.LayoutOrder = 1
			text.Parent = header
			h.titleLabel = parts.titleLabel or titleLabel
			h.descriptionLabel = descriptionLabel
			-- The header slot: filters, tabs or anything else that stays put over the body.
			-- Shown while anything in it is, so a slot whose children all hide takes no gap.
			local headerSlot = Component.box({
				Name = "HeaderSlot",
				LayoutOrder = 2,
				Parent = header,
			})
			Component.list({ Padding = gap, Parent = headerSlot })
			-- With the heading's row gone (title on the edge, no description) the slot is the top row
			Element.new("UIPadding", {
				PaddingRight = function(): UDim
					return UDim.new(0, if headingShown() then 0 else closeRoom)
				end,
			}).Parent =
				headerSlot
			if p.header then
				Component.adopt(headerSlot, p.header)
			end
			Element.hydrate(headerSlot, { Visible = Composables.useHasVisibleChild(headerSlot) })

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

			-- The body scrolls in what is left of the overlay's height (and maxHeight)
			-- after the padding, header, footer and gaps.
			local overlayRef: Reactive.Ref<Overlay.Overlay?> = Reactive.ref(nil :: Overlay.Overlay?)
			-- The inner padding, as the rules above set it
			local function pad(): number
				return if short()
					then Component.space(h.app, "Space4", 16).Offset
					else Component.space(h.app, "Space6", 24).Offset
			end
			local function bodyCap(): number
				local overlay = overlayRef()
				if not overlay then
					return math.huge
				end
				local cap = overlay.maxHeight()
				if p.maxHeight ~= nil then
					cap = math.min(cap, Reactive.toValue(p.maxHeight))
				end
				local scale = Scroll.scaleOf(content)
				if scale <= 0 then
					scale = 1
				end
				local used = pad() * 2 + headerSize().Y / scale + gap.Offset + parts.rise() + parts.offset()
				if footerShown() then
					used += footerSize().Y / scale + gap.Offset
				end
				return math.max(0, math.floor(cap - used))
			end
			local scroll = ScrollArea.new({
				app = h.app,
				name = "Body",
				layoutOrder = 2,
				maxHeight = bodyCap,
				visible = p.children ~= nil,
				children = p.children,
			})
			scroll.Instance.Parent = inner
			local body = scroll.content
			Component.list({ Padding = gap, Parent = body })
			h.scroll = scroll
			h.bodyRoom = bodyCap

			local footer = Element.new("Frame", {
				Name = "Footer",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				[OUT_SIZE] = footerSize :: any,
			})
			footer.Parent = inner
			Component.list({ Padding = gap, Parent = footer })
			-- The footer slot stays put under the body, over the actions. Shown while
			-- anything in it is (key hints hidden on touch leave no gap).
			local footerSlot = Component.box({
				Name = "FooterSlot",
				LayoutOrder = 1,
				Parent = footer,
			})
			Component.list({ Padding = gap, Parent = footerSlot })
			if p.footer then
				Component.adopt(footerSlot, p.footer)
			end
			local slotHasVisible = Composables.useHasVisibleChild(footerSlot)
			Element.hydrate(footerSlot, { Visible = slotHasVisible })
			local actionsRow = Component.box({ Name = "Actions", LayoutOrder = 2, Parent = footer })
			Component.list({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = Component.space(h.app, "Space2", 8),
				Parent = actionsRow,
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
				actionHandle.Instance.Parent = actionsRow
				table.insert(actionHandles, actionHandle)
				h.maid:give(actionHandle)
			end
			actionsRow.Visible = #actionHandles > 0
			local hasActions = #actionHandles > 0
			footerShown = function(): boolean
				return hasActions or slotHasVisible()
			end
			Element.hydrate(footer, { Visible = footerShown })

			-- Stacking, back, focus and the dimmed backdrop (owned, so destroy pops them).
			local overlay = Overlay.use(h.app, {
				open = open,
				content = frame,
				returnFocus = p.returnFocus,
				presentation = "center",
				modal = modal,
				-- A non modal dialog takes focus only when told what to focus
				focus = p.defaultFocus ~= nil,
				scrim = if p.scrim == false then false else nil,
				dismissible = dismissible,
				onBack = p._onBack,
				closeOnOutside = closeOnOverlay,
				parent = false,
				id = h.id,
				name = "Dialog",
				tags = { "ui-dialog" },
				defaultFocus = function()
					local chosen = p.defaultFocus
					if type(chosen) == "function" then
						chosen = chosen(h)
					end
					if chosen ~= nil then
						return chosen
					end
					local last = actionHandles[#actionHandles]
					return if last then last.Instance else (h.closeButton and h.closeButton.Instance)
				end,
			})
			local root = overlay.root
			overlayRef(overlay)
			h.overlay, h.content, h.body, h.footer, h.actions =
				overlay.scrim, content, body, footer, actionHandles
			h.frame, h.shadow, h.plate = frame, parts.shadow, parts.plate
			h.headerSlot, h.footerSlot, h.actionsRow = headerSlot, footerSlot, actionsRow
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
-- Back presses Cancel unless backCancels = false. It is destroyed once it
-- closes, so each alert is used once.
function Dialog.alert(props: { [string]: any })
	local p = table.clone(props)
	p.dismissible = false
	p.open = if p.open == nil then true else p.open
	local handle: any = nil
	if props.backCancels ~= false then
		p._onBack = function()
			if handle and not handle.destroyed then
				handle.actions[1]:click()
			end
		end
	end
	local onOpenChange = props.onOpenChange
	local wasOpen = false
	p.onOpenChange = function(isOpen: boolean, h: any)
		if onOpenChange then
			onOpenChange(isOpen, h)
		end
		if isOpen then
			wasOpen = true
		elseif wasOpen then
			-- After the close has run its course (sounds, focus going back).
			task.defer(function()
				if not h.destroyed then
					h:destroy()
				end
			end)
		end
	end
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
	handle = Dialog.new(p)
	return handle
end

return Dialog
