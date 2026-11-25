return function()
	local Server = require(script.Parent.Server)

	-- A remote copies what it sends, as this does.
	local function copy(value: any): any
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for key, child in value do
			out[key] = copy(child)
		end
		return out
	end

	-- A transport that records what the server sends, per player, instead of using remotes.
	local function fakeTransport()
		local transport = { sent = {} :: { [any]: { any } }, calls = {} }
		function transport.send(player: any, message: any)
			transport.sent[player] = transport.sent[player] or {}
			table.insert(transport.sent[player], copy(message))
		end
		return transport
	end

	local function player(id: number): any
		return { UserId = id, Name = `Dancer{id}` }
	end

	-- Applies every op the player has been sent to a plain table per root, like a client would.
	local function mirror(transport: any, who: any): { shared: any, me: any }
		local out = { shared = nil :: any, me = nil :: any }
		local function apply(root: string, ops: { any })
			for _, op in ops do
				-- { path, value } sets; { path } alone removes (remotes cut arrays at a nil)
				local path, value = op[1], op[2]
				local removed = value == nil
				if path == "" then
					out[root] = if removed then nil else value
					continue
				end
				local node = out[root]
				if type(node) ~= "table" then
					node = {}
					out[root] = node
				end
				local keys = string.split(path, ".")
				for i = 1, #keys - 1 do
					local key = tonumber(keys[i]) or keys[i]
					node[key] = node[key] or {}
					node = node[key]
				end
				local last = tonumber(keys[#keys]) or keys[#keys]
				node[last] = if removed then nil else value
			end
		end
		for _, message in transport.sent[who] or {} do
			if message.shared then
				apply("shared", message.shared)
			end
			if message.me then
				apply("me", message.me)
			end
		end
		return out
	end

	local transport, server
	beforeEach(function()
		transport = fakeTransport()
		server = Server.new({ transport = transport, players = false, autoFlush = false })
	end)
	afterEach(function()
		server:destroy()
	end)

	it("holds its state in a store with the usual methods", function()
		server.state:set("shared.show.phase", "Signup")
		expect(server.state:get("shared.show.phase")).to.equal("Signup")
		server.state:merge("shared.show", { round = 2 })
		expect(server.state:get("shared.show.round")).to.equal(2)
	end)

	it("sends a player who is ready everything shared and their own state", function()
		local a = player(1)
		server.state:set("shared.show", { phase = "Signup", round = 1 })
		server:_join(a)
		server:player(a):set("coins", 50)
		server:_ready(a)
		local seen = mirror(transport, a)
		expect(seen.shared.show.phase).to.equal("Signup")
		expect(seen.shared.show.round).to.equal(1)
		expect(seen.me.coins).to.equal(50)
	end)

	it("sends nothing to a player before they are ready", function()
		local a = player(1)
		server:_join(a)
		server.state:set("shared.show.phase", "Signup")
		server:flush()
		expect(transport.sent[a]).to.equal(nil)
	end)

	it("sends only what changed, once per flush", function()
		local a = player(1)
		server.state:set("shared.show", { phase = "Signup", round = 1, roster = { "Kiko", "Neo" } })
		server:_join(a)
		server:_ready(a)
		local before = #transport.sent[a]

		server.state:set("shared.show.round", 2)
		server.state:set("shared.show.round", 3)
		server:flush()
		expect(#transport.sent[a]).to.equal(before + 1)
		local ops = transport.sent[a][#transport.sent[a]].shared
		expect(#ops).to.equal(1)
		expect(ops[1][1]).to.equal("show.round")
		expect(ops[1][2]).to.equal(3)

		server:flush()
		expect(#transport.sent[a]).to.equal(before + 1)
	end)

	it("sends removals", function()
		local a = player(1)
		server.state:set("shared.show", { phase = "Signup", winner = "Kiko" })
		server:_join(a)
		server:_ready(a)
		server.state:remove("shared.show.winner")
		server:flush()
		local seen = mirror(transport, a)
		expect(seen.shared.show.winner).to.equal(nil)
		expect(seen.shared.show.phase).to.equal("Signup")
	end)

	it("keeps each player's state to that player", function()
		local a, b = player(1), player(2)
		server:_join(a)
		server:_join(b)
		server:_ready(a)
		server:_ready(b)
		server:player(a):set("coins", 10)
		server:player(b):set("coins", 99)
		server:flush()
		expect(mirror(transport, a).me.coins).to.equal(10)
		expect(mirror(transport, b).me.coins).to.equal(99)
	end)

	it("never sends state outside shared and players", function()
		local a = player(1)
		server:_join(a)
		server:_ready(a)
		server.state:set("secret.seed", 1234)
		server:flush()
		for _, message in transport.sent[a] do
			for root in message do
				expect(root == "shared" or root == "me").to.equal(true)
			end
		end
	end)

	it("keeps a player's state under players.u<UserId> and drops it when they leave", function()
		local a = player(42)
		server:_join(a)
		server:player(a):set("coins", 5)
		expect(server.state:get("players.u42.coins")).to.equal(5)
		server:_leave(a)
		expect(server.state:get("players.u42")).to.equal(nil)
	end)

	it("hands requests to their handler with the player", function()
		local a = player(1)
		server:_join(a)
		local got
		server:handle("signup", function(who, genre)
			got = { who, genre }
			return "ok"
		end)
		local ok, result = server:_request(a, "signup", "House")
		expect(ok).to.equal(true)
		expect(result).to.equal("ok")
		expect(got[1]).to.equal(a)
		expect(got[2]).to.equal("House")
	end)

	it("answers a request with no handler, or a failing one, with an error", function()
		local a = player(1)
		server:_join(a)
		local ok = server:_request(a, "nothing")
		expect(ok).to.equal(false)
		server:handle("boom", function()
			error("bad")
		end)
		local ok2, message = server:_request(a, "boom")
		expect(ok2).to.equal(false)
		expect(type(message)).to.equal("string")
	end)

	it("refuses a second handler for a name", function()
		server:handle("vote", function() end)
		expect(function()
			server:handle("vote", function() end)
		end).to.throw()
	end)

	it("ignores requests from players who have left", function()
		local a = player(1)
		local called = false
		server:handle("vote", function()
			called = true
		end)
		local ok = server:_request(a, "vote")
		expect(ok).to.equal(false)
		expect(called).to.equal(false)
	end)

	describe("checks and rates", function()
		local Check = require(script.Parent.Check)
		local now, rejected, checked
		beforeEach(function()
			now = 0
			rejected = {}
			checked = Server.new({
				transport = fakeTransport(),
				players = false,
				autoFlush = false,
				clock = function()
					return now
				end,
				onReject = function(_, name, why)
					table.insert(rejected, { name, why })
				end,
			})
		end)
		afterEach(function()
			checked:destroy()
		end)

		it("runs the handler only when every argument passes its check", function()
			local a = player(1)
			checked:_join(a)
			local calls = 0
			checked:handle("buy", function()
				calls += 1
			end, { check = { Check.string({ max = 8 }), Check.number({ min = 1, max = 5 }) } })
			expect((checked:_request(a, "buy", "glock", 2))).to.equal(true)
			expect((checked:_request(a, "buy", "glock", 0 / 0))).to.equal(false)
			expect((checked:_request(a, "buy", { "glock" }, 2))).to.equal(false)
			expect((checked:_request(a, "buy", "glock", 2, "extra"))).to.equal(false)
			expect(calls).to.equal(1)
			task.wait()
			expect(#rejected).to.equal(3)
		end)

		it("limits how often one player may ask, refilling over time", function()
			local a, b = player(1), player(2)
			checked:_join(a)
			checked:_join(b)
			checked:handle("fire", function() end, { check = {}, rate = { perSecond = 2, burst = 2 } })
			expect((checked:_request(a, "fire"))).to.equal(true)
			expect((checked:_request(a, "fire"))).to.equal(true)
			expect((checked:_request(a, "fire"))).to.equal(false)
			expect((checked:_request(b, "fire"))).to.equal(true) -- another player's bucket
			now += 0.5
			expect((checked:_request(a, "fire"))).to.equal(true)
		end)

		it("lets a rate under one a second through now and then", function()
			local a = player(1)
			checked:_join(a)
			checked:handle("save", function() end, { check = {}, rate = { perSecond = 0.5 } })
			expect((checked:_request(a, "save"))).to.equal(true)
			expect((checked:_request(a, "save"))).to.equal(false)
			now += 2
			expect((checked:_request(a, "save"))).to.equal(true)
		end)

		it("keeps the reason a handler failed on the server", function()
			local a = player(1)
			checked:_join(a)
			checked:handle("boom", function()
				error("secret path in ServerScriptService")
			end)
			local ok, message = checked:_request(a, "boom")
			expect(ok).to.equal(false)
			expect((string.find(message, "secret", 1, true))).to.equal(nil)
		end)

		it("refuses an unchecked handler on a strict server", function()
			local strict =
				Server.new({ transport = fakeTransport(), players = false, autoFlush = false, strict = true })
			expect(function()
				strict:handle("vote", function() end)
			end).to.throw()
			strict:handle("vote", function() end, { check = {} })
			strict:destroy()
		end)

		it("takes a request only on its own channel", function()
			local a = player(1)
			checked:_join(a)
			checked:handle("aim", function() end, { check = { Check.vector() }, unreliable = true })
			checked:handle("vote", function() end, { check = {} })
			expect((checked:_requestStream(a, "aim", Vector3.zero))).to.equal(true)
			expect((checked:_request(a, "aim", Vector3.zero))).to.equal(false)
			expect((checked:_requestStream(a, "vote"))).to.equal(false)
		end)
	end)

	it("sends everything again for a repeated ready only now and then", function()
		local now = 0
		local t = fakeTransport()
		local s = Server.new({
			transport = t,
			players = false,
			autoFlush = false,
			clock = function()
				return now
			end,
		})
		local a = player(1)
		s:_join(a)
		for _ = 1, 50 do
			s:_ready(a)
		end
		-- the first, and one repeat (an App that said ready while it was being made)
		expect(#t.sent[a]).to.equal(2)
		now += 10
		s:_ready(a) -- an App made again gets everything after a pause
		expect(#t.sent[a]).to.equal(3)
		s:destroy()
	end)

	it("streams to one ready player or to every ready player", function()
		local streamed = {}
		local t = fakeTransport()
		function t.stream(who: any, name: string, ...)
			table.insert(streamed, { who or "all", name, ... })
		end
		local s = Server.new({ transport = t, players = false, autoFlush = false })
		local a, b = player(1), player(2)
		s:_join(a)
		s:_join(b)
		s:_ready(a)
		s:stream(b, "hit") -- not ready: dropped
		s:stream(a, "hit", 3)
		s:stream(nil, "shot")
		expect(#streamed).to.equal(2)
		expect(streamed[1][1]).to.equal(a)
		expect(streamed[1][3]).to.equal(3)
		expect(streamed[2][1]).to.equal("all")
		s:destroy()
	end)

	it("compares shared state once for every player, and still catches up a late one", function()
		local a, b, c = player(1), player(2), player(3)
		for _, p in { a, b } do
			server:_join(p)
			server:_ready(p)
		end
		server.state:set("shared.round", 1)
		server:flush()
		-- one list of ops, sent to both
		local last = transport.sent[a][#transport.sent[a]]
		expect(last.shared[1][1]).to.equal("round")
		expect(mirror(transport, b).shared.round).to.equal(1)

		server:_join(c)
		server:_ready(c)
		server.state:set("shared.round", 2)
		server.state:set("shared.phase", "Live")
		server:flush()
		for _, p in { a, b, c } do
			local seen = mirror(transport, p).shared
			expect(seen.round).to.equal(2)
			expect(seen.phase).to.equal("Live")
		end
	end)
end
