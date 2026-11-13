--!strict
--[[
	PanelFrame: the frame Dialog and Sheet put their panel in (ADR 0047). A clear holder the
	overlay places, with the panel inside and, beside it:

	  the shadow   behind the panel, its size, offset right and down by the PanelShadow token
	               (0 in Lucy's themes: no shadow until a game's theme sets it; its colour is a
	               rule on ui-<kind>-shadow)
	  the plate    with titlePlacement "edge" (or the PanelTitleEdge token 1): the title on a
	               plate standing on the panel's top edge, coming down over it by the
	               PanelPlateOverlap token, with a shadow of its own. The frame keeps the room
	               over the panel for it, and the panel's content starts that much lower, so
	               its first row clears the plate by the panel's own padding.

		local parts = PanelFrame.new(app, content, {
			kind = "dialog",               -- the tags' prefix: ui-dialog-frame, -shadow, -plate
			title = h:ref("title"),        -- the plate's words
			placement = p.titlePlacement,  -- "inside" | "edge"; nil: the PanelTitleEdge token
			fill = false,                  -- true (or a getter): the panel fills the frame (a sheet's
			                               -- panel, which the overlay sizes); false: it sets the
			                               -- frame's height
		})
		PanelFrame.edge(app, placement) -> boolean   whether a panel's title goes on the edge
		parts.frame  parts.shadow  parts.edge (boolean)  parts.plate?  parts.titleLabel?
		parts.rise()    the room over the panel the plate takes, in the frame's own units
		parts.offset()  the shadow's offset, likewise
		parts.clear()   the room the plate takes inside the panel (its overlap), likewise (all three
		                0 when unused)

	A shadow takes the corners of what it is behind (the panel's, the plate's), whatever rule set
	them: a square sheet panel has a square shadow, a rounded dialog a rounded one, and a theme
	that changes a panel's corners changes its shadow's with it.

	Call it in a scope (a component's render). Looks are rules (PanelFrame.rules); this only
	places the parts.
]]

local Component = require(script.Parent.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Element)
local Reactive = require(script.Parent.Reactive)
local Scroll = require(script.Parent.Scroll)

local PanelFrame = {}

local OUT_SIZE = Element.out("AbsoluteSize")

-- The plate's look and the shadow's default colour, for one kind ("dialog", "sheet")
function PanelFrame.rules(kind: string): { any }
	return {
		{
			selector = `.ui-{kind}-frame`,
			priority = 0,
			properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
		},
		{
			selector = `.ui-{kind}-shadow`,
			priority = 0,
			properties = { BackgroundColor3 = "$Black", BackgroundTransparency = 0, BorderSizePixel = 0 },
		},
		{
			selector = `.ui-{kind}-plate`,
			priority = 0,
			properties = { BackgroundColor3 = "$Background", BackgroundTransparency = 0, BorderSizePixel = 0 },
		},
		{
			selector = `.ui-{kind}-plate::UICorner`,
			priority = 0,
			properties = { CornerRadius = "$RadiusMd" },
		},
		{
			selector = `.ui-{kind}-plate::UIStroke`,
			priority = 0,
			properties = {
				Color = "$Border",
				Thickness = "$StrokeThin",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			},
		},
		{
			selector = `.ui-{kind}-plate::UIPadding`,
			priority = 0,
			properties = {
				PaddingLeft = "$Space4",
				PaddingRight = "$Space4",
				PaddingTop = "$Space2",
				PaddingBottom = "$Space2",
			},
		},
	}
end

-- Keeps `shadow`'s corners the same as `source`'s: a UICorner of the same radius while the source
-- has one (a style rule's ::UICorner or its own), none while it has none
local function sameCorners(source: GuiObject, shadow: GuiObject)
	local mirror: UICorner? = nil
	local watching: RBXScriptConnection? = nil
	local function update()
		local corner = source:FindFirstChildWhichIsA("UICorner")
		if watching then
			watching:Disconnect()
			watching = nil
		end
		if not corner then
			if mirror then
				mirror:Destroy()
				mirror = nil
			end
			return
		end
		local made = mirror or Instance.new("UICorner")
		made.CornerRadius = corner.CornerRadius
		made.Parent = shadow
		mirror = made
		watching = corner:GetPropertyChangedSignal("CornerRadius"):Connect(update)
	end
	source.ChildAdded:Connect(function(child)
		if child:IsA("UICorner") then
			update()
		end
	end)
	source.ChildRemoved:Connect(function(child)
		if child:IsA("UICorner") then
			task.defer(update)
		end
	end)
	update()
end

export type Parts = {
	frame: Frame,
	shadow: Frame,
	edge: boolean,
	plate: Frame?,
	titleLabel: TextLabel?,
	rise: () -> number,
	offset: () -> number,
	clear: () -> number,
}

-- A panel's own titlePlacement, else the theme's PanelTitleEdge token (1: on the edge)
function PanelFrame.edge(app: any, placement: any): boolean
	if placement == "inside" or placement == "edge" then
		return placement == "edge"
	end
	return app.theme:resolve("PanelTitleEdge") == 1
end

function PanelFrame.new(app: any, content: GuiObject, options: { [string]: any }): Parts
	local kind: string = options.kind
	local edge = PanelFrame.edge(app, options.placement)
	local function fills(): boolean
		local fill = options.fill
		if type(fill) == "function" then
			return fill() == true
		end
		return fill == true
	end
	local offset = Composables.useMetric(app, "PanelShadow")
	local overlap = Composables.useMetric(app, "PanelPlateOverlap")

	local frame = Element.new("Frame", {
		Name = "Frame",
		Tags = { `ui-{kind}-frame` },
	}) :: Frame

	-- The frame's own units (the overlay may scale it)
	local function scaleOf(): number
		local scale = Scroll.scaleOf(frame)
		return if scale > 0 then scale else 1
	end

	-- The plate and its room over the panel
	local plateSize = Reactive.ref(Vector2.zero)
	local function rise(): number
		if not edge then
			return 0
		end
		local height = plateSize().Y / scaleOf()
		return math.max(0, math.ceil(height - overlap()))
	end
	local function shadowOffset(): number
		return math.max(0, offset())
	end
	-- Inside the panel, the plate covers its top by the overlap: the content starts under that
	local function clear(): number
		return if edge then math.max(0, overlap()) else 0
	end

	-- The panel: below the plate's room, short of the shadow on the right (and the foot, when it
	-- fills the frame)
	local contentSize = Reactive.ref(Vector2.zero)
	Element.hydrate(content, {
		Position = function(): UDim2
			return UDim2.fromOffset(0, rise())
		end,
		Size = function(): UDim2
			if fills() then
				return UDim2.new(1, -shadowOffset(), 1, -rise() - shadowOffset())
			end
			return UDim2.new(1, -shadowOffset(), 0, 0)
		end,
		ZIndex = 2,
		[OUT_SIZE] = contentSize :: any,
	})
	if edge then
		Element.new("UIPadding", {
			PaddingTop = function(): UDim
				return UDim.new(0, clear())
			end,
		}).Parent =
			content
	end
	content.Parent = frame

	local function sizeOf(size: Vector2): UDim2
		local scale = scaleOf()
		return UDim2.fromOffset(size.X / scale, size.Y / scale)
	end

	local shadow = Element.new("Frame", {
		Name = "Shadow",
		Position = function(): UDim2
			return UDim2.fromOffset(shadowOffset(), rise() + shadowOffset())
		end,
		Size = function(): UDim2
			return sizeOf(contentSize())
		end,
		Visible = function(): boolean
			return shadowOffset() > 0
		end,
		ZIndex = 1,
		Tags = { `ui-{kind}-shadow` },
	}) :: Frame
	shadow.Parent = frame
	sameCorners(content, shadow)

	local parts: Parts = {
		frame = frame,
		shadow = shadow,
		edge = edge,
		rise = rise,
		offset = shadowOffset,
		clear = clear,
	}

	if edge then
		-- In from the left edge as far as the panel's own padding, so it lines up with the content
		local left = Component.space(app, "Space6", 24).Offset
		local function inset(): number
			return left
		end
		local label = Element.new("TextLabel", {
			Name = "Title",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = options.title,
			Tags = { `ui-{kind}-title` },
		}) :: TextLabel
		local plate = Element.new("Frame", {
			Name = "Plate",
			Position = function(): UDim2
				return UDim2.fromOffset(inset(), 0)
			end,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			ZIndex = 4,
			Tags = { `ui-{kind}-plate` },
			[OUT_SIZE] = plateSize :: any,
			label,
		}) :: Frame
		plate.Parent = frame
		local plateShadow = Element.new("Frame", {
			Name = "PlateShadow",
			Position = function(): UDim2
				return UDim2.fromOffset(inset() + shadowOffset(), shadowOffset())
			end,
			Size = function(): UDim2
				return sizeOf(plateSize())
			end,
			Visible = function(): boolean
				return shadowOffset() > 0
			end,
			ZIndex = 3,
			Tags = { `ui-{kind}-shadow`, `ui-{kind}-plate-shadow` },
		}) :: Frame
		plateShadow.Parent = frame
		sameCorners(plate, plateShadow)
		parts.plate = plate
		parts.titleLabel = label
	end

	return parts
end

return PanelFrame
