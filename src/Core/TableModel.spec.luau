return function()
	local TableModel = require(script.Parent.TableModel)
	local Composables = require(script.Parent.Parent.Composables)
	local Reactive = require(script.Parent.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	describe("compare", function()
		it("orders numbers, and text naturally without case", function()
			expect(TableModel.compare(2, 10, "number")).to.equal(-1)
			expect(TableModel.compare("item2", "item10", "text")).to.equal(-1)
			expect(TableModel.compare("apple", "Banana", "text")).to.equal(-1)
			expect(TableModel.compare("b", "B", "text")).to.equal(0)
			expect(TableModel.compare(5, 5, "auto")).to.equal(0)
			expect(TableModel.compare(3, 20, "auto")).to.equal(-1)
			expect(TableModel.compare("x9", "x10", "auto")).to.equal(-1)
		end)

		it("takes a function", function()
			local order = { low = 1, mid = 2, high = 3 }
			local function byRank(a, b)
				return order[a] - order[b]
			end
			expect(TableModel.compare("high", "low", byRank) > 0).to.equal(true)
		end)
	end)

	describe("useTable", function()
		local app, cleanup
		beforeEach(function()
			app, cleanup = Harness.app()
		end)
		afterEach(function()
			cleanup()
		end)

		local PLAYERS = {
			{ userId = 1, name = "Zoe", score = 50, rank = 3 },
			{ userId = 2, name = "amy", score = 90, rank = 1 },
			{ userId = 3, name = "Bob", score = nil, rank = 4 },
			{ userId = 4, name = "Cat", score = 70, rank = 2 },
		}
		local COLUMNS = {
			{ key = "name", header = "Player" },
			{ key = "score", header = "Score", descFirst = true },
			{ key = "rank", header = "Rank", invert = true },
			{
				id = "initial",
				get = function(row)
					return string.sub(row.name, 1, 1)
				end,
			},
			{ id = "actions", sortable = false },
		}

		local function make(options: { [string]: any }?)
			local opts = table.clone(options or {})
			opts.data = opts.data or PLAYERS
			opts.columns = opts.columns or COLUMNS
			opts.rowId = opts.rowId or function(row)
				return row.userId
			end
			local scope = Reactive.effectScope(true)
			local model
			scope:run(function()
				model = Composables.useTable(opts)
			end)
			return model, scope
		end
		local function names(model): string
			local out = {}
			for _, row in model.rows() do
				table.insert(out, row.original.name)
			end
			return table.concat(out, ",")
		end

		it("needs an owner", function()
			expect(function()
				Composables.useTable({ data = {}, columns = {} })
			end).to.throw()
		end)

		it("keeps data order with no sorting, and gives rows ids and values", function()
			local model, scope = make()
			expect(names(model)).to.equal("Zoe,amy,Bob,Cat")
			local first = model.rows()[1]
			expect(first.id).to.equal(1)
			expect(first.index).to.equal(1)
			expect(first:value("score")).to.equal(50)
			expect(first:value("initial")).to.equal("Z")
			expect(model.sorting()).to.equal(false)
			scope:stop()
		end)

		it("sorts by the starting sort, missing values last", function()
			local model, scope = make({ sorting = { id = "score", desc = true } })
			expect(names(model)).to.equal("amy,Cat,Zoe,Bob")
			expect(model.sortedBy("score")).to.equal("desc")
			expect(model.sortedBy("name")).to.equal(false)
			scope:stop()
		end)

		it("cycles a header: first direction, the other, then none", function()
			local model, scope = make()
			model.toggle("name")
			expect(model.sortedBy("name")).to.equal("asc")
			expect(names(model)).to.equal("amy,Bob,Cat,Zoe")
			model.toggle("name")
			expect(model.sortedBy("name")).to.equal("desc")
			expect(names(model)).to.equal("Zoe,Cat,Bob,amy")
			model.toggle("name")
			expect(model.sorting()).to.equal(false)
			expect(names(model)).to.equal("Zoe,amy,Bob,Cat")
			scope:stop()
		end)

		it("starts descending for descFirst columns and keeps missing values last", function()
			local model, scope = make()
			model.toggle("score")
			expect(model.sortedBy("score")).to.equal("desc")
			expect(names(model)).to.equal("amy,Cat,Zoe,Bob")
			model.toggle("score")
			expect(names(model)).to.equal("Zoe,Cat,amy,Bob")
			scope:stop()
		end)

		it("inverts a column where lower is better", function()
			local model, scope = make()
			model.toggle("rank")
			expect(model.sortedBy("rank")).to.equal("asc")
			-- Inverted: ascending shows the worst rank first.
			expect(names(model)).to.equal("Bob,Zoe,Cat,amy")
			scope:stop()
		end)

		it("moves to another column in its first direction", function()
			local model, scope = make()
			model.toggle("name")
			model.toggle("score")
			expect(model.sortedBy("name")).to.equal(false)
			expect(model.sortedBy("score")).to.equal("desc")
			scope:stop()
		end)

		it("does not clear when removable is false", function()
			local model, scope = make({ removable = false })
			model.toggle("name")
			model.toggle("name")
			model.toggle("name")
			expect(model.sortedBy("name")).to.equal("asc")
			scope:stop()
		end)

		it("ignores columns that cannot sort", function()
			local model, scope = make()
			expect(model.canSort("actions")).to.equal(false)
			expect(model.canSort("initial")).to.equal(true)
			model.toggle("actions")
			expect(model.sorting()).to.equal(false)
			local off, offScope = make({ sortable = false })
			expect(off.canSort("name")).to.equal(false)
			scope:stop()
			offScope:stop()
		end)

		it("keeps equal values in data order", function()
			local data = {
				{ userId = 1, team = "red" },
				{ userId = 2, team = "blue" },
				{ userId = 3, team = "red" },
				{ userId = 4, team = "blue" },
			}
			local model, scope = make({ data = data, columns = { { key = "team" } } })
			model.toggle("team")
			local ids = {}
			for _, row in model.rows() do
				table.insert(ids, row.id)
			end
			expect(table.concat(ids, ",")).to.equal("2,4,1,3")
			scope:stop()
		end)

		it("leaves data as it is when sorting is manual, but tracks the sort", function()
			local model, scope = make({ manual = true })
			model.toggle("name")
			expect(model.sortedBy("name")).to.equal("asc")
			expect(names(model)).to.equal("Zoe,amy,Bob,Cat")
			scope:stop()
		end)

		it("follows data in a ref", function()
			local data = Reactive.ref({ { userId = 1, name = "B" } })
			local model, scope = make({ data = data, sorting = { id = "name", desc = false } })
			data({ { userId = 1, name = "B" }, { userId = 2, name = "A" } })
			expect(names(model)).to.equal("A,B")
			scope:stop()
		end)

		it("writes the sort through a ref it was given", function()
			local sorting = Reactive.ref(false)
			local model, scope = make({ sorting = sorting })
			model.toggle("name")
			expect(sorting().id).to.equal("name")
			sorting({ id = "score", desc = true })
			expect(names(model)).to.equal("amy,Cat,Zoe,Bob")
			scope:stop()
		end)

		it("rejects a column with no id or key, and unknown sorts", function()
			expect(function()
				make({ columns = { { header = "?" } } })
			end).to.throw()
			expect(function()
				make({ sorting = { id = "nope", desc = false } })
			end).to.throw()
		end)
	end)
end
