return function()
	local SortModel = require(script.Parent.SortModel)
	local Composables = require(script.Parent.Parent.Composables)
	local Reactive = require(script.Parent.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local DANCES = {
		{ name = "Wave", genre = "House", rarity = 1 },
		{ name = "Bop", genre = "Techno", rarity = 3 },
		{ name = "Slide", genre = "House", rarity = 3 },
		{ name = "Kick", genre = "Anthem", rarity = nil },
		{ name = "Arm", genre = "Techno", rarity = 1 },
	}
	local COLUMNS = {
		{ key = "name" },
		{ key = "genre" },
		{ key = "rarity", descFirst = true },
		{ id = "icon", sortable = false },
	}

	local function names(list: { any }): string
		local out = {}
		for _, item in list do
			table.insert(out, item.name)
		end
		return table.concat(out, ",")
	end

	describe("SortModel", function()
		it("compares numbers, natural text and functions", function()
			expect(SortModel.compare(2, 10, "number")).to.equal(-1)
			expect(SortModel.compare("x9", "x10", "auto")).to.equal(-1)
			expect(SortModel.compare("b", "B", "text")).to.equal(0)
			expect(SortModel.compare(3, 1, function(a, b)
				return a - b
			end)).to.equal(1)
		end)

		it("sorts by one column at a time unless multi", function()
			local model = SortModel.new({ columns = COLUMNS })
			expect(model.sorting()).to.equal(false)
			model.toggle("genre")
			expect(model.sorting().id).to.equal("genre")
			model.toggle("name")
			expect(model.sorting().id).to.equal("name")
			expect(#model.list()).to.equal(1)
			expect(model.priority("name")).to.equal(1)
			expect(model.priority("genre")).to.equal(nil)
		end)

		it("adds a tiebreaker on each new press when multi", function()
			local model = SortModel.new({ columns = COLUMNS, multi = true })
			expect(#model.sorting()).to.equal(0)
			model.toggle("rarity")
			model.toggle("name")
			local list = model.sorting()
			expect(#list).to.equal(2)
			expect(list[1].id).to.equal("rarity")
			expect(list[1].desc).to.equal(true) -- descFirst
			expect(list[2].id).to.equal("name")
			expect(list[2].desc).to.equal(false)
			expect(model.priority("rarity")).to.equal(1)
			expect(model.priority("name")).to.equal(2)
			expect(model.priority("genre")).to.equal(nil)
		end)

		it("flips a sorted column in place, then drops it", function()
			local model = SortModel.new({ columns = COLUMNS, multi = true })
			model.toggle("genre")
			model.toggle("name")
			model.toggle("genre")
			expect(model.sortedBy("genre")).to.equal("desc")
			expect(model.priority("genre")).to.equal(1)
			model.toggle("genre")
			expect(model.sortedBy("genre")).to.equal(false)
			expect(model.priority("name")).to.equal(1)
			expect(#model.sorting()).to.equal(1)
		end)

		it("flips back instead of dropping when not removable", function()
			local model = SortModel.new({ columns = COLUMNS, multi = true, removable = false })
			model.toggle("name")
			model.toggle("name")
			model.toggle("name")
			expect(model.sortedBy("name")).to.equal("asc")
		end)

		it("ignores columns that do not sort", function()
			local model = SortModel.new({ columns = COLUMNS, multi = true })
			model.toggle("icon")
			model.toggle("nope")
			expect(#model.sorting()).to.equal(0)
			expect(model.canSort("icon")).to.equal(false)
			expect(model.canSort("name")).to.equal(true)
		end)

		it("sorts by each sort in turn, missing values last, ties in their order", function()
			local model = SortModel.new({
				columns = COLUMNS,
				multi = true,
				sorting = { { id = "rarity", desc = true }, { id = "name", desc = false } },
			})
			expect(names(model.sort(DANCES))).to.equal("Bop,Slide,Arm,Wave,Kick")
			model.setSorting({ { id = "genre", desc = false } })
			expect(names(model.sort(DANCES))).to.equal("Kick,Wave,Slide,Bop,Arm")
			model.setSorting({})
			expect(names(model.sort(DANCES))).to.equal("Wave,Bop,Slide,Kick,Arm")
		end)

		it("does not change the list it sorts", function()
			local model = SortModel.new({ columns = COLUMNS, sorting = { id = "name", desc = false } })
			local sorted = model.sort(DANCES)
			expect(sorted).never.to.equal(DANCES)
			expect(DANCES[1].name).to.equal("Wave")
		end)

		it("takes one sort as a list of one when multi", function()
			local model =
				SortModel.new({ columns = COLUMNS, multi = true, sorting = { id = "name", desc = true } })
			expect(#model.sorting()).to.equal(1)
			expect(model.sortedBy("name")).to.equal("desc")
		end)

		it("reads and writes a writable ref", function()
			local sorting = Reactive.ref({ { id = "genre", desc = false } })
			local model = SortModel.new({ columns = COLUMNS, multi = true, sorting = sorting })
			model.toggle("name")
			expect(#sorting()).to.equal(2)
			sorting({})
			expect(model.sortedBy("genre")).to.equal(false)
		end)

		it("errors on a sort by a column it does not have", function()
			expect(function()
				SortModel.new({ columns = COLUMNS, sorting = { id = "nope", desc = false } })
			end).to.throw()
			local model = SortModel.new({ columns = COLUMNS, multi = true })
			expect(function()
				model.setSorting({ { id = "nope", desc = false } })
			end).to.throw()
		end)
	end)

	describe("useSort", function()
		local cleanup
		beforeEach(function()
			_, cleanup = Harness.app()
		end)
		afterEach(function()
			cleanup()
		end)

		it("needs an owner", function()
			expect(function()
				Composables.useSort({ data = {}, columns = COLUMNS })
			end).to.throw()
		end)

		it("gives the data sorted, following the data and the sort", function()
			local data = Reactive.ref(DANCES)
			local scope = Reactive.effectScope(true)
			local sorted
			scope:run(function()
				sorted = Composables.useSort({
					data = data,
					columns = COLUMNS,
					multi = true,
					sorting = { { id = "rarity", desc = true } },
				})
			end)
			expect(names(sorted.items())).to.equal("Bop,Slide,Wave,Arm,Kick")
			sorted.toggle("name")
			expect(names(sorted.items())).to.equal("Bop,Slide,Arm,Wave,Kick")
			data({ DANCES[1], DANCES[2] })
			expect(names(sorted.items())).to.equal("Bop,Wave")
			scope:stop()
		end)
	end)
end
