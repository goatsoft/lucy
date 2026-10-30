return function()
	local AppState = require(script.Parent.AppState)

	describe("get/set", function()
		it("reads initial values by dot path", function()
			local state = AppState.new({ ui = { play = { disabled = true } } })
			expect(state:get("ui.play.disabled")).to.equal(true)
			expect(state:get("ui.missing.deep")).to.equal(nil)
		end)

		it("returns the whole tree with no path", function()
			local state = AppState.new({ a = 1 })
			expect(state:get().a).to.equal(1)
		end)

		it("creates intermediate tables on set", function()
			local state = AppState.new()
			state:set("ui.dialog.open", true)
			expect(state:get("ui.dialog.open")).to.equal(true)
		end)

		it("is copy-on-write so earlier snapshots are not mutated", function()
			local state = AppState.new({ ui = { a = 1 } })
			local before = state:get("ui")
			state:set("ui.a", 2)
			expect(before.a).to.equal(1)
			expect(state:get("ui.a")).to.equal(2)
		end)

		it("rejects empty path segments", function()
			local state = AppState.new()
			expect(function()
				state:set("ui..x", 1)
			end).to.throw()
		end)
	end)

	describe("merge/update", function()
		it("shallow merges a patch into a table at the path", function()
			local state = AppState.new({ ui = { b = { text = "Hi", variant = "default" } } })
			state:merge("ui.b", { variant = "destructive" })
			expect(state:get("ui.b.text")).to.equal("Hi")
			expect(state:get("ui.b.variant")).to.equal("destructive")
		end)

		it("updates with a function of the old value", function()
			local state = AppState.new({ count = 1 })
			state:update("count", function(n)
				return n + 1
			end)
			expect(state:get("count")).to.equal(2)
		end)
	end)

	describe("subscribe", function()
		it("notifies exact path subscribers with new and old values", function()
			local state = AppState.new({ count = 1 })
			local got = {}
			state:subscribe("count", function(new, old)
				table.insert(got, { new, old })
			end)
			state:set("count", 5)
			expect(#got).to.equal(1)
			expect(got[1][1]).to.equal(5)
			expect(got[1][2]).to.equal(1)
		end)

		it("notifies ancestors and descendants of the changed path", function()
			local state = AppState.new({ ui = { play = { disabled = false } } })
			local parent, child = 0, 0
			state:subscribe("ui", function()
				parent += 1
			end)
			state:subscribe("ui.play.disabled", function()
				child += 1
			end)
			state:set("ui.play", { disabled = true })
			expect(parent).to.equal(1)
			expect(child).to.equal(1)
		end)

		it("does not notify unrelated paths or unchanged values", function()
			local state = AppState.new({ a = 1, b = 1 })
			local calls = 0
			state:subscribe("b", function()
				calls += 1
			end)
			state:set("a", 2)
			state:set("b", 1)
			expect(calls).to.equal(0)
		end)

		it("stops notifying after unsubscribe", function()
			local state = AppState.new({ a = 1 })
			local calls = 0
			local unsubscribe = state:subscribe("a", function()
				calls += 1
			end)
			unsubscribe()
			state:set("a", 2)
			expect(calls).to.equal(0)
		end)

		it("keeps notifying other subscribers when one errors", function()
			local state = AppState.new({ a = 1 })
			local calls = 0
			state:subscribe("a", function()
				error("boom")
			end)
			state:subscribe("a", function()
				calls += 1
			end)
			state:set("a", 2)
			expect(calls).to.equal(1)
		end)

		it("handles subscribing and unsubscribing while notifying", function()
			local state = AppState.new({ a = 1 })
			local log = {}
			local stopLater
			state:subscribe("a", function(new)
				table.insert(log, `first {new}`)
				if new == 2 then
					stopLater() -- a later subscriber, removed mid-notify: skipped
					state:subscribe("a", function(v) -- added mid-notify: waits for the next change
						table.insert(log, `added {v}`)
					end)
				end
			end)
			stopLater = state:subscribe("a", function(new)
				table.insert(log, `later {new}`)
			end)
			state:subscribe("a", function(new)
				table.insert(log, `last {new}`)
			end)
			state:set("a", 2)
			state:set("a", 3)
			expect(table.concat(log, ",")).to.equal("first 2,last 2,first 3,last 3,added 3")
		end)
	end)

	describe("batch", function()
		it("coalesces notifications to one per subscriber with the final value", function()
			local state = AppState.new({ a = 1 })
			local seen = {}
			state:subscribe("a", function(new, old)
				table.insert(seen, { new, old })
			end)
			state:batch(function()
				state:set("a", 2)
				state:set("a", 3)
			end)
			expect(#seen).to.equal(1)
			expect(seen[1][1]).to.equal(3)
			expect(seen[1][2]).to.equal(1)
		end)

		it("skips subscribers whose value ended where it started", function()
			local state = AppState.new({ a = 1 })
			local calls = 0
			state:subscribe("a", function()
				calls += 1
			end)
			state:batch(function()
				state:set("a", 2)
				state:set("a", 1)
			end)
			expect(calls).to.equal(0)
		end)
	end)

	describe("scope", function()
		it("prefixes all paths", function()
			local state = AppState.new()
			local ui = state:scope("ui.play")
			ui:set("disabled", true)
			expect(state:get("ui.play.disabled")).to.equal(true)
			expect(ui:get("disabled")).to.equal(true)
		end)

		it("subscribes relative to the scope", function()
			local state = AppState.new()
			local ui = state:scope("ui")
			local value
			ui:subscribe("x", function(new)
				value = new
			end)
			state:set("ui.x", 9)
			expect(value).to.equal(9)
		end)
	end)

	describe("ref", function()
		it("reads and writes a path as a ref and follows outside writes", function()
			local Reactive = require(script.Parent.Reactive)
			local state = AppState.new({ player = { coins = 1 } })
			local scope = Reactive.effectScope(true)
			local coins, seen
			scope:run(function()
				coins = state:ref("player.coins")
				Reactive.watchEffect(function()
					seen = coins()
				end)
			end)
			coins(coins() + 4)
			expect(state:get("player.coins")).to.equal(5)
			expect(seen).to.equal(5)
			state:set("player.coins", 9)
			expect(seen).to.equal(9)
			scope:stop()
			state:set("player.coins", 11)
			expect(seen).to.equal(9)
		end)
	end)

	describe("remove", function()
		it("removes a key and notifies", function()
			local state = AppState.new({ ui = { a = { open = true } } })
			local value = "unset"
			state:subscribe("ui.a", function(new)
				value = new
			end)
			state:remove("ui.a")
			expect(state:get("ui.a")).to.equal(nil)
			expect(value).to.equal(nil)
		end)
	end)

	-- ADR 0017: a living tree with frozen, lazily built snapshots.
	describe("snapshots", function()
		it("returns frozen tables that throw when mutated", function()
			local state = AppState.new({ ui = { a = { open = true } } })
			local snap = state:get("ui.a")
			expect(table.isfrozen(snap)).to.equal(true)
			expect(table.isfrozen(state:get())).to.equal(true)
			expect(function()
				snap.open = false
			end).to.throw()
			expect(state:get("ui.a.open")).to.equal(true)
		end)

		it("returns the same snapshot until something under it changes", function()
			local state = AppState.new({ ui = { a = { x = 1 }, b = { y = 1 } } })
			local ui, a, b = state:get("ui"), state:get("ui.a"), state:get("ui.b")
			expect(state:get("ui")).to.equal(ui)
			state:set("ui.a.x", 2)
			expect(state:get("ui")).never.to.equal(ui)
			expect(state:get("ui.a")).never.to.equal(a)
			expect(state:get("ui.b")).to.equal(b)
			expect(state:get("ui").b).to.equal(b)
		end)

		it("does not keep the caller's table, and accepts snapshots back", function()
			local state = AppState.new()
			local mine = { list = { 1, 2 } }
			state:set("a", mine)
			mine.list[1] = 99
			expect(state:get("a.list.1")).to.equal(1)
			state:set("b", state:get("a"))
			state:set("a.list.1", 5)
			expect(state:get("b.list.1")).to.equal(1)
			local copy = table.clone(state:get("a.list"))
			table.insert(copy, 3)
			state:set("a.list", copy)
			expect(#state:get("a.list")).to.equal(3)
		end)
	end)

	describe("reconcile", function()
		it("notifies nobody when an equal table is set", function()
			local state = AppState.new({ scenes = { stack = { "Pause" }, current = "Game" } })
			local calls = 0
			local function count()
				calls += 1
			end
			state:subscribe("scenes", count)
			state:subscribe("scenes.stack", count)
			state:subscribe("scenes.stack.1", count)
			local before = state:get("scenes")
			state:set("scenes.stack", { "Pause" })
			state:set("scenes", { stack = { "Pause" }, current = "Game" })
			expect(calls).to.equal(0)
			expect(state:get("scenes")).to.equal(before)
		end)

		it("notifies only the keys that changed, by key and by index", function()
			local state =
				AppState.new({ input = { device = "desktop", touch = false }, list = { "a", "b", "c" } })
			local log = {}
			for _, path in { "input.device", "input.touch", "list.1", "list.2", "list.3" } do
				state:subscribe(path, function(new, old)
					table.insert(log, `{path}:{old}>{new}`)
				end)
			end
			state:set("input", { device = "desktop", touch = true })
			state:set("list", { "a", "c" })
			expect(table.concat(log, ",")).to.equal("input.touch:false>true,list.2:b>c,list.3:c>nil")
		end)

		it("removes keys missing from the new table", function()
			local state = AppState.new({ a = { x = 1, y = 2 } })
			state:set("a", { x = 1 })
			expect(state:get("a.y")).to.equal(nil)
			expect(state:get("a.x")).to.equal(1)
		end)
	end)

	describe("node subscriptions", function()
		it("subscribes to a path that does not exist yet", function()
			local state = AppState.new()
			local seen
			state:subscribe("player.stats.hp", function(new)
				seen = new
			end)
			state:set("player", { stats = { hp = 10 } })
			expect(seen).to.equal(10)
		end)

		it("gives table subscribers the old and new snapshots", function()
			local state = AppState.new({ ui = { a = { open = false } } })
			local got
			state:subscribe("ui.a", function(new, old)
				got = { new = new, old = old }
			end)
			state:set("ui.a.open", true)
			expect(got.old.open).to.equal(false)
			expect(got.new.open).to.equal(true)
		end)

		it("notifies in subscription order across paths", function()
			local state = AppState.new({ a = { b = 1 } })
			local log = {}
			state:subscribe("a.b", function()
				table.insert(log, "leaf")
			end)
			state:subscribe("a", function()
				table.insert(log, "parent")
			end)
			state:subscribe("", function()
				table.insert(log, "root")
			end)
			state:set("a.b", 2)
			expect(table.concat(log, ",")).to.equal("leaf,parent,root")
		end)

		it("delivers a write made inside a subscriber after the current round", function()
			local state = AppState.new({ a = 1, b = 1 })
			local log = {}
			state:subscribe("a", function(new)
				table.insert(log, `a{new}`)
				state:set("b", new * 10)
			end)
			state:subscribe("b", function(new)
				table.insert(log, `b{new}`)
			end)
			state:set("a", 2)
			expect(table.concat(log, ",")).to.equal("a2,b20")
		end)

		it("does not call subscribers of unrelated siblings", function()
			local state = AppState.new({ ui = { a = { v = 1 }, b = { v = 1 } } })
			local calls = 0
			state:subscribe("ui.b", function()
				calls += 1
			end)
			state:subscribe("ui.b.v", function()
				calls += 1
			end)
			state:set("ui.a.v", 2)
			state:merge("ui.a", { w = 3 })
			expect(calls).to.equal(0)
		end)
	end)

	describe("reactive integration", function()
		local Reactive = require(script.Parent.Reactive)

		it("coalesces store notifications inside Lucy.batch", function()
			local state = AppState.new({ a = 1 })
			local seen = {}
			state:subscribe("a", function(new, old)
				table.insert(seen, `{old}>{new}`)
			end)
			Reactive.batch(function()
				state:set("a", 2)
				state:set("a", 3)
				expect(#seen).to.equal(0)
			end)
			expect(table.concat(seen, ",")).to.equal("1>3")
		end)

		it("keeps a ref live when its parent table is removed and recreated", function()
			local state = AppState.new({ player = { coins = 1 } })
			local scope = Reactive.effectScope(true)
			local seen
			scope:run(function()
				local coins = state:ref("player.coins")
				Reactive.watchEffect(function()
					seen = coins()
				end)
			end)
			state:remove("player")
			expect(seen).to.equal(nil)
			state:set("player.coins", 7)
			expect(seen).to.equal(7)
			scope:stop()
		end)

		it("re-runs a deep reader when a table above it becomes a value and back", function()
			local state = AppState.new({ a = { b = { c = 1 } } })
			local scope = Reactive.effectScope(true)
			local seen, keyed, viewed = nil, nil, nil
			scope:run(function()
				local c = state:ref("a.b.c")
				local segments = state:_segments("a.b")
				local root = state.root
				Reactive.watchEffect(function()
					seen = c()
				end)
				Reactive.watchEffect(function()
					keyed = state:_trackedKey(segments, "c")
				end)
				Reactive.watchEffect(function()
					local a = root.a
					local b = if type(a) == "table" then a.b else nil
					viewed = if type(b) == "table" then b.c else nil
				end)
			end)
			state:set("a", 5)
			expect(seen).to.equal(nil)
			expect(keyed).to.equal(nil)
			expect(viewed).to.equal(nil)
			state:set("a", { b = { c = 2 } })
			expect(seen).to.equal(2)
			expect(keyed).to.equal(2)
			expect(viewed).to.equal(2)
			state:remove("a.b")
			expect(seen).to.equal(nil)
			expect(keyed).to.equal(nil)
			expect(viewed).to.equal(nil)
			state:set("a.b.c", 3)
			expect(seen).to.equal(3)
			expect(keyed).to.equal(3)
			expect(viewed).to.equal(3)
			state:set("a.b", { c = 4 }) -- same table, new value: only c changes
			expect(seen).to.equal(4)
			expect(keyed).to.equal(4)
			scope:stop()
		end)

		it("re-runs a reader of a whole table when a table above it is removed", function()
			local state = AppState.new({ a = { b = { c = 1 } } })
			local scope = Reactive.effectScope(true)
			local seen
			scope:run(function()
				local b = state:ref("a.b")
				Reactive.watchEffect(function()
					seen = b()
				end)
			end)
			expect(seen.c).to.equal(1)
			state:remove("a")
			expect(seen).to.equal(nil)
			state:set("a.b", { c = 2 })
			expect(seen.c).to.equal(2)
			scope:stop()
		end)

		it("links a reader to the key it reads, not to the tables above it", function()
			local state = AppState.new({ shallow = 1, a = { b = { c = { d = 1 } } } })
			local function cost(path: string?, key: string): number
				local segments = state:_segments(path)
				local function read()
					state:_trackedKey(segments, key)
				end
				local function bind()
					for _ = 1, 1000 do
						Reactive.watchEffect(read)
					end
				end
				local least = math.huge
				for _ = 1, 5 do
					local scope = Reactive.effectScope(true)
					local before = gcinfo()
					scope:run(bind)
					least = math.min(least, gcinfo() - before)
					scope:stop()
				end
				return least -- KB per 1,000 readers: bytes per reader
			end
			local shallow = cost(nil, "shallow")
			local deep = cost("a.b.c", "d")
			expect(deep - shallow < 24).to.equal(true)
		end)

		it("re-runs a ref onto a table when anything under it changes", function()
			local state = AppState.new({ input = { device = "desktop", viewport = { x = 1 } } })
			local scope = Reactive.effectScope(true)
			local runs, last = 0, nil
			scope:run(function()
				local input = state:ref("input")
				Reactive.watchEffect(function()
					runs += 1
					last = input()
				end)
			end)
			state:set("input.viewport.x", 2)
			expect(runs).to.equal(2)
			expect(last.viewport.x).to.equal(2)
			state:set("input", { device = "desktop", viewport = { x = 2 } })
			expect(runs).to.equal(2)
			scope:stop()
		end)
	end)

	describe("root", function()
		local Reactive = require(script.Parent.Reactive)

		it("reads and writes the tree like plain tables, through the store", function()
			local state = AppState.new({ player = { coins = 1 } })
			local seen = {}
			state:subscribe("player.coins", function(new, old)
				table.insert(seen, `{old}>{new}`)
			end)
			local root = state.root
			root.player.coins += 4
			expect(state:get("player.coins")).to.equal(5)
			expect(root.player.coins).to.equal(5)
			expect(table.concat(seen, ",")).to.equal("1>5")
			root.settings = { music = true }
			expect(state:get("settings.music")).to.equal(true)
			expect(root.missing).to.equal(nil)
		end)

		it("is tracked per key", function()
			local state = AppState.new({ player = { coins = 1, name = "A" } })
			local scope = Reactive.effectScope(true)
			local runs, last = 0, nil
			scope:run(function()
				Reactive.watchEffect(function()
					runs += 1
					local player = state.root.player
					last = player and player.coins
				end)
			end)
			state:set("player.name", "B")
			expect(runs).to.equal(1)
			state:set("player.coins", 3)
			expect(runs).to.equal(2)
			expect(last).to.equal(3)
			state:remove("player")
			expect(last).to.equal(nil)
			scope:stop()
		end)

		it("iterates and measures tables, tracking their contents", function()
			local state = AppState.new({ bag = { "sword", "shield" }, ui = { a = { open = true } } })
			local scope = Reactive.effectScope(true)
			local count, names = 0, ""
			scope:run(function()
				Reactive.watchEffect(function()
					count = #state.root.bag
					local list = {}
					for _, item in state.root.bag do
						table.insert(list, item)
					end
					names = table.concat(list, ",")
				end)
			end)
			state:set("bag", { "sword", "shield", "bow" })
			expect(count).to.equal(3)
			expect(names).to.equal("sword,shield,bow")
			for _, panel in state.root.ui do
				expect(panel.open).to.equal(true)
			end
			scope:stop()
		end)

		it("stores a copy when a part of the tree is assigned elsewhere", function()
			local state = AppState.new({ a = { x = 1 } })
			state.root.b = state.root.a
			state.root.a.x = 2
			expect(state:get("b.x")).to.equal(1)
			expect(state:get("a.x")).to.equal(2)
		end)
	end)
end
