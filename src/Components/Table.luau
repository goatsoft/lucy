--!strict
--[[
	Table: rows and columns, for leaderboards, friends lists, inventories and
	match history (ADR 0025). It draws what it is given; DataGrid adds sorting.

		Table.new({
			columns = {
				{ key = "rank", header = "#", width = 48, align = "center" },
				{ key = "name", header = "Player", width = { fill = 2 } },
				{ id = "kd", header = "K/D", get = function(row) return row.kills / row.deaths end },
				{ key = "userId", header = "", cell = function(ctx) return Lucy.Avatar.new({ userId = ctx.value() }) end },
			},
			rows = players,            -- an array, a ref or a getter
			rowId = function(row) return row.userId end,  -- keys rows (defaults to their position)
			rowHeight = 40,            -- pixels; ControlLg by default
			highlight = function(row) return row.userId == myId end,
			striped = false,
			onRowClick = function(row, index) end,   -- rows become pressable and selectable
			empty = "No players yet",  -- shown with no rows
			maxHeight = 320,           -- the body scrolls past it; or give size a height to fill
			virtual = false,           -- build only the rows near the view (needs rowHeight)
			onEndReached = function() end,  -- near the end of the rows: load more
			size = UDim2,              -- full width, as tall as its rows, by default
		})

	A column has id (or key, the id and the field), get (a value from the row,
	instead of key), header, width (pixels, or { fill = n } shares of what is
	left; { fill = 1 } by default), align (left | center | right) and cell. A cell
	shows the value as text, or cell(ctx) returns an instance, a handle or text;
	ctx.row() and ctx.value() are getters that follow the data, and ctx.column
	is the column.

	Rows are keyed by rowId, so new data updates cells in place and moves rows
	rather than rebuilding them. The header stays put while the body scrolls.
	Virtual rows: the body is as tall as every row, but only the rows on screen
	and a few either side exist; they are built as they come near the view and
	removed as they leave. onEndReached fires once when the player scrolls near
	the end, and again only after the row count grows.

	handle.header, handle.body (the ScrollArea), handle.emptyLabel,
	handle.rowFor(id) (the row's instance, if built), handle.rowCount() (rows
	built), handle.pressRow(id).

	State keys: visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local ScrollArea = require(script.Parent.ScrollArea)
local TableModel = require(script.Parent.Parent.Core.TableModel)

local Table = {}

local ACTIVATED = Element.on("Activated")
local ALIGN = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}
-- Rows built beyond each edge of the view, in virtual mode.
Table.overscan = 4
-- How near the end, in rows, counts as the end for onEndReached.
Table.endThreshold = 5

Table.rules = {
	{
		selector = ".ui-table",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-table-header",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-table-head",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-table-row",
		priority = 0,
		properties = { BackgroundColor3 = "$Muted", BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{ selector = ".ui-table-row-striped", priority = 5, properties = { BackgroundTransparency = 0.5 } },
	{
		selector = ".ui-table-row-clickable:Hover",
		priority = 10,
		properties = { BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-table-row-highlight",
		priority = 20,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 0 },
	},
	{
		selector = ".ui-table-cell",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{
		selector = ".ui-table-cell::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space3", PaddingRight = "$Space3" },
	},
	{
		selector = ".ui-table-text",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
	{
		selector = ".ui-table-divider",
		priority = 0,
		properties = { BackgroundColor3 = "$Border", BorderSizePixel = 0 },
	},
	{
		selector = ".ui-table-empty",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextSm",
		},
	},
} :: { Component.Rule }

type Width = { fixed: number?, fill: number? }

local function widthOf(column: any): Width
	local w = column.width
	if w == nil then
		return { fill = 1 }
	elseif type(w) == "number" then
		return { fixed = w }
	elseif type(w) == "table" and type(w.fill) == "number" then
		return { fill = w.fill }
	end
	error(`[Lucy] Table column "{column.id}" width must be pixels or {"{"} fill = n {"}"}`, 0)
end

-- A cell's size across the row: pixels, or a share of what the fixed columns leave.
local function cellSizes(columns: { any }): { UDim2 }
	local fixedTotal, fillTotal = 0, 0
	local widths = {}
	for index, column in columns do
		local w = widthOf(column)
		widths[index] = w
		if w.fixed then
			fixedTotal += w.fixed
		else
			fillTotal += w.fill :: number
		end
	end
	local sizes = {}
	for index, w in widths do
		if w.fixed then
			sizes[index] = UDim2.new(0, w.fixed, 1, 0)
		else
			local share = (w.fill :: number) / math.max(fillTotal, 1e-9)
			sizes[index] = UDim2.new(share, -share * fixedTotal, 1, 0)
		end
	end
	return sizes
end

-- Puts custom cell content where the column aligns, centred vertically.
local ANCHOR_X = {
	[Enum.TextXAlignment.Left] = 0,
	[Enum.TextXAlignment.Center] = 0.5,
	[Enum.TextXAlignment.Right] = 1,
}
local function place(instance: Instance, align: Enum.TextXAlignment): Instance
	if instance:IsA("GuiObject") then
		local x = ANCHOR_X[align] or 0
		instance.AnchorPoint = Vector2.new(x, 0.5)
		instance.Position = UDim2.fromScale(x, 0.5)
	end
	return instance
end

-- What a cell function returned, as an instance.
local function asInstance(value: any, align: Enum.TextXAlignment): Instance?
	if typeof(value) == "Instance" then
		return place(value, align)
	elseif type(value) == "table" and value.Instance then
		return place(value.Instance, align)
	elseif value ~= nil then
		return Element.new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = align,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(value),
			Tags = { "ui-table-text" },
		})
	end
	return nil
end

local spec: Component.Spec = {
	kind = "table",
	defaults = { visible = true },
	rules = Table.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local columns = TableModel.normalizeColumns(p.columns or {}, { sortable = false })
		local sizes = cellSizes(columns)
		local virtual = p.virtual == true
		if virtual and type(p.rowHeight) ~= "number" then
			error("[Lucy] a virtual Table needs a rowHeight in pixels", 0)
		end
		local metricHeight = Composables.useMetric(app, "ControlLg")
		local headerHeight = Composables.useMetric(app, "ControlMd")
		local function rowHeight(): number
			return if type(p.rowHeight) == "number" then p.rowHeight else metricHeight()
		end
		local rowIdOf = p.rowId
		local function rows(): { any }
			return Reactive.toValue(p.rows) or {}
		end
		local function idOf(row: any, index: number): any
			return if rowIdOf then rowIdOf(row, index) else index
		end

		-- Built rows by id, for rowFor and pressRow.
		local built: { [any]: GuiObject } = {}
		local builtCount = 0
		h.rowFor = function(id: any): GuiObject?
			return built[id]
		end
		h.rowCount = function(): number
			return builtCount
		end
		h.pressRow = function(id: any)
			local data = Reactive.untrack(rows)
			for index, row in data do
				if idOf(row, index) == id then
					if p.onRowClick then
						p.onRowClick(row, index)
					end
					return
				end
			end
		end

		-- One row: `dataIndex` follows where the row's data sits now.
		local function buildRow(id: any, dataIndex: () -> number?)
			local function current(): any
				local index = dataIndex()
				return if index then rows()[index] else nil
			end
			local cells = {}
			for index, column in columns do
				local align = ALIGN[column.align or "left"] or Enum.TextXAlignment.Left
				local content: any
				if column.cell then
					local ctx = {
						row = current,
						value = function(): any
							local row = current()
							return if row ~= nil then column.get(row) else nil
						end,
						column = column,
					}
					content = asInstance(column.cell(ctx), align)
				else
					content = Element.new("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						TextXAlignment = align,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Text = function(): string
							local row = current()
							local value = if row ~= nil then column.get(row) else nil
							return if value == nil then "" else tostring(value)
						end,
						Tags = { "ui-table-text" },
					})
				end
				cells[index] = Element.new("Frame", {
					Name = column.id,
					LayoutOrder = index,
					Size = sizes[index],
					ClipsDescendants = true,
					Tags = { "ui-table-cell" },
					content,
				})
			end
			local function stripe(): boolean
				local index = dataIndex()
				return Reactive.toValue(p.striped) == true and index ~= nil and index % 2 == 0
			end
			local function lit(): boolean
				local row = current()
				return p.highlight ~= nil and row ~= nil and p.highlight(row) == true
			end
			local clickable = p.onRowClick ~= nil
			local props: { [any]: any } = {
				Name = "Row",
				Size = function(): UDim2
					return UDim2.new(1, 0, 0, rowHeight())
				end,
				Tags = {
					"ui-table-row" :: any,
					if clickable then "ui-table-row-clickable" else "ui-table-row-static",
					["ui-table-row-striped"] = stripe,
					["ui-table-row-highlight"] = lit,
				},
				Element.new("Frame", {
					Name = "Divider",
					Position = UDim2.new(0, 0, 1, -1),
					Size = UDim2.new(1, 0, 0, 1),
					Tags = { "ui-table-divider" },
				}),
			}
			if virtual then
				props.Position = function(): UDim2
					local index = dataIndex() or 1
					return UDim2.fromOffset(0, (index - 1) * rowHeight())
				end
			else
				props.LayoutOrder = function(): number
					return dataIndex() or 0
				end
			end
			if clickable then
				props.Text = ""
				props.AutoButtonColor = false
				props[ACTIVATED] = function()
					local index = dataIndex()
					local row = current()
					if row ~= nil and index then
						p.onRowClick(row, index)
					end
				end
			end
			-- Cells are laid out in their own frame, so the divider is not.
			table.insert(
				props,
				Element.new("Frame", {
					Name = "Cells",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Element.new("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					table.unpack(cells),
				})
			)
			local root = Element.new(if clickable then "TextButton" else "Frame", props) :: GuiObject
			built[id] = root
			builtCount += 1
			Reactive.onCleanup(function()
				if built[id] == root then
					built[id] = nil
					builtCount -= 1
				end
			end)
			return root
		end

		-- Where each row id sits in the data now.
		local indexById = Reactive.computed(function(): { [any]: number }
			local out = {}
			for index, row in rows() do
				out[idOf(row, index)] = index
			end
			return out
		end)

		-- The body.
		local canvasTop = Reactive.ref(0) -- offset units, before UIScale
		local windowHeight = Reactive.ref(0)
		-- The rows take the scroll window's width, which leaves out the scroll bar.
		local windowWidth = Reactive.ref(0)
		local inner: any
		if virtual then
			local visible = Reactive.computed(function(): { number }
				local count = #rows()
				local rh = rowHeight()
				local first = math.max(1, math.floor(canvasTop() / rh) + 1 - Table.overscan)
				local last = math.min(count, math.ceil((canvasTop() + windowHeight()) / rh) + Table.overscan)
				local out = {}
				for index = first, last do
					table.insert(out, index)
				end
				return out
			end)
			inner = Element.new("Frame", {
				Name = "Rows",
				BackgroundTransparency = 1,
				Size = function(): UDim2
					return UDim2.fromOffset(windowWidth(), #rows() * rowHeight())
				end,
				Element.each(visible, function(index: number)
					local id = idOf(Reactive.untrack(rows)[index], index)
					return buildRow(id, function(): number?
						return indexById()[id]
					end)
				end, {
					key = function(index: number): any
						return idOf(Reactive.untrack(rows)[index], index)
					end,
				}),
			})
		else
			inner = Element.new("Frame", {
				Name = "Rows",
				BackgroundTransparency = 1,
				Size = function(): UDim2
					return UDim2.fromOffset(windowWidth(), 0)
				end,
				AutomaticSize = Enum.AutomaticSize.Y,
				Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
				Element.each(rows, function(row: any, index: () -> number)
					local id = idOf(row, Reactive.untrack(index))
					return buildRow(id, function(): number?
						return indexById()[id]
					end)
				end, {
					key = function(row: any, index: number): any
						return idOf(row, index)
					end,
				}),
			})
		end

		local given: UDim2? = p.size
		local fixedHeight = given ~= nil and (given.Y.Scale ~= 0 or given.Y.Offset ~= 0)
		local body = ScrollArea.new({
			app = app,
			name = "Body",
			layoutOrder = 2,
			size = if fixedHeight
				then function(): UDim2
					return UDim2.new(1, 0, 1, -headerHeight())
				end
				else nil,
			maxHeight = if fixedHeight then nil else (p.maxHeight or math.huge),
			children = { inner },
		})
		h.body = body
		local scroller = body.Instance :: ScrollingFrame

		-- Follow the scroll position and the view's height (side effects of the engine's layout).
		local function measure()
			local scale = Scroll.scaleOf(scroller)
			if scale <= 0 then
				scale = 1
			end
			canvasTop(scroller.CanvasPosition.Y / scale)
			windowHeight(scroller.AbsoluteWindowSize.Y / scale)
			windowWidth(math.floor(scroller.AbsoluteWindowSize.X / scale))
		end
		measure()
		local connections = {
			scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(measure),
			scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(measure),
		}
		Reactive.onCleanup(function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end)

		-- Near the end: tell the game once per row count.
		if p.onEndReached then
			local firedAt = -1
			Reactive.watchEffect(function()
				local count = #rows()
				local rh = rowHeight()
				local bottom = canvasTop() + windowHeight()
				local nearEnd = count > 0
					and windowHeight() > 0
					and bottom >= (count - Table.endThreshold) * rh
				if nearEnd and firedAt ~= count then
					firedAt = count
					Reactive.untrack(p.onEndReached, h)
				end
			end)
		end

		-- The header leaves the same room on the right as the rows have beside them
		-- (the scroll bar's), measured, so the columns line up.
		local bodyWidth = Reactive.ref(0)
		local rowsWidth = Reactive.ref(0)
		local function measureWidths()
			bodyWidth(scroller.AbsoluteSize.X)
			rowsWidth(inner.AbsoluteSize.X)
		end
		measureWidths()
		table.insert(connections, scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(measureWidths))
		table.insert(connections, inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(measureWidths))
		local headerCells = {}
		for index, column in columns do
			local align = ALIGN[column.align or "left"] or Enum.TextXAlignment.Left
			local content: any
			if p.headerCell then
				content = asInstance(p.headerCell(column, align), align)
			else
				content = Element.new("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = align,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = if column.header ~= nil then tostring(column.header) else "",
					Tags = { "ui-table-head" },
				})
			end
			headerCells[index] = Element.new("Frame", {
				Name = column.id,
				LayoutOrder = index,
				Size = sizes[index],
				ClipsDescendants = true,
				Tags = { "ui-table-cell" },
				content,
			})
		end
		local header = Element.new("Frame", {
			Name = "Header",
			LayoutOrder = 1,
			Size = function(): UDim2
				return UDim2.new(1, 0, 0, headerHeight())
			end,
			Tags = { "ui-table-header" },
			Element.new("UIPadding", {
				PaddingRight = function(): UDim
					local scale = Scroll.scaleOf(scroller)
					local gap = (bodyWidth() - rowsWidth()) / (if scale > 0 then scale else 1)
					return UDim.new(0, math.max(0, math.floor(gap + 0.5)))
				end,
			}),
			Element.new("Frame", {
				Name = "Cells",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Element.new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				table.unpack(headerCells),
			}),
			Element.new("Frame", {
				Name = "Divider",
				Position = UDim2.new(0, 0, 1, -1),
				Size = UDim2.new(1, 0, 0, 1),
				Tags = { "ui-table-divider" },
			}),
		})
		h.header = header

		local emptyLabel = Element.new("TextLabel", {
			Name = "Empty",
			LayoutOrder = 3,
			Size = function(): UDim2
				return UDim2.new(1, 0, 0, rowHeight())
			end,
			Text = p.empty or "",
			Visible = function(): boolean
				return p.empty ~= nil and #rows() == 0
			end,
			Tags = { "ui-table-empty" },
		})
		h.emptyLabel = emptyLabel

		local root = Element.new("Frame", {
			Size = if fixedHeight
				then given
				else UDim2.new(if given then given.X else UDim.new(1, 0), UDim.new(0, 0)),
			AutomaticSize = if fixedHeight then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			Tags = { "ui-table" },
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			header,
			body.Instance,
			emptyLabel,
		})
		return root
	end,
}

function Table.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Table
