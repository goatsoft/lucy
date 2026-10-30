--!strict
--[[
	TableModel (ADR 0025): the sorting core behind Lucy.useTable, DataGrid and
	anything else list shaped. No instances.

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
			sortable = true,              -- false: no column sorts
			removable = true,             -- a third press clears the sort
			manual = false,               -- true: the data arrives sorted
		})
		model.rows()          -- { { id, index, original, value = row:value(columnId) } }, sorted
		model.sorting()       -- { id, desc } or false
		model.toggle(id)      -- what a header press does
		model.sortedBy(id)    -- false | "asc" | "desc"
		model.canSort(id)
		model.columns         -- the normalized columns, in order

	A column's sortFn is "auto" (numbers as numbers, anything else as text),
	"number", "text" (natural order, case blind) or a function (a, b) -> number
	on two values. Missing values sort last in either direction. Equal values
	keep their data order. One column sorts at a time.
]]

local Reactive = require(script.Parent.Reactive)

local TableModel = {}

export type Column = {
	id: string,
	key: string?,
	header: any,
	get: (row: any) -> any,
	sortable: boolean,
	sortFn: any,
	descFirst: boolean,
	invert: boolean,
	[string]: any,
}

export type Sort = { id: string, desc: boolean }
-- A Sort, or false for none.
export type Sorting = any

-- Splits text into lowercase runs of digits and non digits, for natural order.
local function chunks(text: string): { string | number }
	local out: { string | number } = {}
	for digits, rest in string.gmatch(string.lower(text), "(%d*)(%D*)") do
		if digits ~= "" then
			table.insert(out, tonumber(digits) :: number)
		end
		if rest ~= "" then
			table.insert(out, rest :: string)
		end
	end
	return out
end

local function compareText(a: string, b: string): number
	local ca, cb = chunks(a), chunks(b)
	for i = 1, math.max(#ca, #cb) do
		local x, y = ca[i], cb[i]
		if x == nil then
			return -1
		elseif y == nil then
			return 1
		end
		if type(x) ~= type(y) then
			-- A number before text, as in "2b" before "b2".
			return if type(x) == "number" then -1 else 1
		end
		if (x :: any) < (y :: any) then
			return -1
		elseif (x :: any) > (y :: any) then
			return 1
		end
	end
	return 0
end

-- -1, 0 or 1: how `a` compares with `b` in ascending order. Values are present.
function TableModel.compare(a: any, b: any, sortFn: any?): number
	local fn = sortFn or "auto"
	if type(fn) == "function" then
		local result = fn(a, b)
		return if result < 0 then -1 elseif result > 0 then 1 else 0
	end
	if fn == "number" or (fn == "auto" and type(a) == "number" and type(b) == "number") then
		local x, y = tonumber(a) or 0, tonumber(b) or 0
		return if x < y then -1 elseif x > y then 1 else 0
	end
	if fn == "text" or fn == "auto" then
		return compareText(tostring(a), tostring(b))
	end
	error(`[Lucy] unknown sortFn "{tostring(fn)}" (auto, number, text or a function)`, 2)
end

function TableModel.normalizeColumns(columns: { any }, options: { [string]: any }): { Column }
	local out: { Column } = {}
	for index, given in columns do
		local id = given.id or given.key
		if type(id) ~= "string" then
			error(`[Lucy] table column {index} needs an id or a key`, 3)
		end
		local key = given.key
		local get = given.get
		if get == nil then
			get = if key
				then function(row: any): any
					return row[key]
				end
				else function(_row: any): any
					return nil
				end
		end
		local column: Column = table.clone(given)
		column.id = id
		column.get = get
		column.sortable = options.sortable ~= false
			and given.sortable ~= false
			and (key ~= nil or given.get ~= nil)
		column.sortFn = given.sortFn or "auto"
		column.descFirst = if given.descFirst ~= nil
			then given.descFirst == true
			else options.descFirst == true
		column.invert = given.invert == true
		table.insert(out, column)
	end
	return out
end

local RowMeta = {}
RowMeta.__index = RowMeta

-- The row's value for a column, by id.
function RowMeta.value(self: any, columnId: string): any
	local column = self._byId[columnId]
	return if column then column.get(self.original) else nil
end

function TableModel.new(options: { [string]: any })
	local columns = TableModel.normalizeColumns(options.columns or {}, options)
	local byId: { [string]: Column } = {}
	for _, column in columns do
		byId[column.id] = column
	end
	local removable = options.removable ~= false
	local manual = options.manual == true
	local rowId = options.rowId

	local given = options.sorting
	local sorting: any = if Reactive.isWritable(given)
		then given
		else Reactive.ref(if given then given else false)

	local function check(value: Sorting)
		if value and byId[value.id] == nil then
			error(`[Lucy] cannot sort by "{value.id}": no column has that id`, 4)
		end
	end
	check(Reactive.peek(sorting))

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
		local current = sorting()
		if manual or not current then
			return list
		end
		local column = byId[current.id]
		if not column then
			return list
		end
		local get, sortFn = column.get, column.sortFn
		local flip = current.desc ~= column.invert -- desc, or asc on an inverted column
		local values = {}
		for _, row in list do
			values[row] = get(row.original)
		end
		table.sort(list, function(a, b)
			local x, y = values[a], values[b]
			if x == nil or y == nil then
				if x == nil and y == nil then
					return a.index < b.index
				end
				return y == nil -- missing values last, either way
			end
			local order = TableModel.compare(x, y, sortFn)
			if order == 0 then
				return a.index < b.index
			end
			if flip then
				return order > 0
			end
			return order < 0
		end)
		return list
	end)

	local model = {}
	model.columns = columns
	model.rows = rows
	model.sorting = function(): Sorting
		return sorting()
	end
	function model.canSort(columnId: string): boolean
		local column = byId[columnId]
		return column ~= nil and column.sortable
	end
	function model.sortedBy(columnId: string): string | false
		local current = sorting()
		if current and current.id == columnId then
			return if current.desc then "desc" else "asc"
		end
		return false
	end
	-- What a header press does: off, then the column's first direction, then the
	-- other, then off again (unless not removable).
	function model.toggle(columnId: string)
		local column = byId[columnId]
		if not column or not column.sortable then
			return
		end
		local first = column.descFirst
		local current = Reactive.peek(sorting)
		local nextSort: Sorting
		if not current or current.id ~= columnId then
			nextSort = { id = columnId, desc = first }
		elseif current.desc == first then
			nextSort = { id = columnId, desc = not first }
		elseif removable then
			nextSort = false
		else
			nextSort = { id = columnId, desc = first }
		end
		sorting(nextSort)
	end
	function model.setSorting(value: Sorting)
		check(value)
		sorting(value)
	end
	return model
end

return TableModel
