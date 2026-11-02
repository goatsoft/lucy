return function()
	local DataQueue = require(script.Parent.DataQueue)

	-- A DataStoreService that records every call, answers at once, and lets a spec set the
	-- budgets, make calls fail, or be offline (GetDataStore errors).
	local function fakeService(options: { offline: boolean?, budget: number? }?)
		local opts = options or {}
		local service = {
			calls = {} :: { { any } },
			budget = {} :: { [any]: number },
			defaultBudget = opts.budget or 100,
			failures = 0, -- the next this many write calls error
			data = {} :: { [string]: { [string]: any } },
		}
		local function record(...)
			table.insert(service.calls, table.pack(...))
		end
		local function makeStore(name: string, ordered: boolean)
			service.data[name] = service.data[name] or {}
			-- Looked up on every call, so a spec can seed data after opening the store
			local data = setmetatable({}, {
				__index = function(_, key)
					return service.data[name][key]
				end,
				__newindex = function(_, key, value)
					service.data[name][key] = value
				end,
				__iter = function()
					return next, service.data[name]
				end,
			})
			local store = {}
			function store:SetAsync(key: string, value: any)
				record("SetAsync", name, key, value)
				if service.failures > 0 then
					service.failures -= 1
					error("fake write failed")
				end
				data[key] = value
			end
			function store:UpdateAsync(key: string, fn: (any) -> any)
				record("UpdateAsync", name, key)
				if service.failures > 0 then
					service.failures -= 1
					error("fake write failed")
				end
				data[key] = fn(data[key])
				return data[key]
			end
			function store:RemoveAsync(key: string)
				record("RemoveAsync", name, key)
				data[key] = nil
			end
			function store:GetAsync(key: string)
				record("GetAsync", name, key)
				return data[key]
			end
			if ordered then
				function store:GetSortedAsync(ascending: boolean, pageSize: number)
					record("GetSortedAsync", name, ascending, pageSize)
					local list = {}
					for key, value in data do
						table.insert(list, { key = key, value = value })
					end
					table.sort(list, function(a, b)
						if ascending then
							return a.value < b.value
						end
						return a.value > b.value
					end)
					local page = {}
					for i = 1, math.min(pageSize, #list) do
						page[i] = list[i]
					end
					return {
						GetCurrentPage = function()
							return page
						end,
					}
				end
			end
			return store
		end
		function service:GetDataStore(name: string)
			if opts.offline then
				error("DataStores are off")
			end
			return makeStore(name, false)
		end
		function service:GetOrderedDataStore(name: string)
			if opts.offline then
				error("DataStores are off")
			end
			return makeStore(name, true)
		end
		function service:GetRequestBudgetForRequestType(kind: any): number
			local value = service.budget[kind]
			return if value == nil then service.defaultBudget else value
		end
		function service.count(method: string): number
			local n = 0
			for _, call in service.calls do
				if call[1] == method then
					n += 1
				end
			end
			return n
		end
		return service
	end

	local service, now, queue
	local function make(options: { [string]: any }?)
		local opts = options or {}
		service = opts.service or fakeService()
		now = 0
		queue = DataQueue.new({
			service = service,
			clock = function()
				return now
			end,
			spawn = function(fn: (...any) -> (), ...: any)
				fn(...)
			end,
			wait = function()
				now += 0.1
				queue:step()
			end,
			autoRun = false,
			bindToClose = false,
			warn = function() end,
		})
	end

	afterEach(function()
		if queue then
			queue:destroy()
		end
	end)

	describe("writes", function()
		it("sends the latest of several sets to one key, once", function()
			make()
			local scores = queue:store("Scores")
			scores:set("u1", 1)
			scores:set("u1", 2)
			scores:set("u1", 3)
			queue:step()
			expect(service.count("SetAsync")).to.equal(1)
			expect(service.data.Scores.u1).to.equal(3)
		end)

		it("leaves a key alone for keyGap seconds after a write", function()
			make()
			local scores = queue:store("Scores")
			scores:set("u1", 1)
			queue:step()
			scores:set("u1", 2)
			now += 3
			queue:step()
			expect(service.count("SetAsync")).to.equal(1)
			now += 3.5
			queue:step()
			expect(service.count("SetAsync")).to.equal(2)
			expect(service.data.Scores.u1).to.equal(2)
		end)

		it("does not let a waiting key hold up the others", function()
			make()
			local scores = queue:store("Scores")
			scores:set("u1", 1)
			queue:step()
			scores:set("u1", 2)
			scores:set("u2", 5)
			queue:step()
			expect(service.data.Scores.u2).to.equal(5)
			expect(service.data.Scores.u1).to.equal(1)
		end)

		it("sends no more in a step than the engine's budget allows", function()
			make()
			service.budget[Enum.DataStoreRequestType.SetIncrementAsync] = 1
			local scores = queue:store("Scores")
			scores:set("a", 1)
			scores:set("b", 2)
			scores:set("c", 3)
			queue:step()
			expect(service.count("SetAsync")).to.equal(1)
			queue:step()
			queue:step()
			expect(service.count("SetAsync")).to.equal(3)
		end)

		it("composes updates onto one UpdateAsync", function()
			make()
			local wins = queue:store("Wins")
			service.data.Wins = { u1 = 5 }
			wins:update("u1", function(old)
				return (old or 0) + 1
			end)
			wins:update("u1", function(old)
				return (old or 0) + 1
			end)
			queue:step()
			expect(service.count("UpdateAsync")).to.equal(1)
			expect(service.data.Wins.u1).to.equal(7)
		end)

		it("applies an update to a pending set without reading", function()
			make()
			local wins = queue:store("Wins")
			wins:set("u1", 10)
			wins:update("u1", function(old)
				return old * 2
			end)
			queue:step()
			expect(service.count("UpdateAsync")).to.equal(0)
			expect(service.data.Wins.u1).to.equal(20)
		end)

		it("retries a failed write with backoff, then gives up", function()
			make()
			local errors = {}
			queue.onError = function(info)
				table.insert(errors, info)
			end
			service.failures = 10
			local scores = queue:store("Scores")
			scores:set("u1", 1)
			queue:step()
			expect(service.count("SetAsync")).to.equal(1)
			queue:step() -- too soon to retry
			expect(service.count("SetAsync")).to.equal(1)
			now += 1
			queue:step()
			expect(service.count("SetAsync")).to.equal(2)
			now += 10
			queue:step()
			now += 10
			queue:step()
			now += 10
			queue:step()
			expect(service.count("SetAsync")).to.equal(3)
			expect(#errors).to.equal(1)
			expect(queue:pending()).to.equal(0)
		end)

		it("removes a key", function()
			make()
			service.data.Scores = { u1 = 4 }
			local scores = queue:store("Scores")
			scores:remove("u1")
			queue:step()
			expect(service.count("RemoveAsync")).to.equal(1)
			expect(service.data.Scores.u1).to.equal(nil)
		end)
	end)

	describe("reads", function()
		it("answers from a pending write without reading", function()
			make()
			local scores = queue:store("Scores")
			scores:set("u1", 9)
			expect(scores:get("u1")).to.equal(9)
			expect(service.count("GetAsync")).to.equal(0)
		end)

		it("keeps what it read for ttl seconds", function()
			make()
			service.data.Scores = { u1 = 3 }
			local scores = queue:store("Scores")
			expect(scores:get("u1")).to.equal(3)
			expect(scores:get("u1")).to.equal(3)
			expect(service.count("GetAsync")).to.equal(1)
			now += 61
			scores:get("u1")
			expect(service.count("GetAsync")).to.equal(2)
		end)

		it("reads again when asked for a fresh value", function()
			make()
			service.data.Scores = { u1 = 3 }
			local scores = queue:store("Scores")
			scores:get("u1")
			scores:get("u1", { fresh = true })
			expect(service.count("GetAsync")).to.equal(2)
		end)

		it("remembers what it wrote once the write lands", function()
			make()
			local scores = queue:store("Scores")
			scores:set("u1", 4)
			queue:step()
			expect(scores:get("u1")).to.equal(4)
			expect(service.count("GetAsync")).to.equal(0)
		end)
	end)

	describe("sorted pages", function()
		it("reads the top of an ordered store once per ttl", function()
			make()
			service.data.Hype = { a = 10, b = 30, c = 20 }
			local hype = queue:ordered("Hype")
			local top = hype:top(2)
			expect(#top).to.equal(2)
			expect(top[1].key).to.equal("b")
			expect(top[2].key).to.equal("c")
			hype:top(2)
			expect(service.count("GetSortedAsync")).to.equal(1)
		end)

		it("merges pending writes into the page at once", function()
			make()
			service.data.Hype = { a = 10, b = 30 }
			local hype = queue:ordered("Hype")
			hype:top(3)
			hype:set("a", 50)
			local top = hype:top(3)
			expect(top[1].key).to.equal("a")
			expect(top[1].value).to.equal(50)
			expect(service.count("GetSortedAsync")).to.equal(1)
		end)

		it("answers from a stale page and refreshes it in the background", function()
			make()
			service.data.Hype = { a = 10 }
			local hype = queue:ordered("Hype")
			hype:top(5)
			service.data.Hype.b = 99
			now += 61
			local stale = hype:top(5)
			expect(service.count("GetSortedAsync")).to.equal(2)
			-- the refresh ran inline here (spawn is inline), so the next answer has b
			local fresh = hype:top(5)
			expect(#stale >= 1).to.equal(true)
			expect(fresh[1].key).to.equal("b")
		end)
	end)

	describe("flushing", function()
		it("writes everything pending and says so", function()
			make()
			local scores = queue:store("Scores")
			scores:set("a", 1)
			scores:set("b", 2)
			expect(queue:pending()).to.equal(2)
			expect(queue:flush(5)).to.equal(true)
			expect(queue:pending()).to.equal(0)
			expect(service.data.Scores.a).to.equal(1)
		end)

		it("stops waiting at the timeout", function()
			make()
			service.budget[Enum.DataStoreRequestType.SetIncrementAsync] = 0
			local scores = queue:store("Scores")
			scores:set("a", 1)
			expect(queue:flush(1)).to.equal(false)
			expect(queue:pending()).to.equal(1)
		end)
	end)

	describe("offline", function()
		it("keeps everything in memory when DataStores cannot be reached", function()
			make({ service = fakeService({ offline = true }) })
			expect(queue.offline).to.equal(true)
			local scores = queue:store("Scores")
			scores:set("u1", 7)
			queue:step()
			expect(scores:get("u1")).to.equal(7)
			local hype = queue:ordered("Hype")
			hype:set("a", 1)
			hype:set("b", 3)
			local top = hype:top(2)
			expect(top[1].key).to.equal("b")
			expect(queue:pending()).to.equal(0)
		end)
	end)
end
