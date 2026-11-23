return function()
	local Preload = require(script.Parent.Preload)

	local real, batchSize, surface, warmTimeout
	local calls: { { any } }
	local gate: BindableEvent?
	beforeEach(function()
		real, batchSize = Preload.provider, Preload.batchSize
		surface, warmTimeout = Preload.surface, Preload.warmTimeout
		-- No player here: ids go to the provider (the drawn path has its own test)
		Preload.surface = function()
			return nil
		end
		calls = {}
		gate = nil
		Preload._reset()
		Preload.provider = {
			PreloadAsync = function(_, list: { any })
				table.insert(calls, table.clone(list))
				if gate then
					gate.Event:Wait()
				end
			end,
		}
	end)
	afterEach(function()
		Preload.provider, Preload.batchSize = real, batchSize
		Preload.surface, Preload.warmTimeout = surface, warmTimeout
		if gate then
			gate:Fire()
		end
		task.wait()
		Preload._reset()
	end)

	it("fetches ids as urls, once each, and reports progress", function()
		local job = Preload.preload({ 1, "2", "rbxassetid://3", 1, "", 0 })
		task.wait()
		expect(#calls).to.equal(1)
		expect(table.concat(calls[1], ",")).to.equal("rbxassetid://1,rbxassetid://2,rbxassetid://3")
		expect(job.done()).to.equal(true)
		expect(job.progress()).to.equal(1)
		expect(Preload.isLoaded(2)).to.equal(true)
		-- Fetched before: done at once, no new fetch
		local again = Preload.preload({ 1, 2 })
		expect(again.done()).to.equal(true)
		task.wait()
		expect(#calls).to.equal(1)
	end)

	it("on a client, draws each url once, tiny, then takes the copies away", function()
		local host = Instance.new("Folder")
		Preload.surface = function()
			return host
		end
		Preload.warmTimeout = 0.05 -- nothing renders here, so the copies wait it out
		local decal = Instance.new("Decal")
		local job = Preload.preload({ 5, 6, decal })
		task.wait()
		-- The urls are drawn, not sent; an instance still goes to the provider
		expect(#calls).to.equal(1)
		expect(#calls[1]).to.equal(1)
		expect(calls[1][1]).to.equal(decal)
		local drawn = {}
		for _, child in host:GetChildren() do
			expect(child.ClassName).to.equal("ImageLabel")
			expect((child :: ImageLabel).Size).to.equal(UDim2.fromOffset(2, 2))
			table.insert(drawn, (child :: ImageLabel).Image)
		end
		table.sort(drawn)
		expect(table.concat(drawn, ",")).to.equal("rbxassetid://5,rbxassetid://6")
		task.wait(0.15)
		expect(#host:GetChildren()).to.equal(0)
		expect(job.done()).to.equal(true)
		expect(Preload.isLoaded(5)).to.equal(true)
		decal:Destroy()
		host:Destroy()
	end)

	it("warms a picture again once Roblox may have dropped it, not before", function()
		local fresh = Preload.fresh
		Preload.fresh = 0.2
		Preload.preload({ 21 })
		task.wait()
		expect(#calls).to.equal(1)
		-- Still fresh: nothing to do
		local again = Preload.preload({ 21 })
		expect(again.done()).to.equal(true)
		task.wait()
		expect(#calls).to.equal(1)
		task.wait(0.3)
		-- Stale: warmed again
		expect(Preload.isLoaded(21)).to.equal(false)
		Preload.preload({ 21 })
		task.wait()
		expect(#calls).to.equal(2)
		Preload.fresh = fresh
	end)

	describe("pinned (ADR 0051)", function()
		local host: Folder
		beforeEach(function()
			host = Instance.new("Folder")
			Preload.surface = function()
				return host
			end
			Preload.warmTimeout = 0.05 -- nothing renders here, so the warming copies wait it out
		end)
		afterEach(function()
			Preload._reset()
			host:Destroy()
		end)

		local function kept(): { string }
			local images = {}
			for _, child in host:GetChildren() do
				if child.Name == "Pinned" then
					table.insert(images, (child :: ImageLabel).Image)
				end
			end
			table.sort(images)
			return images
		end

		it("keeps a drawn copy of each picture until the job releases it", function()
			local job = Preload.preload({ 7, 8 }, { pin = true })
			task.wait(0.15)
			expect(job.done()).to.equal(true)
			expect(table.concat(kept(), ",")).to.equal("rbxassetid://7,rbxassetid://8")
			for _, child in host:GetChildren() do
				expect((child :: ImageLabel).Size).to.equal(UDim2.fromOffset(2, 2))
			end
			expect(Preload.stats().pinned).to.equal(2)
			job.release()
			expect(#kept()).to.equal(0)
			expect(Preload.stats().pinned).to.equal(0)
			-- Still loaded: only Roblox may drop it now
			expect(Preload.isLoaded(7)).to.equal(true)
		end)

		it("keeps a picture pinned twice until both release it", function()
			local a = Preload.preload({ 9 }, { pin = true })
			local b = Preload.preload({ 9 }, { pin = true })
			task.wait(0.15)
			expect(#kept()).to.equal(1)
			a.release()
			a.release() -- twice from one job counts once
			expect(#kept()).to.equal(1)
			b.release()
			expect(#kept()).to.equal(0)
		end)

		it("pins a picture warmed before at once", function()
			Preload.preload({ 10 })
			task.wait(0.15)
			expect(#kept()).to.equal(0)
			Preload.preload({ 10 }, { pin = true })
			expect(table.concat(kept(), ",")).to.equal("rbxassetid://10")
		end)

		it("counts pins with nothing to draw on (a server)", function()
			Preload.surface = function()
				return nil
			end
			local job = Preload.preload({ 11 }, { pin = true })
			task.wait()
			expect(Preload.stats().pinned).to.equal(1)
			job.release()
			expect(Preload.stats().pinned).to.equal(0)
		end)

		it("reports what is pinned, warmed and waiting", function()
			Preload.batchSize = 1
			Preload.preload({ 12 }, { pin = true })
			Preload.preload({ 13, 14 })
			local now = Preload.stats()
			expect(now.pinned).to.equal(1)
			expect(now.waiting >= 1).to.equal(true)
			task.wait(0.5)
			local later = Preload.stats()
			expect(later.waiting).to.equal(0)
			expect(later.warmed).to.equal(3)
		end)
	end)

	it("works in batches", function()
		Preload.batchSize = 2
		local job = Preload.preload({ 1, 2, 3, 4, 5 })
		task.wait()
		expect(#calls).to.equal(3)
		expect(#calls[1]).to.equal(2)
		expect(#calls[3]).to.equal(1)
		expect(job.done()).to.equal(true)
	end)

	it("puts urgent images first", function()
		Preload.batchSize = 1
		gate = Instance.new("BindableEvent")
		local slow = Preload.preload({ 1, 2, 3 })
		task.wait()
		-- 1 is being fetched; 2 and 3 wait
		local urgent = Preload.preload({ 3, 9 }, { first = true })
		local open = gate :: BindableEvent
		gate = nil
		open:Fire()
		task.wait()
		expect(calls[2][1]).to.equal("rbxassetid://3")
		expect(calls[3][1]).to.equal("rbxassetid://9")
		expect(calls[4][1]).to.equal("rbxassetid://2")
		expect(urgent.done()).to.equal(true)
		expect(slow.done()).to.equal(true)
	end)

	it("starts afresh after a reset, whatever an earlier batch is still doing", function()
		gate = Instance.new("BindableEvent")
		Preload.preload({ 1 })
		task.wait()
		-- 1 is still being fetched when the queue is reset
		local stuck = gate :: BindableEvent
		gate = nil
		Preload._reset()
		local job = Preload.preload({ 5 })
		expect(job.done()).to.equal(true)
		-- The old batch ending later leaves the fresh queue alone
		stuck:Fire()
		task.wait()
		expect(Preload.isLoaded(1)).to.equal(false)
		expect(Preload.isLoaded(5)).to.equal(true)
	end)

	it("shows progress part way", function()
		Preload.batchSize = 1
		gate = Instance.new("BindableEvent")
		local job = Preload.preload({ 1, 2 })
		task.wait()
		expect(job.progress()).to.equal(0);
		(gate :: BindableEvent):Fire()
		task.wait()
		expect(job.progress()).to.equal(0.5)
		expect(job.done()).to.equal(false)
	end)
end
