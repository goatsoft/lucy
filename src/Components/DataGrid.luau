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
			multi = false,          -- true: each new header pressed breaks the ties of the ones before
			sortable = true, removable = true, descFirst = false, manual = false,
			onSortingChange = function(sorting, grid) end,
			-- and any Table prop: highlight, striped, onRowClick, empty, maxHeight,
			-- virtual, rowHeight, onEndReached, size
		})
		grid:toggle("score")    -- what pressing the Score header does

	Columns take Table's fields and useTable's (sortable, sortFn, descFirst,
	invert). A sortable header is a SortButton showing lucy:chevron-up or
	lucy:chevron-down while it sorts; each press goes first direction, the other,
	then unsorted (unless removable is false). With multi, a header that is not
	sorted joins as the next tiebreaker and each sorted header shows its place.
	The sort is kept in app state at ui.<id>.sorting (one sort or false; a list
	with multi), so a game can save and restore it.

	grid.table is the Table, grid.model the useTable result, grid.headers the
	header buttons by column id, grid.sortIcons their icons, grid.sortButtons
	their SortButton handles.

	State keys: sorting, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local SortButton = require(script.Parent.SortButton)
local Table = require(script.Parent.Table)

local DataGrid = {}

-- The headers' looks are SortButton's.
DataGrid.rules = {} :: { Component.Rule }

local ALIGN_NAME = {
	[Enum.TextXAlignment.Left] = "left",
	[Enum.TextXAlignment.Center] = "center",
	[Enum.TextXAlignment.Right] = "right",
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
			multi = p.multi,
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
		h.sortButtons = {}
		local function headerCell(column: any, align: Enum.TextXAlignment): any
			local text = if column.header ~= nil then tostring(column.header) else ""
			if not model.canSort(column.id) then
				return Element.new("TextLabel", {
					Name = "Label",
					Size = UDim2.fromScale(1, 1),
					Text = text,
					TextXAlignment = align,
					Tags = { "ui-table-head" },
				})
			end
			local id = column.id
			local button = SortButton.new({
				app = app,
				sort = model,
				column = id,
				text = text,
				align = ALIGN_NAME[align] or "left",
				size = UDim2.fromScale(1, 1),
			})
			-- Kept so a game's own rules for DataGrid headers still match
			button.Instance:AddTag("ui-datagrid-sort")
			h.headers[id] = button.Instance
			h.sortIcons[id] = button.icon
			h.sortButtons[id] = button
			return button.Instance
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
