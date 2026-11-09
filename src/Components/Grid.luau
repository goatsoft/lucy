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

	columns, minCellWidth, cellHeight, cellSize and gap also take responsive values:
		columns = { mobile = 2, tablet = 3, default = 5 }

	handle.Instance is the frame; handle.layout is its UIGridLayout. With columns
	or minCellWidth the grid measures its own width to size the cells.

	Virtual: for long lists (a shop of hundreds of items) in a ScrollArea.

		Grid.new({
			virtual = true,
			items = list,             -- an array, a ref or a getter
			item = function(entry, index) return Tile.new(...) end,  -- index is a getter
			key = function(entry, index) return entry.id end,         -- the item's index by default
			columns = 4,              -- or minCellWidth; cellHeight is required
			cellHeight = 160,
			gap = "Space2",
		})

	The grid is as tall as every row, but only the cells in the nearest
	ScrollingFrame's view and Grid.overscan rows either side exist; they are
	built as they come near the view and removed as they leave. Cells are keyed,
	so a new list moves the cells it keeps rather than rebuilding them. Without a
	ScrollingFrame around it every cell is built. children is not used.
	handle.cellFor(key) is a cell's frame, if built; handle.cellCount() is how
	many are built. There is no UIGridLayout (handle.layout is nil).

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
-- Rows built beyond each edge of the view, in virtual mode.
Grid.overscan = 2

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
		local minWidth = Composables.useResponsive(app, p.minCellWidth)
		local cellHeight = Composables.useResponsive(app, p.cellHeight)
		local aspect: number = p.aspectRatio or 1
		local shared = p.columns ~= nil or p.minCellWidth ~= nil
		if p.virtual == true then
			if p.cellHeight == nil or not shared then
				error("[Lucy] a virtual Grid needs columns or minCellWidth, and a cellHeight in pixels", 0)
			end
			if p.items == nil or type(p.item) ~= "function" then
				error("[Lucy] a virtual Grid needs items and an item function", 0)
			end
		end

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
			return Grid.fit(width(), minWidth() or 0, gap())
		end

		if p.virtual == true then
			return Grid._virtual(h, {
				count = count,
				gap = gap,
				cellHeight = cellHeight,
				width = width,
				measured = measured,
				inset = inset,
				pad = pad,
				setFrame = function(f: Frame)
					frame = f
				end,
			})
		end

		local cellSize: any
		if shared then
			cellSize = function(): UDim2
				local n, g = count(), gap()
				local x = UDim.new(1 / n, -math.ceil(g * (n - 1) / n))
				local height: number? = cellHeight()
				if height then
					return UDim2.new(x, UDim.new(0, height))
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

-- The virtual grid's frame: as tall as every row, holding only the cells near the view.
function Grid._virtual(h: any, g: { [string]: any }): Frame
	local p: Component.Props = h.props
	local cellHeight: () -> number = g.cellHeight
	local keyOf = p.key
	local function items(): { any }
		return Reactive.toValue(p.items) or {}
	end
	local function idOf(entry: any, index: number): any
		if keyOf then
			return keyOf(entry, index)
		end
		return index
	end
	local indexById = Reactive.computed(function(): { [any]: number }
		local out = {}
		for index, entry in items() do
			out[idOf(entry, index)] = index
		end
		return out
	end)

	local pad: number = g.pad and g.pad.Offset or 0
	local function cellWidth(): number
		local n, gap = g.count(), g.gap()
		return math.max(0, (g.width() - gap * (n - 1)) / n)
	end
	local function rows(): number
		return math.ceil(#items() / g.count())
	end

	-- The part of the grid in view, in layout pixels from its top (side effects of the engine's
	-- layout follow it below)
	local viewTop = Reactive.ref(0)
	local viewHeight = Reactive.ref(math.huge)

	local visible = Reactive.computed(function(): { number }
		local count = #items()
		local n, step = g.count(), cellHeight() + g.gap()
		local height = viewHeight()
		local first, last = 1, count
		if height < math.huge then
			local top = viewTop() - pad
			local firstRow = math.max(0, math.floor(top / step) - Grid.overscan)
			local lastRow = math.ceil((top + height) / step) + Grid.overscan
			first = firstRow * n + 1
			last = math.min(count, (lastRow + 1) * n)
		end
		local out = {}
		for index = first, last do
			table.insert(out, index)
		end
		return out
	end)

	local cells: { [any]: Frame } = {}
	local root = Element.new("Frame", {
		Name = "VirtualGrid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = function(): UDim2
			local r = rows()
			local height = if r > 0 then r * cellHeight() + (r - 1) * g.gap() else 0
			return UDim2.new(1, 0, 0, height + g.inset)
		end,
		Visible = h:ref("visible"),
		[OUT_SIZE] = g.measured :: any,
		Element.each(visible, function(index: number)
			local entry = Reactive.untrack(items)[index]
			local id = idOf(entry, index)
			local function at(): number
				return indexById()[id] or index
			end
			local cell = Element.new("Frame", {
				Name = "Cell",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = function(): UDim2
					return UDim2.fromOffset(cellWidth(), cellHeight())
				end,
				Position = function(): UDim2
					local i, n, gap = at() - 1, g.count(), g.gap()
					local column, row = i % n, i // n
					return UDim2.fromOffset(
						pad + column * (cellWidth() + gap),
						pad + row * (cellHeight() + gap)
					)
				end,
				LayoutOrder = at,
			})
			Component.adopt(cell, { p.item(entry, at) })
			cells[id] = cell
			Reactive.onCleanup(function()
				if cells[id] == cell then
					cells[id] = nil
				end
			end)
			return cell
		end, {
			key = function(index: number): any
				return idOf(Reactive.untrack(items)[index], index)
			end,
		}),
	}) :: Frame
	g.setFrame(root)

	-- Follow the nearest ScrollingFrame's view: its window against the grid's place on screen.
	local connections: { RBXScriptConnection } = {}
	local function disconnect()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
	local scroller: ScrollingFrame? = nil
	local function measure()
		if not scroller then
			viewTop(0)
			viewHeight(math.huge)
			return
		end
		local scale = Scroll.scaleOf(root)
		if scale <= 0 then
			scale = 1
		end
		viewTop((scroller.AbsolutePosition.Y - root.AbsolutePosition.Y) / scale)
		viewHeight(scroller.AbsoluteWindowSize.Y / scale)
	end
	local function attach()
		disconnect()
		scroller = root:FindFirstAncestorWhichIsA("ScrollingFrame")
		table.insert(connections, root:GetPropertyChangedSignal("AbsolutePosition"):Connect(measure))
		if scroller then
			local s = scroller :: ScrollingFrame
			table.insert(connections, s:GetPropertyChangedSignal("CanvasPosition"):Connect(measure))
			table.insert(connections, s:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(measure))
			table.insert(connections, s:GetPropertyChangedSignal("AbsolutePosition"):Connect(measure))
		end
		measure()
	end
	attach()
	local ancestry = root.AncestryChanged:Connect(attach)
	Reactive.onCleanup(function()
		ancestry:Disconnect()
		disconnect()
	end)

	h.cellFor = function(id: any): Frame?
		return cells[id]
	end
	h.cellCount = function(): number
		local n = 0
		for _ in cells do
			n += 1
		end
		return n
	end
	return root
end

function Grid.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Grid
