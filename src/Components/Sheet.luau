--!strict
--[[
	Sheet: a panel that slides in from the side of the screen; a drawer from the
	bottom on touch.

		local settings = Sheet.new({
			id = "settings",
			title = "Settings",
			description = "Saved to your profile.",
			children = { ... },                     -- into sheet.body, which scrolls
			actions = {                             -- buttons along the bottom, like Dialog's
				{ text = "Done" },
			},
			side = "right",           -- left | right (the panel; touch always uses the bottom)
			width = 360,              -- the panel's width, at most 90% of the screen
			presentation = "auto",    -- auto | panel | drawer
			dismissible = true,       -- back keys / outside press / close button
			closeOnOverlay = true,
			modal = true,             -- false: no focus trap, presses reach what is behind
			scrim = true,             -- false: no dimmed backdrop
			showClose = true,
			onOpenChange = function(open, sheet) end,
		})
		settings:open()  settings:close()  settings:toggle()

	Sheets float on the app's overlay layer with dialogs and popups, newest on
	top. The panel or drawer is decided each time it opens: a drawer when the
	player last used touch, a panel otherwise. A long body scrolls inside it.

	State keys: open, title, description.
]]

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Overlay = require(script.Parent.Parent.Core.Overlay)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local ScrollArea = require(script.Parent.ScrollArea)

local Sheet = {}

local OUT_SIZE = Element.out("AbsoluteSize")

Sheet.rules = {
	{
		selector = ".ui-sheet-content",
		priority = 0,
		properties = { BackgroundColor3 = "$Background", BorderSizePixel = 0 },
	},
	{
		selector = ".ui-sheet-content::UIStroke",
		priority = 0,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-sheet-inner::UIPadding",
		priority = 0,
		properties = {
			PaddingTop = "$Space6",
			PaddingBottom = "$Space6",
			PaddingLeft = "$Space6",
			PaddingRight = "$Space6",
		},
	},
	{ selector = ".ui-sheet-drawer::UICorner", priority = 0, properties = { CornerRadius = "$RadiusLg" } },
	{
		selector = ".ui-sheet-handle",
		priority = 0,
		properties = { BackgroundColor3 = "$Border", BorderSizePixel = 0 },
	},
	{
		selector = ".ui-sheet-title",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontDisplay",
			TextSize = "$TextLg",
		},
	},
	{
		selector = ".ui-sheet-description",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-sheet-part",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
} :: { Component.Rule }

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

local spec: Component.Spec = {
	kind = "sheet",
	defaults = { open = false, title = "", description = "" },
	rules = Sheet.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local open = h:ref("open")
		local dismissible = p.dismissible ~= false
		local modal = p.modal ~= false
		local closeOnOverlay = dismissible
			and (if modal then p.closeOnOverlay ~= false else p.closeOnOverlay == true)
		local showClose = dismissible and p.showClose ~= false
		local actionHandles = {}

		-- The overlay is made last (it needs the content); parts that depend on it
		-- read it through this ref.
		local overlayRef: Reactive.Ref<Overlay.Overlay?> = Reactive.ref(nil :: Overlay.Overlay?)
		local function isDrawer(): boolean
			local overlay = overlayRef()
			return overlay ~= nil and overlay.presentation() == "drawer"
		end

		local pad = Component.space(app, "Space6", 24).Offset
		local gap = Component.space(app, "Space4", 16).Offset
		local headerSize = Reactive.ref(Vector2.zero)
		local footerSize = Reactive.ref(Vector2.zero)

		local handleBar = Element.new("Frame", {
			Name = "Handle",
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(40, 4),
			Visible = isDrawer,
			Tags = { "ui-sheet-handle" },
			Element.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		local handleRow = Element.new("Frame", {
			Name = "HandleRow",
			Size = UDim2.new(1, 0, 0, 4),
			LayoutOrder = 1,
			Visible = isDrawer,
			Tags = { "ui-sheet-part" },
			handleBar,
		})
		handleBar.Position = UDim2.fromScale(0.5, 0)

		local text = Component.box({
			Name = "Text",
			Size = UDim2.new(1, if showClose then -44 else 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		Component.list({ Padding = UDim.new(0, 6), Parent = text })
		h.titleLabel = label("ui-sheet-title", 1, h:ref("title"))
		h.titleLabel.Parent = text
		h.descriptionLabel = label("ui-sheet-description", 2, h:ref("description"))
		h.descriptionLabel.Parent = text

		local header = Element.new("Frame", {
			Name = "Header",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Tags = { "ui-sheet-part" },
			[OUT_SIZE] = headerSize :: any,
			text,
		})
		if showClose then
			h.closeButton = Button.close({
				app = app,
				onClick = function()
					h:close()
				end,
			})
		end

		local footer = Element.new("Frame", {
			Name = "Footer",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 5,
			Tags = { "ui-sheet-part" },
			[OUT_SIZE] = footerSize :: any,
		})
		Component.list({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = Component.space(app, "Space2", 8),
			Parent = footer,
		})
		for index, action in p.actions or {} do
			local actionHandle = Button.new({
				app = app,
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
		end
		footer.Visible = #actionHandles > 0

		-- The body may use what the overlay offers, less the header, footer, padding and gaps.
		local content: Frame
		local function bodyCap(): number
			local overlay = overlayRef()
			if not overlay then
				return math.huge
			end
			local scale = if content then Scroll.scaleOf(content) else 1
			if scale <= 0 then
				scale = 1
			end
			local used = pad * 2 + headerSize().Y / scale + gap
			if #actionHandles > 0 then
				used += footerSize().Y / scale + gap
			end
			if isDrawer() then
				used += 4 + gap
			end
			return math.max(0, math.floor(overlay.maxHeight() - used))
		end
		local body = ScrollArea.new({
			app = app,
			maxHeight = bodyCap,
			children = p.children,
			layoutOrder = 3,
			name = "Body",
		})
		-- Several children stack, as in a Dialog's body.
		Component.list({ Padding = UDim.new(0, gap), Parent = body.content })

		-- In a panel the footer sits at the bottom; this takes the space between.
		local spacer = Element.new("Frame", {
			Name = "Spacer",
			Size = UDim2.fromScale(1, 0),
			LayoutOrder = 4,
			Visible = function()
				return not isDrawer()
			end,
			Tags = { "ui-sheet-part" },
			Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})

		-- Padding and layout live on an inner frame, so the close button can sit in
		-- the content's own corner. In a panel it is full height, so the footer
		-- reaches the bottom; in a drawer it fits its children.
		local inner = Element.new("Frame", {
			Name = "Inner",
			Size = function(): UDim2
				return if isDrawer() then UDim2.fromScale(1, 0) else UDim2.fromScale(1, 1)
			end,
			AutomaticSize = Enum.AutomaticSize.Y,
			Tags = { "ui-sheet-inner", "ui-sheet-part" },
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, gap),
			}),
			handleRow,
			header,
			body.Instance,
			spacer,
			footer,
		})

		content = Element.new("Frame", {
			Name = "Content",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Active = true,
			Tags = { "ui-sheet-content" :: any, ["ui-sheet-drawer"] = isDrawer },
			inner,
		}) :: Frame
		if h.closeButton then
			local inset = Component.space(app, "Space1", 4).Offset
			local close = h.closeButton.Instance
			close.AnchorPoint = Vector2.new(1, 0)
			close.Position = UDim2.new(1, -inset, 0, inset)
			close.ZIndex = 3
			close.Parent = content
		end

		local overlay = Overlay.use(app, {
			open = open,
			content = content,
			presentation = p.presentation or "auto",
			prefer = "panel",
			panelSide = p.side,
			width = p.width,
			modal = modal,
			scrim = if p.scrim == false then false else nil,
			dismissible = dismissible,
			closeOnOutside = closeOnOverlay,
			parent = false,
			id = h.id,
			name = "Sheet",
			tags = { "ui-sheet" },
			defaultFocus = function()
				local first = Overlay.firstSelectable(body.content)
				if first then
					return first
				end
				local last = actionHandles[#actionHandles]
				return if last then last.Instance else (h.closeButton and h.closeButton.Instance)
			end,
		})
		overlayRef(overlay)

		h.overlay, h.content, h.body, h.footer, h.actions =
			overlay.scrim, content, body, footer, actionHandles
		h.handleBar, h.presentation = handleBar, overlay.presentation
		Component.claimSelection(app, overlay.root)

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
		return overlay.root
	end,
}

function Sheet.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	function handle.open(h)
		h:set("open", true)
	end
	function handle.close(h)
		h:set("open", false)
	end
	function handle.toggle(h)
		h:set("open", not h:get("open"))
	end
	local p: Component.Props = props or {}
	if not (p.Parent or p.parent) then
		handle.Instance.Parent = handle.app:portal("modal")
	end
	return handle
end

return Sheet
