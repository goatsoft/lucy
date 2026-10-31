return function()
	local DataGrid = require(script.Parent.DataGrid)
	local Icon = require(script.Parent.Icon)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local PLAYERS = {
		{ userId = 1, name = "Zoe", score = 50 },
		{ userId = 2, name = "amy", score = 90 },
		{ userId = 3, name = "Bob", score = 70 },
	}
	local COLUMNS = {
		{ key = "name", header = "Player" },
		{ key = "score", header = "Score", descFirst = true, align = "right" },
		{ id = "invite", header = "", sortable = false },
	}
	local function make(props: { [string]: any }?)
		local p = table.clone(props or {})
		p.app = app
		p.Parent = gui
		p.data = p.data or PLAYERS
		p.columns = p.columns or COLUMNS
		p.rowId = p.rowId or function(row)
			return row.userId
		end
		p.size = p.size or UDim2.fromOffset(400, 0)
		return DataGrid.new(p)
	end
	-- Row ids top to bottom, by where each built row sits.
	local function order(grid): string
		local ids = {}
		for _, player in PLAYERS do
			local row = grid.table.rowFor(player.userId)
			if row then
				table.insert(ids, { id = player.userId, at = row.LayoutOrder })
			end
		end
		table.sort(ids, function(a, b)
			return a.at < b.at
		end)
		local out = {}
		for _, entry in ids do
			table.insert(out, tostring(entry.id))
		end
		return table.concat(out, ",")
	end

	it("shows rows in data order with no sort, sorted with one", function()
		expect(order(make())).to.equal("1,2,3")
		expect(order(make({ sorting = { id = "score", desc = true } }))).to.equal("2,3,1")
	end)

	it("cycles a header and keeps the sort in app state", function()
		local grid = make({ id = "board" })
		grid:toggle("name")
		expect(order(grid)).to.equal("2,3,1")
		expect(app.state:get("ui.board.sorting").id).to.equal("name")
		grid:toggle("name")
		expect(order(grid)).to.equal("1,3,2")
		grid:toggle("name")
		expect(app.state:get("ui.board.sorting")).to.equal(false)
		expect(order(grid)).to.equal("1,2,3")
	end)

	it("sorts when the state is set from elsewhere", function()
		local grid = make({ id = "board" })
		app.state:set("ui.board.sorting", { id = "score", desc = false })
		expect(order(grid)).to.equal("1,3,2")
	end)

	it("makes sortable headers buttons with a direction icon", function()
		local grid = make()
		local nameHeader = grid.headers.name
		expect(nameHeader:IsA("TextButton")).to.equal(true)
		expect(grid.headers.invite).to.equal(nil)
		local icon = grid.sortIcons.name
		expect(icon.Instance.Visible).to.equal(false)
		grid:toggle("name")
		local up: any = Icon.resolve("lucy:chevron-up")
		expect(icon.Instance.Visible).to.equal(true)
		expect(icon.Instance.Image).to.equal(up.image)
		expect(nameHeader:HasTag("ui-sorted")).to.equal(true)
		grid:toggle("name")
		local down: any = Icon.resolve("lucy:chevron-down")
		expect(icon.Instance.Image).to.equal(down.image)
	end)

	it("follows new data in its current sort", function()
		local data = Reactive.ref(PLAYERS)
		local grid = make({ data = data, sorting = { id = "score", desc = true } })
		local changed = table.clone(PLAYERS)
		changed[1] = { userId = 1, name = "Zoe", score = 100 }
		data(changed)
		expect(order(grid)).to.equal("1,2,3")
	end)

	it("reports sort changes and passes table props through", function()
		local sorts = {}
		local grid = make({
			highlight = function(row)
				return row.userId == 3
			end,
			onSortingChange = function(sorting)
				table.insert(sorts, if sorting then sorting.id else "none")
			end,
		})
		grid:toggle("score")
		expect(sorts[1]).to.equal("score")
		expect(grid.table.rowFor(3):HasTag("ui-table-row-highlight")).to.equal(true)
	end)

	it("can turn sorting off", function()
		local grid = make({ sortable = false })
		expect(grid.headers.name).to.equal(nil)
		grid:toggle("name")
		expect(order(grid)).to.equal("1,2,3")
	end)

	it("sorts by the focused header on Enter", function()
		local grid = make()
		app.input:setMode("keyboard")
		app.input:focus(grid.headers.score)
		app.input:activate()
		expect(order(grid)).to.equal("2,3,1")
	end)
end
