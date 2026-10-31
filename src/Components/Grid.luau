--!strict
--[[
	Grid: lays out its children in rows of equal cells.

		Grid.new({
			columns = 4,              -- cells share the width; or a responsive value
			minCellWidth = 120,       -- or: as many columns as fit at this width
			cellSize = UDim2,         -- or: fixed cells, as many per row as fit
			cellHeight = 80,          -- pixels; with columns or minCellWidth
			aspectRatio = 1,          -- width / height when cellHeight is left out
			gap = "Space2",           -- spacing token, pixels or a UDim
			padding = "Space4",       -- optional, same forms as gap
			align = "start",          -- start | center | end, for a row that is not full
			size = UDim2,             -- fills the width and fits its rows when left out
			children = { ... },       -- instances, handles or functions
		})

	columns, cellSize and gap also take responsive values:
		columns = { mobile = 2, tablet = 3, default = 5 }

	handle.Instance is the frame; handle.layout is its UIGridLayout. With columns
	or minCellWidth the grid measures its own width to size the cells.
	State keys: visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)

local Grid = {}

local OUT_SIZE = Element.out("AbsoluteSize")

local ALIGN = {
	start = Enum.HorizontalAlignment.Left,
	center = Enum.HorizontalAlignment.Center,
	["end"] = Enum.HorizontalAlignment.Right,
}

Grid.defaultCellSize = UDim2.fromOffset(100, 100)

-- How many columns of at least `min` fit in `width` with `gap` between them.
function Grid.fit(width: number, min: number, gap: number): number
	if min <= 0 then
		return 1
	end
	return math.max(1, math.floor((width + gap) / (min + gap)))
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "grid",
	defaults = { visible = true },
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local columns = Composables.useResponsive(app, p.columns)
		local fixed = Composables.useResponsive(app, p.cellSize)
		local gapValue = Composables.useResponsive(app, p.gap)
		local minWidth: number? = p.minCellWidth
		local cellHeight: number? = p.cellHeight
		local aspect: number = p.aspectRatio or 1
		local shared = p.columns ~= nil or minWidth ~= nil

		local pad = if p.padding ~= nil then Component.space(app, p.padding, 0) else nil
		local inset = if pad then pad.Offset * 2 else 0

		-- Whole pixels: UDim offsets are whole numbers, so the gap is rounded once
		-- and each cell's share of the gaps rounds up. Rounding either the other way
		-- leaves the columns a pixel too wide and the last one wraps.
		local function gap(): number
			return math.round(Component.space(app, gapValue(), 0).Offset)
		end

		-- The width cells are laid out in, in layout pixels (the ScreenGui scales).
		-- Only measured when a cell's size depends on it.
		local measured: Reactive.Ref<Vector2>? = if shared then Reactive.ref(Vector2.zero) else nil
		local frame: Frame? = nil
		local function width(): number
			local size = (measured :: Reactive.Ref<Vector2>)()
			if not frame then
				return 0
			end
			return math.max(0, size.X / Scroll.scaleOf(frame) - inset)
		end

		local function count(): number
			local n: number? = columns()
			if n then
				return math.max(1, math.floor(n))
			end
			return Grid.fit(width(), minWidth or 0, gap())
		end

		local cellSize: any
		if shared then
			cellSize = function(): UDim2
				local n, g = count(), gap()
				local x = UDim.new(1 / n, -math.ceil(g * (n - 1) / n))
				if cellHeight then
					return UDim2.new(x, UDim.new(0, cellHeight))
				end
				local each = (width() - g * (n - 1)) / n
				return UDim2.new(x, UDim.new(0, math.max(0, each / aspect)))
			end
		else
			cellSize = function(): UDim2
				return fixed() or Grid.defaultCellSize
			end
		end

		h.layout = Element.new("UIGridLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = ALIGN[p.align or "start"] or ALIGN.start,
			CellSize = cellSize,
			CellPadding = function(): UDim2
				local g = gap()
				return UDim2.fromOffset(g, g)
			end,
		})

		local paddingChild: UIPadding? = nil
		if pad then
			paddingChild = Element.new("UIPadding", {
				Name = "GridPadding",
				PaddingTop = pad,
				PaddingBottom = pad,
				PaddingLeft = pad,
				PaddingRight = pad,
			})
		end

		local size: UDim2? = p.size
		local root = Element.new("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = size or UDim2.fromScale(1, 0),
			AutomaticSize = if size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			[OUT_SIZE] = measured :: any,
			h.layout,
			paddingChild :: any,
		})
		frame = root
		Component.adopt(root, p.children)
		return root
	end,
}

function Grid.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Grid
