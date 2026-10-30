--!strict
--[[
	DataGrid: a Table whose headers sort it (ADR 0025).

		DataGrid.new({
			data = players,                     -- an array, a ref or a getter
			rowId = function(row) return row.userId end,
			columns = {
				{ key = "name", header = "Player", width = { fill = 2 } },
				{ key = "score", header = "Score", descFirst = true, align = "right" },
				{ key = "rank", header = "Rank", invert = true },
				{ id = "invite", sortable = false, cell = function(ctx) ... end },
			},
			sorting = { id = "score", desc = true },   -- the starting sort; false for none
			sortable = true, removable = true, descFirst = false, manual = false,
			onSortingChange = function(sorting, grid) end,
			-- and any Table prop: highlight, striped, onRowClick, empty, maxHeight,
			-- virtual, rowHeight, onEndReached, size
		})
		grid:toggle("score")    -- what pressing the Score header does

	Columns take Table's fields and useTable's (sortable, sortFn, descFirst,
	invert). A sortable header is a button showing lucy:chevron-up or
	lucy:chevron-down while it sorts; each press goes first direction, the other,
	then unsorted (unless removable is false). The sort is kept in app state at
	ui.<id>.sorting, so a game can save and restore it.

	grid.table is the Table, grid.model the useTable result, grid.headers the
	header buttons by column id, grid.sortIcons their icons.

	State keys: sorting, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Icon = require(script.Parent.Icon)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Table = require(script.Parent.Table)

local DataGrid = {}

local ACTIVATED = Element.on("Activated")

DataGrid.rules = {
	{
		selector = ".ui-datagrid-sort",
		priority = 0,
		properties = { BackgroundColor3 = "$Accent", BackgroundTransparency = 1, BorderSizePixel = 0 },
	},
	{ selector = ".ui-datagrid-sort::UICorner", priority = 0, properties = { CornerRadius = "$RadiusSm" } },
	{ selector = ".ui-datagrid-sort:Hover", priority = 10, properties = { BackgroundTransparency = 0 } },
	{
		selector = ".ui-datagrid-sort.ui-sorted > .ui-table-head",
		priority = 10,
		properties = { TextColor3 = "$Foreground" },
	},
} :: { Component.Rule }

local HORIZONTAL = {
	[Enum.TextXAlignment.Left] = Enum.HorizontalAlignment.Left,
	[Enum.TextXAlignment.Center] = Enum.HorizontalAlignment.Center,
	[Enum.TextXAlignment.Right] = Enum.HorizontalAlignment.Right,
}

-- Props DataGrid hands to its Table as they are.
local TABLE_PROPS = {
	"highlight",
	"striped",
	"onRowClick",
	"empty",
	"maxHeight",
	"virtual",
	"rowHeight",
	"onEndReached",
	"size",
	"rowId",
}

local spec: Component.Spec = {
	kind = "data-grid",
	defaults = { sorting = false, visible = true },
	rules = DataGrid.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app

		-- The sort is a table in app state, changed in place, so read a snapshot
		-- that follows anything under the key, and write through the handle.
		local state = app.state
		local segments = state:_segments(h.path .. ".sorting")
		local snapshot = Reactive.computed(function(): any
			return state:_tracked(segments)
		end)
		local sorting = Reactive._accessor(function(): any
			return snapshot()
		end, function(value: any)
			h:set("sorting", value)
		end)

		local model = Composables.useTable({
			data = p.data,
			columns = p.columns or {},
			rowId = p.rowId,
			sorting = sorting,
			sortable = p.sortable,
			removable = p.removable,
			descFirst = p.descFirst,
			manual = p.manual,
		})
		h.model = model

		if p.onSortingChange then
			Reactive.watch(snapshot, function(value)
				p.onSortingChange(value, h)
			end)
		end

		h.headers = {}
		h.sortIcons = {}
		local function headerCell(column: any, align: Enum.TextXAlignment): any
			local label = Element.new("TextLabel", {
				Name = "Label",
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Text = if column.header ~= nil then tostring(column.header) else "",
				Tags = { "ui-table-head" },
			})
			if not model.canSort(column.id) then
				label.AutomaticSize = Enum.AutomaticSize.None
				label.Size = UDim2.fromScale(1, 1)
				label.TextXAlignment = align
				return label
			end
			local id = column.id
			local function direction(): string | false
				return model.sortedBy(id)
			end
			local icon = Icon.new({
				app = app,
				icon = function(): string
					return if direction() == "desc" then "lucy:chevron-down" else "lucy:chevron-up"
				end,
				size = "sm",
				variant = "muted",
				name = "SortIcon",
				layoutOrder = 2,
				visible = function(): boolean
					return direction() ~= false
				end,
			})
			local button = Element.new("TextButton", {
				Name = "Sort",
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1),
				Tags = {
					"ui-datagrid-sort" :: any,
					["ui-sorted"] = function(): boolean
						return direction() ~= false
					end,
				},
				[ACTIVATED] = function()
					h:toggle(id)
				end,
				Element.new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = HORIZONTAL[align] or Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				label,
				icon.Instance,
			})
			h.headers[id] = button
			h.sortIcons[id] = icon
			return button
		end

		local tableProps: { [string]: any } = {
			app = app,
			columns = p.columns or {},
			rows = function(): { any }
				local out = {}
				for index, row in model.rows() do
					out[index] = row.original
				end
				return out
			end,
			headerCell = headerCell,
			visible = h:ref("visible"),
		}
		for _, key in TABLE_PROPS do
			if p[key] ~= nil then
				tableProps[key] = p[key]
			end
		end
		local grid = Table.new(tableProps)
		h.table = grid
		Component.claimSelection(app, grid.Instance)
		return grid.Instance
	end,
}

function DataGrid.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)
	-- What pressing a column's header does. Reported as "activate" for game sounds.
	function handle.toggle(h, columnId: string)
		if h.destroyed or not h.model.canSort(columnId) then
			return
		end
		h.model.toggle(columnId)
		h:emit("activate")
	end
	return handle
end

return DataGrid
