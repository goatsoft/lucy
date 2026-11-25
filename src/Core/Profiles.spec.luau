return function()
	local DataQueue = require(script.Parent.DataQueue)
	local Profiles = require(script.Parent.Profiles)

	-- A DataStoreService with one shared table of stores, like Roblox's: two queues made
	-- with it are two servers. UpdateAsync leaves the key alone when the function says nil.
	local function fakeService()
		local service = { data = {} :: { [string]: { [string]: any } }, failures = 0 }
		function service:GetDataStore(name: string)
			service.data[name] = service.data[name] or {}
			local data = service.data[name]
			local store = {}
			function store:UpdateAsync(key: string, fn: (any) -> any)
				if service.failures > 0 then
					service.failures -= 1
					error("fake write failed")
				end
				local value = fn(data[key])
				if value ~= nil then
					data[key] = value
				end
				return data[key]
			end
			function store:SetAsync(key: string, value: any)
				data[key] = value
			end
			function store:GetAsync(key: string)
				return data[key]
			end
			function store:RemoveAsync(key: string)
				data[key] = nil
			end
			return store
		end
		function service:GetRequestBudgetForRequestType()
			return 100
		end
		return service
	end

	local now = 1000
	local function server(service: any, job: string, options: { [string]: any }?)
		local queue = DataQueue.new({
			service = service,
			inStudio = false,
			autoRun = false,
			bindToClose = false,
			keyGap = 0,
			retryDelay = 0,
			wait = function() end,
			warn = function() end,
		})
		local opts: { [string]: any } = {
			jobId = job,
			autoRun = false,
			bindToClose = false,
			tries = 2,
			wait = 0,
			time = function()
				return now
			end,
			sleep = function() end,
			template = { cash = 0, items = {} },
		}
		for key, value in (options or {}) :: { [string]: any } do
			opts[key] = value
		end
		return Profiles.new(queue, "Profiles", opts), queue
	end

	beforeEach(function()
		now = 1000
	end)

	it("makes a new player's data from the template and saves it held by this server", function()
		local service = fakeService()
		local profiles = server(service, "A")
		local profile = assert(profiles:load("u1"))
		expect(profile.data.cash).to.equal(0)
		profile.data.cash = 50
		profile:save()
		expect(profile:await(1)).to.equal(true)
		local record = service.data.Profiles.u1
		expect(record.data.cash).to.equal(50)
		expect(record.session.job).to.equal("A")
	end)

	it("will not load a profile another server holds, until it is let go", function()
		local service = fakeService()
		local a = server(service, "A")
		local b = server(service, "B")
		local held = assert(a:load("u1"))
		held.data.cash = 10
		local profile, why = b:load("u1")
		expect(profile).to.equal(nil)
		expect(why).to.equal("in use")

		held:release()
		expect(held:await(1)).to.equal(true)
		local moved = assert(b:load("u1"))
		expect(moved.data.cash).to.equal(10)
	end)

	it("takes over a claim left by a server that died", function()
		local service = fakeService()
		local a = server(service, "A", { stale = 100 })
		local b = server(service, "B", { stale = 100 })
		assert(a:load("u1"))
		now += 101
		expect(b:load("u1")).never.to.equal(nil)
	end)

	it("drops its copy, never writing it, when another server has taken the profile", function()
		local service = fakeService()
		local a = server(service, "A", { stale = 100 })
		local b = server(service, "B", { stale = 100 })
		local old = assert(a:load("u1"))
		local lost
		a.onLost = function(profile)
			lost = profile
		end
		now += 101
		local fresh = assert(b:load("u1"))
		fresh.data.cash = 5
		fresh:save()
		fresh:await(1)

		old.data.cash = 9999
		old:save()
		old:await(1)
		expect(old.lost).to.equal(true)
		expect(service.data.Profiles.u1.data.cash).to.equal(5)
		task.wait()
		expect(lost).to.equal(old)
	end)

	it("grants a purchase once however often the receipt comes", function()
		local service = fakeService()
		local profiles = server(service, "A")
		local profile = assert(profiles:load("u1"))
		local grants = 0
		for _ = 1, 3 do
			local ok = profiles:receipt(profile, "purchase-1", function(data)
				grants += 1
				data.cash += 1
			end)
			expect(ok).to.equal(true)
		end
		expect(grants).to.equal(1)
		expect(service.data.Profiles.u1.receipts[1]).to.equal("purchase-1")
	end)

	it("commits both sides of a trade and says so once both are saved", function()
		local service = fakeService()
		local profiles = server(service, "A")
		local a = assert(profiles:load("u1"))
		local b = assert(profiles:load("u2"))
		a.data.cash -= 0
		b.data.items = { "glock" }
		expect(Profiles.commit({ a, b }, 1)).to.equal(true)
		expect(service.data.Profiles.u2.data.items[1]).to.equal("glock")
		b:release()
		expect(Profiles.commit({ a, b }, 1)).to.equal(false)
	end)

	it("never writes over a profile another server took over and let go", function()
		local service = fakeService()
		local a = server(service, "A", { stale = 100 })
		local b = server(service, "B", { stale = 100 })
		local old = assert(a:load("u1"))
		now += 101
		local fresh = assert(b:load("u1"))
		fresh.data.cash = 5
		fresh:release()
		fresh:await(1)
		-- the record now has no claim at all: A's stale copy must still not be written
		old.data.cash = 9999
		old:save()
		expect(old:await(1)).to.equal(false)
		expect(old.lost).to.equal(true)
		expect(service.data.Profiles.u1.data.cash).to.equal(5)
	end)

	it("waits for its own release to land before loading the key again", function()
		local service = fakeService()
		local profiles = server(service, "A")
		local first = assert(profiles:load("u1"))
		first.data.cash = 7
		first:release()
		local again = assert(profiles:load("u1"))
		expect(again).never.to.equal(first)
		expect(again.data.cash).to.equal(7)
		-- the release did not clear the new claim
		expect(service.data.Profiles.u1.session.job).to.equal("A")
		again.data.cash = 8
		again:save()
		expect(again:await(1)).to.equal(true)
		expect(service.data.Profiles.u1.data.cash).to.equal(8)
	end)

	it("grants a purchase once even when grant yields and the receipt comes twice", function()
		local profiles = server(fakeService(), "A")
		local profile = assert(profiles:load("u1"))
		local grants = 0
		local function grant(data)
			grants += 1
			task.wait()
			data.cash += 1
		end
		local answers = {}
		task.spawn(function()
			table.insert(answers, profiles:receipt(profile, "purchase-2", grant))
		end)
		table.insert(answers, profiles:receipt(profile, "purchase-2", grant))
		while #answers < 2 do
			task.wait()
		end
		expect(grants).to.equal(1)
		expect(profile.data.cash).to.equal(1)
		expect(answers[1] and answers[2]).to.equal(true)
	end)

	it("saves nothing for a trade when any side cannot be saved", function()
		local service = fakeService()
		local profiles = server(service, "A")
		local a = assert(profiles:load("u1"))
		local b = assert(profiles:load("u2"))
		b:release()
		b:await(1)
		a.data.cash = 500
		expect(Profiles.commit({ a, b }, 1)).to.equal(false)
		profiles.queue:flush(1)
		-- the claim from load, but not the trade's cash
		expect(service.data.Profiles.u1.data).to.equal(nil)
	end)

	it("writes a release that gave up again before loading the key, instead of refusing for good", function()
		local service = fakeService()
		local profiles = server(service, "A")
		local first = assert(profiles:load("u1"))
		first.data.cash = 9
		service.failures = 100 -- DataStores down: every try of the release fails
		first:release()
		profiles.queue:flush(1)
		service.failures = 0 -- and back
		local again = assert(profiles:load("u1"))
		expect(again.data.cash).to.equal(9)
	end)

	it("lets go only once a purchase being granted is in the last save", function()
		local service = fakeService()
		local profiles = server(service, "A")
		local profile = assert(profiles:load("u1"))
		local answer
		task.spawn(function()
			answer = profiles:receipt(profile, "purchase-3", function(data)
				task.wait()
				task.wait()
				data.cash += 25
			end)
		end)
		profile:release() -- the player leaves mid grant
		expect(profiles:receipt(profile, "purchase-4", function() end)).to.equal(false)
		while answer == nil or profile.active do -- the grant, then the release it held back
			task.wait()
		end
		profiles.queue:flush(1)
		expect(answer).to.equal(true)
		local record = service.data.Profiles.u1
		expect(record.data.cash).to.equal(25)
		expect(record.receipts[1]).to.equal("purchase-3")
		expect(record.session).to.equal(nil)
	end)

	it("gives the same profile to a second load on the same server", function()
		local profiles = server(fakeService(), "A")
		local first = profiles:load("u1")
		expect(profiles:load("u1")).to.equal(first)
		expect(profiles:get("u1")).to.equal(first)
	end)

	it("fills new fields on load with reconcile", function()
		local service = fakeService()
		service:GetDataStore("Profiles")
		service.data.Profiles.u1 = { data = { cash = 3 }, receipts = {} }
		local profiles = server(service, "A", {
			reconcile = function(data)
				data.items = data.items or {}
			end,
		})
		local profile = assert(profiles:load("u1"))
		expect(profile.data.cash).to.equal(3)
		expect(type(profile.data.items)).to.equal("table")
	end)
end
