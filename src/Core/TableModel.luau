--!strict
--[[
	TableModel (ADR 0025): the sorting core behind Lucy.useTable, DataGrid and
	anything else list shaped. No instances. The sort itself is Core/SortModel.

		local model = TableModel.new({
			data = players,               -- an array, a ref or a getter
			rowId = function(row) return row.userId end,  -- defaults to the index
			columns = {
				{ key = "name", header = "Player" },          -- key: the id and the field
				{ id = "kd", get = function(row) return row.kills / row.deaths end },
				{ key = "score", descFirst = true },          -- first press sorts high to low
				{ key = "rank", invert = true },              -- lower is better
				{ id = "actions", sortable = false },
			},
			sorting = { id = "score", desc = true },  -- a value or a writable ref; false for none
			multi = false,                -- true: sorting is a list, each new header breaks ties
			sortable = true,              -- false: no column sorts
			removable = true,             -- a third press clears the sort
			manual = false,               -- true: the data arrives sorted
		})
		model.rows()          -- { { id, index, original, value = row:value(columnId) } }, sorted
		model.sorting()       -- { id, desc } or false; with multi, a list of them
		model.list()          -- the sorts as a list either way
		model.toggle(id)      -- what a header press does
		model.sortedBy(id)    -- false | "asc" | "desc"
		model.priority(id)    -- 1 for the first sort, 2 for its tiebreaker, nil if unsorted
		model.canSort(id)
		model.columns         -- the normalized columns, in order

	A column's sortFn is "auto" (numbers as numbers, anything else as text),
	"number", "text" (natural order, case blind) or a function (a, b) -> number
	on two values. Missing values sort last in either direction. Equal values
	keep their data order. One column sorts at a time unless multi is set.
]]

local Reactive = require(script.Parent.Reactive)
local SortModel = require(script.Parent.SortModel)

local TableModel = {}

export type Column = SortModel.Column
export type Sort = SortModel.Sort
export type Sorting = SortModel.Sorting

TableModel.compare = SortModel.compare
TableModel.normalizeColumns = SortModel.normalizeColumns

local RowMeta = {}
RowMeta.__index = RowMeta

-- The row's value for a column, by id.
function RowMeta.value(self: any, columnId: string): any
	local column = self._byId[columnId]
	return if column then column.get(self.original) else nil
end

local function rowOriginal(row: any): any
	return row.original
end

function TableModel.new(options: { [string]: any })
	local sort = SortModel.new(options)
	local byId: { [string]: SortModel.Column } = {}
	for _, column in sort.columns do
		byId[column.id] = column
	end
	local manual = options.manual == true
	local rowId = options.rowId

	local rows = Reactive.computed(function(): { any }
		local data = Reactive.toValue(options.data) or {}
		local list = {}
		for index, original in data do
			list[index] = setmetatable({
				id = if rowId then rowId(original, index) else index,
				index = index,
				original = original,
				_byId = byId,
			}, RowMeta)
		end
		if manual then
			sort.list() -- still follows the sort, so a game reloading on it sees the change
			return list
		end
		return sort.sort(list, rowOriginal)
	end)

	local model = {}
	model.columns = sort.columns
	model.rows = rows
	model.sorting = sort.sorting
	model.list = sort.list
	model.canSort = sort.canSort
	model.sortedBy = sort.sortedBy
	model.priority = sort.priority
	model.toggle = sort.toggle
	model.setSorting = sort.setSorting
	return model
end

return TableModel
