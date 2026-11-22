--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local SortModel = require(script.Parent.Parent.Core.SortModel)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Sorted rows from data and column definitions, for tables and anything list
	shaped (ADR 0025). Returns { rows, sorting, toggle, sortedBy, canSort,
	setSorting, columns }; see Core/TableModel for the options. Its computeds
	belong to the owner.
]]
--[[
	Any list, sorted by one column or several (Core/SortModel has the options):
	data (an array, a ref or a getter), columns, sorting, multi, sortable,
	removable, descFirst. Returns the sort model (sorting, list, toggle,
	sortedBy, priority, canSort, setSorting, columns, sort) and items, a
	computed of the data in order. With multi, a press on a new column adds it
	as the next tiebreaker. Its computed belongs to the owner.

		local dances = Lucy.useSort({
			data = owned,
			columns = { { key = "name" }, { key = "genre" }, { id = "rarity", get = rank, descFirst = true } },
			sorting = { { id = "rarity", desc = true } },
			multi = true,
		})
		Lucy.each(dances.items, tile)
]]
local function useSort(options: { [string]: any })
	requireOwner("useSort")
	local model: any = SortModel.new(options)
	model.items = Reactive.computed(function(): { any }
		return model.sort(Reactive.toValue(options.data) or {})
	end)
	return model
end

return useSort
