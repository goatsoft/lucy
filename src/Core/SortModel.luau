--!strict
--[[
	SortModel: the sorting core behind Lucy.useSort, useTable and DataGrid. It keeps
	which columns sort and which way, and sorts lists by them. No instances.

		local model = SortModel.new({
			columns = {
				{ key = "name" },                        -- key: the id and the field
				{ id = "power", get = function(item) return item.level * 2 end },
				{ key = "rarity", descFirst = true },    -- first press sorts high to low
				{ key = "rank", invert = true },         -- lower is better
				{ id = "icon", sortable = false },
			},
			sorting = { id = "rarity", desc = true },  -- a value or a writable ref; false for none
			multi = false,             -- true: sorting is a list, each new press adds a tiebreaker
			sortable = true,           -- false: no column sorts
			removable = true,          -- a third press clears that column's sort
			descFirst = false,         -- the first direction for every column
		})
		model.sort(list)        -- a new list in the sort's order (reads the sort, so it tracks)
		model.sorting()         -- { id, desc } or false; with multi, a list of them
		model.list()            -- the sorts as a list either way, first sort first
		model.toggle(id)        -- what a header press does
		model.sortedBy(id)      -- false | "asc" | "desc"
		model.priority(id)      -- 1 for the first sort, 2 for its tiebreaker, nil if unsorted
		model.canSort(id)
		model.setSorting(value)
		model.columns           -- the normalized columns, in order

	A press on a column cycles its first direction, the other, then off (or back
	to the first when not removable). With multi, a press on a column that is not
	sorted adds it after the others, so the first sorted column leads and the next
	breaks its ties; without, it replaces the sort.

	A column's sortFn is "auto" (numbers as numbers, anything else as text),
	"number", "text" (natural order, case blind) or a function (a, b) -> number
	on two values. Missing values sort last in either direction. Items equal on
	every sort keep their order in the list.
]]

local Reactive = require(script.Parent.Reactive)

local SortModel = {}

export type Column = {
	id: string,
	key: string?,
	header: any,
	get: (item: any) -> any,
	sortable: boolean,
	sortFn: any,
	descFirst: boolean,
	invert: boolean,
	[string]: any,
}

export type Sort = { id: string, desc: boolean }
-- A Sort or false; with multi, a list of Sorts.
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
function SortModel.compare(a: any, b: any, sortFn: any?): number
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

function SortModel.normalizeColumns(columns: { any }, options: { [string]: any }): { Column }
	local out: { Column } = {}
	for index, given in columns do
		local id = given.id or given.key
		if type(id) ~= "string" then
			error(`[Lucy] column {index} needs an id or a key`, 3)
		end
		local key = given.key
		local get = given.get
		if get == nil then
			get = if key
				then function(item: any): any
					return item[key]
				end
				else function(_item: any): any
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

-- A sort value as a list: false or nil is none, one sort is a list of one.
local function asList(value: Sorting): { Sort }
	if not value then
		return {}
	end
	if value.id ~= nil then
		return { value }
	end
	return value
end

function SortModel.new(options: { [string]: any })
	local columns = SortModel.normalizeColumns(options.columns or {}, options)
	local byId: { [string]: Column } = {}
	for _, column in columns do
		byId[column.id] = column
	end
	local multi = options.multi == true
	local removable = options.removable ~= false

	-- Stored as the caller gave it: one sort or false, or a list with multi.
	local function shaped(list: { Sort }): Sorting
		if multi then
			return list
		end
		return list[1] or false
	end

	local function check(value: Sorting)
		for _, entry in asList(value) do
			if byId[entry.id] == nil then
				error(`[Lucy] cannot sort by "{entry.id}": no column has that id`, 4)
			end
		end
	end

	local given = options.sorting
	local sorting: any
	if Reactive.isWritable(given) then
		sorting = given
	else
		sorting = Reactive.ref(shaped(asList(given)))
	end
	check(Reactive.peek(sorting))

	local model = {}
	model.columns = columns

	function model.list(): { Sort }
		local list = asList(sorting())
		if not multi and #list > 1 then
			return { list[1] }
		end
		return list
	end
	function model.sorting(): Sorting
		return shaped(model.list())
	end
	function model.canSort(columnId: string): boolean
		local column = byId[columnId]
		return column ~= nil and column.sortable
	end
	function model.sortedBy(columnId: string): string | false
		for _, entry in model.list() do
			if entry.id == columnId then
				return if entry.desc then "desc" else "asc"
			end
		end
		return false
	end
	function model.priority(columnId: string): number?
		for index, entry in model.list() do
			if entry.id == columnId then
				return index
			end
		end
		return nil
	end
	-- What a header press does: the column's first direction, the other, then off
	-- (or back to the first when not removable). With multi a new column joins the
	-- end, as the next tiebreaker; without, it replaces the sort.
	function model.toggle(columnId: string)
		local column = byId[columnId]
		if not column or not column.sortable then
			return
		end
		local first = column.descFirst
		local current = asList(Reactive.peek(sorting))
		if not multi and #current > 1 then
			current = { current[1] }
		end
		local nextList: { Sort } = {}
		local found = false
		for _, entry in current do
			if entry.id == columnId then
				found = true
				if entry.desc == first then
					table.insert(nextList, { id = columnId, desc = not first })
				elseif not removable then
					table.insert(nextList, { id = columnId, desc = first })
				end
			elseif multi then
				table.insert(nextList, entry)
			end
		end
		if not found then
			table.insert(nextList, { id = columnId, desc = first })
		end
		sorting(shaped(nextList))
	end
	function model.setSorting(value: Sorting)
		check(value)
		sorting(if multi then asList(value) else (asList(value)[1] or false))
	end

	-- A new list holding `items` in the sort's order. `valueOf` turns an item into
	-- what the columns read (the item itself by default). Reads the sort, so a
	-- computed calling it follows the sort.
	function model.sort<T>(items: { T }, valueOf: ((T) -> any)?): { T }
		local list = model.list()
		local out = table.clone(items)
		if #list == 0 then
			return out
		end
		local keys = {}
		for _, entry in list do
			local column = byId[entry.id]
			if column then
				table.insert(keys, {
					get = column.get,
					sortFn = column.sortFn,
					flip = entry.desc ~= column.invert, -- desc, or asc on an inverted column
				})
			end
		end
		local values: { { any } } = {}
		local order: { number } = {}
		for index, item in out do
			local source = if valueOf then valueOf(item) else item
			local row = {}
			for k, key in keys do
				row[k] = key.get(source)
			end
			values[index] = row
			order[index] = index
		end
		table.sort(order, function(a: number, b: number): boolean
			local va, vb = values[a], values[b]
			for k, key in keys do
				local x, y = va[k], vb[k]
				if x == nil or y == nil then
					if x ~= nil or y ~= nil then
						return y == nil -- missing values last, either way
					end
				else
					local result = SortModel.compare(x, y, key.sortFn)
					if result ~= 0 then
						if key.flip then
							return result > 0
						end
						return result < 0
					end
				end
			end
			return a < b
		end)
		local sorted = table.create(#out)
		for i, index in order do
			sorted[i] = out[index]
		end
		out = sorted
		return out
	end

	return model
end

return SortModel
