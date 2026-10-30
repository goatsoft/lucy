return function()
	local Reactive = require(script.Parent.Reactive)
	local ref, computed, reactive = Reactive.ref, Reactive.computed, Reactive.reactive
	local watch, watchEffect = Reactive.watch, Reactive.watchEffect

	describe("ref", function()
		it("reads with a call and writes with an argument", function()
			local count = ref(1)
			expect(count()).to.equal(1)
			count(5)
			expect(count()).to.equal(5)
		end)

		it("can be set to nil explicitly", function()
			local value = ref("x")
			value(nil)
			expect(value()).to.equal(nil)
		end)

		it("is recognised by isRef, plain functions are not", function()
			expect(Reactive.isRef(ref(0))).to.equal(true)
			expect(Reactive.isRef(computed(function()
				return 1
			end))).to.equal(true)
			expect(Reactive.isRef(function() end)).to.equal(false)
			expect(Reactive.isRef(1)).to.equal(false)
		end)

		it("does not notify when the value is unchanged", function()
			local count = ref(1)
			local runs = 0
			watchEffect(function()
				count()
				runs += 1
			end)
			count(1)
			expect(runs).to.equal(1)
			count(2)
			expect(runs).to.equal(2)
		end)

		it("trigger notifies after an in-place mutation", function()
			local list = ref({ 1 })
			local seen = 0
			watchEffect(function()
				seen = #list()
			end)
			table.insert(list(), 2)
			expect(seen).to.equal(1)
			Reactive.trigger(list)
			expect(seen).to.equal(2)
		end)
	end)

	describe("computed", function()
		it("derives a value and caches it until a source changes", function()
			local count = ref(2)
			local runs = 0
			local double = computed(function()
				runs += 1
				return count() * 2
			end)
			expect(double()).to.equal(4)
			expect(double()).to.equal(4)
			expect(runs).to.equal(1)
			count(3)
			expect(double()).to.equal(6)
			expect(runs).to.equal(2)
		end)

		it("is lazy: nothing runs until it is read", function()
			local runs = 0
			local value = computed(function()
				runs += 1
				return 1
			end)
			expect(runs).to.equal(0)
			value()
			expect(runs).to.equal(1)
		end)

		it("is read-only unless given get and set", function()
			local value = computed(function()
				return 1
			end)
			expect(function()
				value(2)
			end).to.throw()
		end)

		it("supports writable computeds", function()
			local first, last = ref("Lucy"), ref("Lua")
			local full = computed({
				get = function()
					return `{first()} {last()}`
				end,
				set = function(value: string)
					local a, b = string.match(value, "^(%S+) (%S+)$")
					first(a)
					last(b)
				end,
			})
			expect(full()).to.equal("Lucy Lua")
			full("Goat Soft")
			expect(first()).to.equal("Goat")
			expect(full()).to.equal("Goat Soft")
		end)

		it("passes the previous value to the getter", function()
			local count = ref(1)
			local history = computed(function(previous)
				return (previous or 0) + count()
			end)
			expect(history()).to.equal(1)
			count(2)
			expect(history()).to.equal(3)
		end)

		it("is glitch-free: a diamond runs its effect once with consistent values", function()
			local a = ref(1)
			local b = computed(function()
				return a() + 1
			end)
			local c = computed(function()
				return a() * 10
			end)
			local seen = {}
			watchEffect(function()
				table.insert(seen, `{b()}:{c()}`)
			end)
			a(2)
			expect(#seen).to.equal(2)
			expect(seen[2]).to.equal("3:20")
		end)

		it("stops propagation when a computed's value does not change", function()
			local count = ref(1)
			local isPositive = computed(function()
				return count() > 0
			end)
			local runs = 0
			watchEffect(function()
				isPositive()
				runs += 1
			end)
			count(2)
			count(3)
			expect(runs).to.equal(1)
			count(-1)
			expect(runs).to.equal(2)
		end)

		it("rethrows getter errors and recovers once the source is fixed", function()
			local value = ref(0)
			local inverse = computed(function()
				assert(value() ~= 0, "zero")
				return 1 / value()
			end)
			local seen
			watchEffect(function()
				local ok, result = pcall(inverse)
				seen = if ok then result else "error"
			end)
			expect(seen).to.equal("error")
			value(2)
			expect(seen).to.equal(0.5)
		end)
	end)

	describe("watchEffect", function()
		it("runs immediately and again when what it read changes", function()
			local name = ref("a")
			local seen = {}
			watchEffect(function()
				table.insert(seen, name())
			end)
			name("b")
			expect(table.concat(seen, ",")).to.equal("a,b")
		end)

		it("re-tracks dependencies on every run", function()
			local useA = ref(true)
			local a, b = ref(1), ref(2)
			local runs = 0
			watchEffect(function()
				runs += 1
				if useA() then
					a()
				else
					b()
				end
			end)
			useA(false)
			a(10) -- no longer a dependency
			expect(runs).to.equal(2)
			b(20)
			expect(runs).to.equal(3)
		end)

		it("calls onCleanup before re-running and when stopped", function()
			local count = ref(0)
			local cleaned = 0
			local stop = watchEffect(function(onCleanup)
				count()
				onCleanup(function()
					cleaned += 1
				end)
			end)
			count(1)
			expect(cleaned).to.equal(1)
			stop()
			expect(cleaned).to.equal(2)
			count(2)
			expect(cleaned).to.equal(2)
		end)

		it("disposes effects created inside it when it re-runs", function()
			local outer, inner = ref(0), ref(0)
			local innerRuns = 0
			watchEffect(function()
				outer()
				watchEffect(function()
					inner()
					innerRuns += 1
				end)
			end)
			outer(1) -- old inner effect disposed, a new one created
			innerRuns = 0
			inner(1)
			expect(innerRuns).to.equal(1)
		end)

		it("does not re-trigger itself when it writes what it reads", function()
			local count = ref(0)
			watchEffect(function()
				count(count() + 1)
			end)
			expect(count()).to.equal(1)
		end)

		it("errors instead of hanging when effects trigger each other forever", function()
			local a, b = ref(0), ref(0)
			watchEffect(function()
				b(a() + 1)
			end)
			watchEffect(function()
				a(b() + 1)
			end)
			expect(a() > 50).to.equal(true)
		end)
	end)

	describe("batch, untrack, peek", function()
		it("batch runs dependent effects once, after the batch", function()
			local a, b = ref(1), ref(2)
			local runs = 0
			watchEffect(function()
				a()
				b()
				runs += 1
			end)
			Reactive.batch(function()
				a(10)
				b(20)
				expect(runs).to.equal(1)
			end)
			expect(runs).to.equal(2)
		end)

		it("untrack and peek read without subscribing", function()
			local a, b = ref(1), ref(1)
			local runs = 0
			watchEffect(function()
				a()
				Reactive.untrack(function()
					return b()
				end)
				Reactive.peek(b)
				runs += 1
			end)
			b(2)
			expect(runs).to.equal(1)
			a(2)
			expect(runs).to.equal(2)
		end)

		it("toValue unwraps refs and getters and passes plain values through", function()
			expect(Reactive.toValue(ref(3))).to.equal(3)
			expect(Reactive.toValue(function()
				return 4
			end)).to.equal(4)
			expect(Reactive.toValue(5)).to.equal(5)
		end)
	end)

	describe("reactive", function()
		it("tracks reads and writes per key", function()
			local player = reactive({ coins = 0, name = "JB" })
			local coinRuns, nameRuns = 0, 0
			watchEffect(function()
				local _ = player.coins
				coinRuns += 1
			end)
			watchEffect(function()
				local _ = player.name
				nameRuns += 1
			end)
			player.coins += 5
			expect(player.coins).to.equal(5)
			expect(coinRuns).to.equal(2)
			expect(nameRuns).to.equal(1)
		end)

		it("is deep: nested tables are reactive too", function()
			local state = reactive({ settings = { volume = 1 } })
			local seen
			watchEffect(function()
				seen = state.settings.volume
			end)
			state.settings.volume = 0.5
			expect(seen).to.equal(0.5)
			expect(Reactive.isReactive(state.settings)).to.equal(true)
		end)

		it("returns the same proxy for the same table", function()
			local raw = { a = 1 }
			expect(reactive(raw)).to.equal(reactive(raw))
			expect(reactive(reactive(raw))).to.equal(reactive(raw))
			expect(Reactive.toRaw(reactive(raw))).to.equal(raw)
		end)

		it("notifies length and iteration when keys are added or removed", function()
			local list = reactive({ "a" })
			local length, joined = 0, ""
			watchEffect(function()
				length = #list
			end)
			watchEffect(function()
				local parts = {}
				for _, value in list do
					table.insert(parts, value)
				end
				joined = table.concat(parts, ",")
			end)
			list[2] = "b"
			expect(length).to.equal(2)
			expect(joined).to.equal("a,b")
		end)

		it("insert and remove keep lists reactive", function()
			local list = reactive({ "a", "c" })
			local joined = ""
			watchEffect(function()
				local parts = {}
				for i = 1, #list do
					table.insert(parts, list[i])
				end
				joined = table.concat(parts, ",")
			end)
			Reactive.insert(list, 2, "b")
			expect(joined).to.equal("a,b,c")
			Reactive.insert(list, "d")
			expect(joined).to.equal("a,b,c,d")
			expect(Reactive.remove(list, 1)).to.equal("a")
			expect(joined).to.equal("b,c,d")
		end)

		it("leaves frozen tables alone", function()
			local frozen = table.freeze({ a = 1 })
			expect(reactive(frozen)).to.equal(frozen)
		end)
	end)

	describe("watch", function()
		it("calls back with new and old values, lazily by default", function()
			local count = ref(1)
			local calls = {}
			watch(count, function(new, old)
				table.insert(calls, `{old}->{new}`)
			end)
			expect(#calls).to.equal(0)
			count(2)
			expect(calls[1]).to.equal("1->2")
		end)

		it("runs at once with immediate", function()
			local count = ref(1)
			local first
			watch(count, function(new)
				first = first or new
			end, { immediate = true })
			expect(first).to.equal(1)
		end)

		it("watches getters and arrays of sources", function()
			local a, b = ref(1), ref(2)
			local sum, pair
			watch(function()
				return a() + b()
			end, function(new)
				sum = new
			end)
			watch({ a, b }, function(new)
				pair = `{new[1]},{new[2]}`
			end)
			a(5)
			expect(sum).to.equal(7)
			expect(pair).to.equal("5,2")
		end)

		it("is deep for reactive tables", function()
			local state = reactive({ inventory = { swords = 1 } })
			local calls = 0
			watch(state, function()
				calls += 1
			end)
			state.inventory.swords = 2
			expect(calls).to.equal(1)
		end)

		it("runs onCleanup before the next callback, and stops", function()
			local count = ref(0)
			local log = {}
			local stop = watch(count, function(new, _, onCleanup)
				table.insert(log, "run" .. new)
				onCleanup(function()
					table.insert(log, "clean" .. new)
				end)
			end)
			count(1)
			count(2)
			stop()
			count(3)
			expect(table.concat(log, ",")).to.equal("run1,clean1,run2,clean2")
		end)
	end)

	describe("effectScope", function()
		it("stops every effect created in it", function()
			local count = ref(0)
			local runs = 0
			local scope = Reactive.effectScope()
			scope:run(function()
				watchEffect(function()
					count()
					runs += 1
				end)
			end)
			expect(scope.active).to.equal(true)
			scope:stop()
			expect(scope.active).to.equal(false)
			count(1)
			expect(runs).to.equal(1)
		end)

		it("runs onCleanup callbacks registered in it", function()
			local cleaned = false
			local scope = Reactive.effectScope()
			scope:run(function()
				Reactive.onCleanup(function()
					cleaned = true
				end)
			end)
			scope:stop()
			expect(cleaned).to.equal(true)
		end)

		it("stops nested scopes with their parent", function()
			local count = ref(0)
			local runs = 0
			local outer = Reactive.effectScope()
			outer:run(function()
				Reactive.effectScope():run(function()
					watchEffect(function()
						count()
						runs += 1
					end)
				end)
			end)
			outer:stop()
			count(1)
			expect(runs).to.equal(1)
		end)
	end)
end
