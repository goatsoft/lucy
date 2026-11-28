--!strict
--[[
	Sheet: a panel that slides in from the side of the screen; a drawer from the
	bottom on touch.

		local settings = Sheet.new({
			id = "settings",
			title = "Settings",
			description = "Saved to your profile.",
			header = { ... },                       -- under the title, stays put (sheet.headerSlot)
			corner = { ... },                       -- beside the close button, top right (sheet.cornerSlot)
			children = { ... },                     -- into sheet.body, which scrolls
			footer = { ... },                       -- above the actions, stays put (sheet.footerSlot)
			build = function(sheet) return { header, children, footer, corner } end,
			                          -- in place of those four: called the first time the sheet opens,
			                          -- so nothing in it is made until then (see below)
			mount = "shown",          -- shown: built on its first open | immediate: when made
			keep = true,              -- false: the whole panel is removed once the sheet has closed,
			                          -- and built again on the next open
			onBuild = function(sheet) end, -- once its panel exists, each time it is built
			actions = {                             -- buttons along the bottom, like Dialog's
				{ text = "Done" },
			},
			side = "right",           -- left | right (the panel; touch always uses the bottom)
			dock = nil,               -- a name: sheets in the same dock open side by side from the edges,
			                          -- each at its `side`, the newest at the edge, pushing the others
			                          -- over (Core/Dock); one backdrop and one focus scope for them all;
			                          -- always a panel; one dock open at a time
			dockPin = false,          -- with dock: true holds this sheet at its edge; sheets opened
			                          -- after it open inward beside it (a menu and its sub-sheets)
			dockSlide = true,         -- with dock: false appears and goes without sliding
			minWidth = nil,           -- with dock: how narrow it may go when the screen is short of
			                          -- room; it then scrolls sideways (default: width, never narrower)
			width = 360,              -- the panel's width, at most 90% of the screen
			presentation = "auto",    -- auto | panel | drawer
			fill = false,             -- true: always as tall as it may be, whatever the body holds (a
			                          -- drawer whose tabs hold more or less never grows or shrinks)
			titlePlacement = nil,     -- "inside" | "edge": the title on a plate standing on the top
			                          -- edge; nil: the PanelTitleEdge token (Lucy's themes: 0, inside)
			dismissible = true,       -- back keys / outside press / close button
			closeOnOverlay = true,
			modal = true,             -- false: no focus trap, presses reach what is behind
			scrim = true,             -- false: no dimmed backdrop
			showClose = true,
			defaultFocus = nil,       -- what keyboard and gamepad select first (an object, handle or
			                          -- function called with the sheet); else the first thing in the
			                          -- body. A non modal sheet takes focus only when this is given
			returnFocus = nil,        -- focus on close: nil what opened it, an object, handle or
			                          -- getter, or false for nothing
			onOpenChange = function(open, sheet) end,
		})
		settings:open()  settings:close()  settings:toggle()

	The header and footer slots stay where they are while the body scrolls
	between them; the body gets whatever height they leave. sheet.bodyRoom() is that height, in
	the sheet's own units (a getter that follows the screen): for a body that should fit it.

	Sheets float on the app's overlay layer with dialogs and popups, newest on
	top. The panel or drawer is decided each time it opens: a drawer when the
	player last used touch, a panel otherwise. A long body scrolls inside it.

	The panel sits in a frame (sheet.frame, Core/PanelFrame): with the PanelShadow token set, a
	shadow offset behind it (sheet.shadow, ui-sheet-shadow); with the title on the edge, a plate
	(sheet.plate, ui-sheet-plate) whose label is sheet.titleLabel, and the room for it comes off
	the panel's top. sheet.content is the panel.

	A sheet is a root and a presence (ADR 0050, Radix's Root and Presence): Sheet.new makes the
	handle, its state and one empty frame in the modal portal (sheet.Instance); the overlay, the
	panel and everything in it are built on the first open (mount = "shown") or when it is made
	(mount = "immediate"), before anything sees it open (placing, focus, onOpenChange), and the
	first show waits a frame off the screen while its text is measured. keep = false takes the
	whole presence away once it has closed. sheet:build() builds it ahead without opening. Every
	field that points into the panel (frame, content, body, the slots, actions, closeButton,
	titleLabel) is nil until then: onBuild(sheet) runs once they exist, each time it is built.
	`build` in place of the slots makes the content then too, put in the slots in the order
	header, children, footer, corner; slots and build together is an error.

	State keys: open, title, description.
]]

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Deferred = require(script.Parent.Parent.Core.Deferred)
local Dock = require(script.Parent.Parent.Core.Dock)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Heading = require(script.Parent.Heading)
local Overlay = require(script.Parent.Parent.Core.Overlay)
local PanelCorner = require(script.Parent.PanelCorner)
local PanelFrame = require(script.Parent.Parent.Core.PanelFrame)
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
	{
		-- A short screen (a phone held sideways) has little height to give to padding, as a dialog
		selector = ".ui-sheet-inner.ui-sheet-short::UIPadding",
		priority = 1,
		properties = {
			PaddingTop = "$Space4",
			PaddingBottom = "$Space4",
			PaddingLeft = "$Space4",
			PaddingRight = "$Space4",
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
for _, rule in PanelFrame.rules("sheet") do
	table.insert(Sheet.rules, rule)
end

local spec: Component.Spec = {
	kind = "sheet",
	defaults = { open = false, title = "", description = "" },
	rules = Sheet.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local open = h:ref("open")
		-- One build function in place of the slots: the content is made on the first open
		local building = Deferred.building(p, "Sheet")
		-- When the presence is built (ADR 0050): on the first open, or when it is made; kept or not
		local mount, keep = Deferred.mode(p, "Sheet")
		if p.onBuild ~= nil and type(p.onBuild) ~= "function" then
			error(`[Lucy] Sheet: onBuild is a function, not "{tostring(p.onBuild)}"`, 0)
		end
		h._mount = mount
		-- The overlay is made last in the presence (it needs the content); parts that depend on it
		-- read it through this ref.
		local overlayRef: Reactive.Ref<Overlay.Overlay?> = Reactive.ref(nil :: Overlay.Overlay?)
		-- What the overlay, focus and the owner follow: true once it is open and its presence is
		-- built (and a write to it writes `open`). Set below, before anything is built
		local shown: Reactive.Ref<boolean> = open
		-- The body's room and the presentation, from the presence while it is built
		local capRef: Reactive.Ref<(() -> number)?> = Reactive.ref(nil :: (() -> number)?)
		h.bodyRoom = function(): number
			local cap = capRef()
			return if cap then cap() else math.huge
		end
		h.presentation = function(): string?
			local overlay = overlayRef()
			return if overlay then overlay.presentation() else nil
		end

		-- The root's one instance (ADR 0050): the host the presence is built in, in the portal
		local host = Element.new("Frame", {
			Name = "Sheet",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = function(): boolean
				local overlay = overlayRef()
				return overlay ~= nil and overlay.visible()
			end,
		}) :: Frame

		-- The presence: the overlay, the panel and everything in it, built on the first open
		-- (or when made, mount = "immediate"), in its own scope (Core/Deferred)
		local function presence()
			local dismissible = p.dismissible ~= false
			local modal = p.modal ~= false
			local closeOnOverlay = dismissible
				and (if modal then p.closeOnOverlay ~= false else p.closeOnOverlay == true)
			local showClose = dismissible and p.showClose ~= false
			local actionHandles = {}

			local function isDrawer(): boolean
				local overlay = overlayRef()
				return overlay ~= nil and overlay.presentation() == "drawer"
			end

			-- The inner padding, as the rules above set it (smaller on a short screen, as a dialog's)
			local short = Composables.useResponsive(app, { short = true, default = false })
			local function pad(): number
				return if short()
					then Component.space(app, "Space4", 16).Offset
					else Component.space(app, "Space6", 24).Offset
			end
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
			-- The drawer's handle sits in the top padding, so the first row starts where a dialog's does
			-- (placed with the panel, below)

			-- The title over its description (beside it on a short screen: Components/Heading)
			-- (with the title on the edge, the description alone: the title is on the frame's plate)
			local edge = PanelFrame.edge(app, p.titlePlacement)
			local titleRef = h:ref("title")
			local text, titleLabel, descriptionLabel, headingShown = Heading.new(h.app, {
				title = function(): string
					return if edge then "" else titleRef()
				end,
				description = h:ref("description"),
				titleTag = "ui-sheet-title",
				descriptionTag = "ui-sheet-description",
			})
			-- The close button (and the corner slot beside it) in the top right corner, the same place on
			-- every sheet: the top row stops short of it. The corner is made with the panel, below.
			local cornerRef: Reactive.Ref<PanelCorner.Corner?> = Reactive.ref(nil :: PanelCorner.Corner?)
			local function cornerRoom(): number
				local corner = cornerRef()
				return if corner then corner.room() else 0
			end
			Element.hydrate(text, {
				Size = function(): UDim2
					return UDim2.new(1, -cornerRoom(), 0, 0)
				end,
			})
			h.titleLabel = titleLabel
			h.descriptionLabel = descriptionLabel

			text.LayoutOrder = 1
			-- The header slot: filters, tabs or anything else that stays put over the body.
			local headerSlot = Component.box({
				Name = "HeaderSlot",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Visible = p.header ~= nil,
			})
			Component.list({ Padding = UDim.new(0, gap), Parent = headerSlot })
			-- With the heading's row gone (title on the edge, no description) the slot is the top row
			Element.new("UIPadding", {
				PaddingRight = function(): UDim
					return UDim.new(0, if headingShown() then 0 else cornerRoom())
				end,
			}).Parent =
				headerSlot
			if p.header then
				Component.adopt(headerSlot, p.header)
			end

			local header = Element.new("Frame", {
				Name = "Header",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Tags = { "ui-sheet-part" },
				[OUT_SIZE] = headerSize :: any,
				Element.new("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, gap),
				}),
				text,
				headerSlot,
			})
			-- The footer: the footer slot (stays put under the body), then the actions.
			local footerSlot = Component.box({
				Name = "FooterSlot",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
				Visible = p.footer ~= nil,
			})
			Component.list({ Padding = UDim.new(0, gap), Parent = footerSlot })
			if p.footer then
				Component.adopt(footerSlot, p.footer)
			end
			local actionsRow = Element.new("Frame", {
				Name = "Actions",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Tags = { "ui-sheet-part" },
			})
			Component.list({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = Component.space(app, "Space2", 8),
				Parent = actionsRow,
			})
			local footer = Element.new("Frame", {
				Name = "Footer",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 5,
				Tags = { "ui-sheet-part" },
				[OUT_SIZE] = footerSize :: any,
				Element.new("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, gap),
				}),
				footerSlot,
				actionsRow,
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
				actionHandle.Instance.Parent = actionsRow
				table.insert(actionHandles, actionHandle)
			end
			actionsRow.Visible = #actionHandles > 0
			local hasActions = #actionHandles > 0
			-- With build the slots fill on open, so whether they show is followed, not fixed here
			local footerFilled = if building then Composables.useHasVisibleChild(footerSlot) else nil
			local function hasFooter(): boolean
				return hasActions or p.footer ~= nil or (footerFilled ~= nil and footerFilled())
			end
			if building then
				Element.hydrate(footer, { Visible = hasFooter })
				Element.hydrate(footerSlot, { Visible = footerFilled })
				Element.hydrate(headerSlot, { Visible = Composables.useHasVisibleChild(headerSlot) })
			else
				footer.Visible = hasFooter()
			end

			-- In a drawer the body may use what the overlay offers, less the header, footer, padding
			-- and gaps. In a panel it fills what the header and footer leave (below), so the footer
			-- sits at the bottom with no gap, however the panel is placed under the top bar.
			local content: Frame
			local parts: PanelFrame.Parts? = nil
			local function bodyCap(): number
				local overlay = overlayRef()
				if not overlay then
					return math.huge
				end
				local scale = if content then Scroll.scaleOf(content) else 1
				if scale <= 0 then
					scale = 1
				end
				local used = pad() * 2 + headerSize().Y / scale + gap
				if parts then
					used += parts.rise() + parts.offset() + parts.clear()
				end
				if hasFooter() then
					used += footerSize().Y / scale + gap
				end
				if isDrawer() then
					local safe = overlay.safeBottom()
					if safe > 0 then
						used += safe + gap
					end
				end
				return math.max(0, math.floor(overlay.maxHeight() - used))
			end
			-- A docked sheet that may be squeezed scrolls sideways as well (ADR 0062)
			local squeezable = type(p.dock) == "string"
				and type(p.minWidth) == "number"
				and p.minWidth < (p.width or Overlay.panelWidth)
			local body = ScrollArea.new({
				app = app,
				direction = if squeezable then "both" else nil,
				maxHeight = bodyCap,
				minHeight = if p.fill then bodyCap else nil,
				children = p.children,
				layoutOrder = 3,
				name = "Body",
			})
			-- Several children stack, as in a Dialog's body.
			Component.list({ Padding = UDim.new(0, gap), Parent = body.content })
			-- In a panel the body takes all the height between the header and the footer
			local fill = Element.new("UIFlexItem", {
				FlexMode = function(): Enum.UIFlexMode
					return if isDrawer() then Enum.UIFlexMode.None else Enum.UIFlexMode.Fill
				end,
			})
			fill.Parent = body.Instance

			-- Room for a phone's home bar under a drawer; the background still runs to the edge.
			local safeArea = Element.new("Frame", {
				Name = "SafeArea",
				LayoutOrder = 6,
				BackgroundTransparency = 1,
				Size = function(): UDim2
					local overlay = overlayRef()
					return UDim2.new(1, 0, 0, if overlay then overlay.safeBottom() else 0)
				end,
				Visible = function(): boolean
					local overlay = overlayRef()
					return isDrawer() and overlay ~= nil and overlay.safeBottom() > 0
				end,
			})

			-- Padding and layout live on an inner frame, so the close button can sit in
			-- the content's own corner. In a panel it is the panel's height (the body fills
			-- what is left, so the footer reaches the bottom); in a drawer it fits its children.
			local inner = Element.new("Frame", {
				Name = "Inner",
				Size = function(): UDim2
					return if isDrawer() then UDim2.fromScale(1, 0) else UDim2.fromScale(1, 1)
				end,
				AutomaticSize = function(): Enum.AutomaticSize
					return if isDrawer() then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
				end,
				Tags = { "ui-sheet-inner" :: any, "ui-sheet-part", ["ui-sheet-short"] = short },
				Element.new("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, gap),
				}),
				header,
				body.Instance,
				footer,
				safeArea,
			})

			-- A drawer fits its children; a panel keeps the height the overlay gives it (the screen's,
			-- less the top bar), or it would grow past the bottom of the screen
			content = Element.new("Frame", {
				Name = "Content",
				AutomaticSize = function(): Enum.AutomaticSize
					return if isDrawer() then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
				end,
				Active = true,
				Tags = { "ui-sheet-content" :: any, ["ui-sheet-drawer"] = isDrawer },
				inner,
			}) :: Frame

			-- The frame the overlay places: the panel (filling it, or fitting its children in a
			-- drawer), its shadow and an edge title's plate
			local framed = PanelFrame.new(app, content, {
				kind = "sheet",
				title = titleRef,
				placement = p.titlePlacement,
				fill = function(): boolean
					return not isDrawer()
				end,
			})
			parts = framed
			local corner = PanelCorner.new(app, content, {
				close = showClose,
				onClose = function()
					h:close()
				end,
				children = p.corner,
				clear = framed.clear,
			})
			h.cornerSlot = corner.slot
			-- The handle, centred in the top padding (an edge title's clearance moves the content down: the
			-- handle moves back up, as the corner does)
			Element.hydrate(handleBar, {
				Position = function(): UDim2
					return UDim2.new(0.5, 0, 0, math.max(0, (pad() - 4) // 2) - framed.clear())
				end,
				ZIndex = 3,
			})
			handleBar.Parent = content
			h.closeButton = corner.closeButton
			cornerRef(corner)
			Element.hydrate(framed.frame, {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = function(): Enum.AutomaticSize
					return if isDrawer() then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
				end,
			})
			if framed.titleLabel then
				h.titleLabel = framed.titleLabel
			end

			-- With build: what it makes, in the slots in order (0049, 2)
			if building then
				Deferred.placeBuild(h, p, "Sheet", {
					header = headerSlot,
					children = body.content,
					footer = footerSlot,
					corner = corner.slot,
				})
			end

			local function firstFocus(): any
				local chosen = p.defaultFocus
				if type(chosen) == "function" then
					chosen = chosen(h)
				end
				if chosen ~= nil then
					return chosen
				end
				local first = Overlay.firstSelectable(body.content)
				if first then
					return first
				end
				local last = actionHandles[#actionHandles]
				return if last then last.Instance else (h.closeButton and h.closeButton.Instance)
			end
			-- In a dock the dock places it beside the others, in its one overlay
			local overlay: any = if type(p.dock) == "string"
				then Dock.join(app, p.dock, {
					open = shown,
					content = framed.frame,
					width = p.width,
					minWidth = p.minWidth,
					side = p.side,
					pin = p.dockPin,
					slide = p.dockSlide,
					dismissible = dismissible,
					defaultFocus = firstFocus,
					id = h.id,
				})
				else nil
			overlay = overlay
				or Overlay.use(app, {
					open = shown,
					content = framed.frame,
					returnFocus = p.returnFocus,
					presentation = p.presentation or "auto",
					prefer = "panel",
					panelSide = p.side,
					width = p.width,
					modal = modal,
					-- A non modal sheet takes focus only when told what to focus
					focus = p.defaultFocus ~= nil,
					scrim = if p.scrim == false then false else nil,
					dismissible = dismissible,
					closeOnOutside = closeOnOverlay,
					host = host,
					measureFirst = true,
					id = h.id,
					name = "Sheet",
					tags = { "ui-sheet" },
					defaultFocus = firstFocus,
				})
			overlayRef(overlay)

			h.overlay, h.content, h.body, h.footer, h.actions =
				overlay.scrim, content, body, footer, actionHandles
			h.frame, h.shadow, h.plate = framed.frame, framed.shadow, framed.plate
			capRef(bodyCap)
			h.headerSlot, h.footerSlot, h.actionsRow = headerSlot, footerSlot, actionsRow
			h.handleBar = handleBar
			Component.claimSelection(app, overlay.root)
		end

		local part = Deferred.new(h, {
			slots = { host },
			keep = keep,
			build = function()
				presence()
				if p.onBuild then
					p.onBuild(h)
				end
			end,
			-- keep = false: everything the presence pointed at is gone
			removed = function()
				overlayRef(nil)
				capRef(nil)
				h.overlay, h.content, h.body, h.footer, h.actions = nil, nil, nil, nil, nil
				h.frame, h.shadow, h.plate, h.handleBar = nil, nil, nil, nil
				h.headerSlot, h.footerSlot, h.actionsRow, h.cornerSlot = nil, nil, nil, nil
				h.closeButton, h.titleLabel, h.descriptionLabel = nil, nil, nil
			end,
		})
		h._part = part
		shown = part:follow(open, {
			-- A drawer is still on screen while it slides out: the presence goes after that
			visible = function(): boolean
				local overlay = overlayRef()
				return overlay ~= nil and overlay.visible()
			end,
		})

		-- Side effects of opening: the owner hears (once the content is there, with build).
		Reactive.watch(shown, function(isOpen, previous)
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
		return host
	end,
}

-- With build: builds the content now, without opening. Nothing happens once it is built.
local function build(h: any)
	if not h.destroyed then
		h._part:build()
	end
end

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
	-- The handle is finished: the presence is built now with mount = "immediate", or if it starts
	-- open
	handle.build = build
	local part = handle._part
	if handle._mount == "immediate" then
		part:build()
	end
	part:start(handle:ref("open"))
	-- Warmed ahead: preload, trigger, ahead and warm() (ADR 0051)
	Deferred.anticipate(handle, p, "Sheet")
	return handle
end

Component.define(spec)

return Sheet
