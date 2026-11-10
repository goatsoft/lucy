return function()
	local Boards = require(script.Parent.Boards)
	local DataQueue = require(script.Parent.DataQueue)
	local Server = require(script.Parent.Server)

	-- A DataStoreService that records which ordered stores are opened, then keeps them in
	-- memory (opening one fails, so the queue keeps that handle's data itself).
	local function recordingService()
		local service = { opened = {} :: { { name: string, scope: string? } } }
		function service:GetDataStore()
			return {}
		end
		function service:GetOrderedDataStore(name: string, scope: string?)
			table.insert(service.opened, { name = name, scope = scope })
			error("kept in memory for the spec")
		end
		function service:GetRequestBudgetForRequestType(): number
			return 100
		end
		return service
	end

	local function dancer(userId: number, name: string): any
		return { UserId = userId, DisplayName = name }
	end
	local NOVA, KAI, JUNO, REMY =
		dancer(11, "Nova"), dancer(12, "Kai"), dancer(13, "Juno"), dancer(14, "Remy")

	-- Monday 2026-11-09 12:00 UTC
	local MONDAY = 1794225600

	local service, queue, boards, now
	local function make(options: { [string]: any }?)
		service = recordingService()
		queue = DataQueue.new({
			service = service,
			autoRun = false,
			bindToClose = false,
			warn = function() end,
			inStudio = false,
		})
		now = MONDAY
		local opts = {
			queue = queue,
			boards = {
				combo = { store = "BestCombos", periods = { "all", "week" } },
				coins = { store = "CoinsEarned", kind = "total", periods = { "all" } },
			},
			now = function()
				return now
			end,
			name = function(userId: number): string?
				return if userId == 99 then "DJ Lucy" else nil
			end,
		}
		for key, value in (options or {}) :: { [string]: any } do
			opts[key] = value
		end
		boards = Boards.new(opts)
	end

	afterEach(function()
		if boards then
			boards:destroy()
			boards = nil
		end
		if queue then
			queue:destroy()
		end
	end)

	it("rejects an unknown kind or period", function()
		expect(function()
			make({ boards = { combo = { store = "BestCombos", kind = "most" } } })
		end).to.throw()
		expect(function()
			make({ boards = { combo = { store = "BestCombos", periods = { "month" } } } })
		end).to.throw()
	end)

	it("keeps each dancer's best, best first, with ranks and names", function()
		make()
		boards:post(NOVA, "combo", 40)
		boards:post(KAI, "combo", 55)
		boards:post(NOVA, "combo", 32) -- lower than her best: stays 40
		local answer = boards:get("combo")
		expect(answer.board).to.equal("combo")
		expect(answer.period).to.equal("all")
		expect(#answer.rows).to.equal(2)
		expect(answer.rows[1].name).to.equal("Kai")
		expect(answer.rows[1].value).to.equal(55)
		expect(answer.rows[1].rank).to.equal(1)
		expect(answer.rows[2].userId).to.equal(11)
		expect(answer.rows[2].value).to.equal(40)
		expect(answer.rows[2].rank).to.equal(2)
	end)

	it("adds up a total board", function()
		make()
		boards:post(NOVA, "coins", 100)
		boards:post(NOVA, "coins", 25)
		expect(boards:get("coins").rows[1].value).to.equal(125)
	end)

	it("posts to every period, and set writes one value as it is", function()
		make()
		boards:post(NOVA, "combo", 40)
		expect(boards:get("combo", "week").rows[1].value).to.equal(40)
		boards:set(NOVA, "combo", 12, "week")
		expect(boards:get("combo", "week").rows[1].value).to.equal(12)
		expect(boards:get("combo", "all").rows[1].value).to.equal(40)
		boards:set(KAI, "combo", 7)
		expect(boards:get("combo", "all").rows[2].value).to.equal(7)
		expect(boards:get("combo", "week").rows[2].value).to.equal(7)
	end)

	it("leaves out values that are not above zero, and rounds down", function()
		make()
		boards:post(NOVA, "combo", 0)
		boards:post(KAI, "combo", -5)
		boards:post(JUNO, "combo", 8.7)
		local rows = boards:get("combo").rows
		expect(#rows).to.equal(1)
		expect(rows[1].value).to.equal(8)
	end)

	it("keeps a week in its own scope of the store, and starts again on Monday", function()
		make()
		boards:post(NOVA, "combo", 40)
		local week = Boards.weekId(MONDAY)
		local scopes = {}
		for _, opened in service.opened do
			if opened.name == "BestCombos" then
				scopes[opened.scope or "all"] = true
			end
		end
		expect(scopes.all).to.equal(true)
		expect(scopes[`w{week}`]).to.equal(true)
		-- Sunday night is the same week; Monday is a new one
		now = MONDAY + 6 * 86400 + 11 * 3600
		expect(#boards:get("combo", "week").rows).to.equal(1)
		now = MONDAY + 7 * 86400
		expect(Boards.weekId(now)).to.equal(week + 1)
		expect(#boards:get("combo", "week").rows).to.equal(0)
		expect(#boards:get("combo", "all").rows).to.equal(1)
	end)

	it("gives the asking dancer their own row, ranked when they are deep enough", function()
		make({ depth = 2, top = 1 })
		boards:post(NOVA, "combo", 40)
		boards:post(KAI, "combo", 55)
		boards:post(JUNO, "combo", 20)
		local nova = boards:get("combo", "all", NOVA)
		expect(#nova.rows).to.equal(1)
		expect(nova.me.rank).to.equal(2)
		expect(nova.me.value).to.equal(40)
		expect(nova.me.name).to.equal("Nova")
		-- Juno is past the depth: her value, no rank
		local juno = boards:get("combo", "all", JUNO)
		expect(juno.me.rank).to.equal(nil)
		expect(juno.me.value).to.equal(20)
		-- Remy has nothing on the board
		local remy = boards:get("combo", "all", REMY)
		expect(remy.me.value).to.equal(0)
		expect(remy.me.rank).to.equal(nil)
	end)

	it("names a dancer with the game's name function first", function()
		make()
		boards:set(99, "combo", 70)
		expect(boards:get("combo").rows[1].name).to.equal("DJ Lucy")
	end)

	it("answers the boards.get request, and refuses a board it does not keep", function()
		local server =
			Server.new({ transport = { send = function() end }, players = false, autoFlush = false })
		make({ server = server })
		server:_join(NOVA)
		boards:post(NOVA, "combo", 40)
		local ok, answer = server:_request(NOVA, "boards.get", "combo", "week")
		expect(ok).to.equal(true)
		expect(answer.period).to.equal("week")
		expect(answer.me.rank).to.equal(1)
		local refused = server:_request(NOVA, "boards.get", "dances", "all")
		expect(refused).to.equal(false)
		local badPeriod = server:_request(NOVA, "boards.get", "coins", "week") -- coins is all time only
		expect(badPeriod).to.equal(false)
		boards:destroy()
		boards = nil
		expect((server:_request(NOVA, "boards.get", "combo"))).to.equal(false)
		server:destroy()
	end)

	it("publishes a board's top rows to the server's state, and again on refresh", function()
		local server =
			Server.new({ transport = { send = function() end }, players = false, autoFlush = false })
		make({ server = server })
		boards:post(NOVA, "combo", 40)
		boards:publish("combo", { count = 5, every = 60 })
		local rows = server.state:get("shared.boards.combo")
		expect(#rows).to.equal(1)
		expect(rows[1].name).to.equal("Nova")
		boards:post(KAI, "combo", 55)
		boards:publish("coins", { path = "shared.walls.coins" })
		boards:refresh()
		expect(#server.state:get("shared.boards.combo")).to.equal(2)
		expect(server.state:get("shared.walls.coins")).to.be.ok()
		server:destroy()
	end)
end
