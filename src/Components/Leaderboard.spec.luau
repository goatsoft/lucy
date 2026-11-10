return function()
	local Leaderboard = require(script.Parent.Leaderboard)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Reactive = require(script.Parent.Parent.Core.Reactive)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local ROWS = {
		{ userId = 11, name = "Sasha", value = 14850 },
		{ userId = 12, name = "Tessa", value = 12400 },
		{ userId = 13, name = "Kiko", value = 9800 },
		{ userId = 14, name = "Jax", value = 120 },
	}

	it("draws a row for each entry, best first, with its rank, name and value", function()
		local board = Leaderboard.new({ app = app, Parent = gui, rows = ROWS })
		expect(board.rowCount()).to.equal(4)
		local first = board.rowFor(11)
		expect(first).to.be.ok()
		expect(first.LayoutOrder).to.equal(1)
		expect(board.rankLabelFor(11).Text).to.equal("1")
		expect(board.nameLabelFor(11).Text).to.equal("Sasha")
		expect(board.valueLabelFor(11).Text).to.equal("14,850")
		expect(board.rankLabelFor(14).Text).to.equal("4")
		expect(board.rowFor(14).LayoutOrder).to.equal(4)
	end)

	it("formats values with the game's format", function()
		local board = Leaderboard.new({
			app = app,
			Parent = gui,
			rows = ROWS,
			format = function(value: number)
				return `{value} PTS`
			end,
		})
		expect(board.valueLabelFor(12).Text).to.equal("12400 PTS")
	end)

	it("tints the top three in the medal colours and shows a medal icon in place of the number", function()
		local board = Leaderboard.new({
			app = app,
			Parent = gui,
			rows = ROWS,
			medals = { "lucide:heart", "lucide:play", "lucide:bold" },
		})
		expect(board.rowFor(11):HasTag("ui-leaderboard-medal-gold")).to.equal(true)
		expect(board.rowFor(12):HasTag("ui-leaderboard-medal-silver")).to.equal(true)
		expect(board.rowFor(13):HasTag("ui-leaderboard-medal-bronze")).to.equal(true)
		expect(board.rowFor(14):HasTag("ui-leaderboard-medal-gold")).to.equal(false)
		expect(board.medalFor(11).Visible).to.equal(true)
		expect(board.rankLabelFor(11).Visible).to.equal(false)
		expect(board.medalFor(14).Visible).to.equal(false)
		expect(board.rankLabelFor(14).Visible).to.equal(true)
	end)

	it("keeps the number with no medal icons, still in the medal colours", function()
		local board = Leaderboard.new({ app = app, Parent = gui, rows = ROWS })
		expect(board.rankLabelFor(11).Visible).to.equal(true)
		expect(board.rowFor(11):HasTag("ui-leaderboard-medal-gold")).to.equal(true)
	end)

	it("can leave out the medals altogether", function()
		local board = Leaderboard.new({ app = app, Parent = gui, rows = ROWS, medals = false })
		expect(board.rowFor(11):HasTag("ui-leaderboard-medal-gold")).to.equal(false)
	end)

	it("lights the player's own row and leaves the pinned row hidden while they are listed", function()
		local board = Leaderboard.new({
			app = app,
			Parent = gui,
			rows = ROWS,
			own = { userId = 12, name = "Tessa", value = 12400, rank = 2 },
		})
		expect(board.rowFor(12):HasTag("ui-leaderboard-row-own")).to.equal(true)
		expect(board.rowFor(11):HasTag("ui-leaderboard-row-own")).to.equal(false)
		expect(board.pinned.Visible).to.equal(false)
	end)

	it("pins the player's own row under the list when they are not in it", function()
		local board = Leaderboard.new({
			app = app,
			Parent = gui,
			rows = ROWS,
			own = { userId = 99, name = "Me", value = 50, rank = 37 },
		})
		expect(board.pinned.Visible).to.equal(true)
		expect(board.ownRankLabel.Text).to.equal("37")
		expect(board.ownNameLabel.Text).to.equal("Me")
		expect(board.ownValueLabel.Text).to.equal("50")
	end)

	it("shows the unranked text when the player's rank is not known", function()
		local board = Leaderboard.new({
			app = app,
			Parent = gui,
			rows = ROWS,
			own = { userId = 99, name = "Me", value = 3 },
			unranked = "100+",
		})
		expect(board.ownRankLabel.Text).to.equal("100+")
	end)

	it("follows reactive rows, updating a row in place", function()
		local rows = Reactive.ref({ { userId = 1, name = "A", value = 5 } })
		local board = Leaderboard.new({ app = app, Parent = gui, rows = rows })
		local row = board.rowFor(1)
		rows({ { userId = 2, name = "B", value = 9 }, { userId = 1, name = "A", value = 6 } })
		expect(board.rowFor(1)).to.equal(row)
		expect(board.rankLabelFor(1).Text).to.equal("2")
		expect(board.valueLabelFor(1).Text).to.equal("6")
		expect(board.rowCount()).to.equal(2)
	end)

	it("shows skeleton rows while loading, and the rows after", function()
		local loading = Reactive.ref(true)
		local board =
			Leaderboard.new({ app = app, Parent = gui, rows = ROWS, loading = loading, placeholders = 3 })
		expect(board.skeletons.Visible).to.equal(true)
		expect(board.list.Visible).to.equal(false)
		loading(false)
		expect(board.skeletons.Visible).to.equal(false)
		expect(board.list.Visible).to.equal(true)
	end)

	it("says so when there is no one yet", function()
		local board = Leaderboard.new({ app = app, Parent = gui, rows = {}, empty = "No one yet" })
		expect(board.emptyLabel.Visible).to.equal(true)
		expect(board.emptyLabel.Text).to.equal("No one yet")
	end)

	it("rejects an unknown size", function()
		expect(function()
			Leaderboard.new({ app = app, Parent = gui, rows = ROWS, size = "huge" })
		end).to.throw()
	end)
end
