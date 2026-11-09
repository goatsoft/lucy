return function()
	local Preload = require(script.Parent.Preload)

	local real, batchSize
	local calls: { { any } }
	local gate: BindableEvent?
	beforeEach(function()
		real, batchSize = Preload.provider, Preload.batchSize
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
