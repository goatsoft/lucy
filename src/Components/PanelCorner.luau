--!strict
--[[
	PanelCorner: the top right corner of a Dialog or Sheet (not a component of its own: their
	corner part). The close button, with the corner slot's children before it on the same row
	(a currency chip, a help button), always in the same place and at the same size on every
	panel, whatever the title's placement.

		local corner = PanelCorner.new(app, content, {
			close = showClose,              -- the close button
			onClose = function() h:close() end,
			children = p.corner,            -- beside it, to its left
			clear = parts.clear,            -- the panel's content padding at the top (an edge
			                                -- title's plate): the corner stays above it
		})
		corner.frame        the row (ui-<kind>-corner is the caller's tag to add)
		corner.slot         where the children go
		corner.closeButton  the close button's handle, or nil
		corner.room()       how much of the top row's width the corner takes, in the panel's own
		                    units (0 when it is empty), for the row beside it to stop short

	Call it in a scope (a component's render).
]]

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)

local PanelCorner = {}

local OUT_SIZE = Element.out("AbsoluteSize")

-- The room the close button alone has always kept (the row stops this far short of the edge)
PanelCorner.closeRoom = 44

export type Corner = {
	frame: Frame,
	slot: Frame,
	closeButton: any?,
	room: () -> number,
}

function PanelCorner.new(app: any, content: GuiObject, props: { [string]: any }): Corner
	local inset = Component.space(app, "Space1", 4).Offset
	local gap = Component.space(app, "Space2", 8)
	local clear: () -> number = props.clear or function()
		return 0
	end

	local size = Reactive.ref(Vector2.zero)
	local frame = Element.new("Frame", {
		Name = "Corner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		-- The content's top padding (clear) moves its children down: the corner moves back up
		Position = function(): UDim2
			return UDim2.new(1, -inset, 0, inset - clear())
		end,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 3,
		[OUT_SIZE] = size :: any,
	}) :: Frame
	Component.list({
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = gap,
		Parent = frame,
	})

	local slot = Component.box({
		Name = "CornerSlot",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 1,
		Parent = frame,
	})
	Component.list({
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = gap,
		Parent = slot,
	})
	if props.children then
		Component.adopt(slot, props.children)
	end
	local slotShown = Composables.useHasVisibleChild(slot)
	Element.hydrate(slot, { Visible = slotShown })

	local closeButton = nil
	if props.close then
		closeButton = Button.close({ app = app, onClick = props.onClose })
		closeButton.Instance.LayoutOrder = 2
		closeButton.Instance.Parent = frame
	end
	frame.Parent = content

	local function room(): number
		if not slotShown() then
			return if closeButton then PanelCorner.closeRoom else 0
		end
		local scale = Scroll.scaleOf(frame)
		if scale <= 0 then
			scale = 1
		end
		return math.max(PanelCorner.closeRoom, math.ceil(size().X / scale + inset + gap.Offset))
	end

	return { frame = frame, slot = slot, closeButton = closeButton, room = room }
end

return PanelCorner
