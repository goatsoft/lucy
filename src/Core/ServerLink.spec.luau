return function()
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Server = require(script.Parent.Server)

	-- A client transport that records what the App sends and answers calls itself.
	local function fakeClient()
		local transport = { sent = {} :: { any }, answer = nil :: any }
		function transport.send(...)
			table.insert(transport.sent, table.pack(...))
		end
		function transport.call(name: string, ...)
			if transport.answer then
				return transport.answer(name, ...)
			end
			return true, nil
		end
		return transport
	end

	local app, cleanup, client
	beforeEach(function()
		client = fakeClient()
		app, cleanup = Harness.app({ server = { transport = client } })
	end)
	afterEach(function()
		cleanup()
	end)

	it("has no server link unless asked", function()
		local plain, done = Harness.app()
		local has = plain.server ~= nil
		done()
		expect(has).to.equal(false)
	end)

	it("tells the server it is ready", function()
		expect(client.sent[1][1]).to.equal("ready")
	end)

	it("mirrors shared state at server.* and the player's own at server.me.*", function()
		app.server:_receive({
			shared = { { "", { show = { phase = "Signup", round = 1 } } } },
			me = { { "", { coins = 50 } } },
		})
		expect(app.state:get("server.show.phase")).to.equal("Signup")
		expect(app.state:get("server.show.round")).to.equal(1)
		expect(app.state:get("server.me.coins")).to.equal(50)
	end)

	it("applies changes and removals by path", function()
		app.server:_receive({ shared = { { "", { show = { phase = "Signup", winner = "Kiko" } } } } })
		app.server:_receive({ shared = { { "show.phase", "Live" }, { "show.winner" } } })
		expect(app.state:get("server.show.phase")).to.equal("Live")
		expect(app.state:get("server.show.winner")).to.equal(nil)
	end)

	it("keeps server.me when shared state is replaced whole", function()
		app.server:_receive({ me = { { "", { coins = 7 } } } })
		app.server:_receive({ shared = { { "", { show = { phase = "Live" } } } } })
		expect(app.state:get("server.me.coins")).to.equal(7)
		expect(app.state:get("server.show.phase")).to.equal("Live")
	end)

	it("updates bindings that follow server state", function()
		local phase = app.state:ref("server.show.phase")
		local Reactive = require(script.Parent.Reactive)
		local seen = {}
		local scope = Reactive.effectScope()
		scope:run(function()
			Reactive.watchEffect(function()
				table.insert(seen, phase())
			end)
		end)
		app.server:_receive({ shared = { { "show.phase", "Live" } } })
		scope:stop()
		expect(seen[#seen]).to.equal("Live")
	end)

	it("sends requests to the server", function()
		app.server:send("vote", "House", 2)
		local last = client.sent[#client.sent]
		expect(last[1]).to.equal("send")
		expect(last[2]).to.equal("vote")
		expect(last[3]).to.equal("House")
		expect(last[4]).to.equal(2)
	end)

	it("returns what the server answers to a call, and raises its error", function()
		client.answer = function(name, value)
			if name == "double" then
				return true, value * 2
			end
			return false, "no handler"
		end
		expect(app.server:call("double", 21)).to.equal(42)
		expect(function()
			app.server:call("missing")
		end).to.throw()
	end)

	it("works end to end with a Server", function()
		local who = { UserId = 7, Name = "Dancer7" }
		local server
		local link = {}
		function link.send(kind: string, ...)
			if kind == "ready" then
				server:_ready(who)
			elseif kind == "send" then
				server:_request(who, ...)
			end
		end
		function link.call(name: string, ...)
			return server:_request(who, name, ...)
		end
		local linked, done
		local toClient = {}
		function toClient.send(_player: any, message: any)
			if linked then
				linked.server:_receive(message)
			end
		end
		server = Server.new({ transport = toClient, players = false, autoFlush = false })
		server:_join(who)
		server.state:set("shared.show.phase", "Signup")
		server:player(who):set("coins", 3)

		linked, done = Harness.app({ namePrefix = "LucyLinked_", server = { transport = link } })
		-- The App said it was ready while being made, before `linked` was set: again.
		server:_ready(who)

		server:handle("earn", function(player, amount)
			server:player(player):update("coins", function(n)
				return n + amount
			end)
			return true
		end)
		local answered = linked.server:call("earn", 4)
		server:flush()
		local phase = linked.state:get("server.show.phase")
		local coins = linked.state:get("server.me.coins")
		done()
		server:destroy()
		expect(answered).to.equal(true)
		expect(phase).to.equal("Signup")
		expect(coins).to.equal(7)
	end)
end
