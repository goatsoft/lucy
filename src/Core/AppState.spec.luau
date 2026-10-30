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
end
