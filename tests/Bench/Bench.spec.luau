--[[
	The benchmark harness: statistics, the measure loop, the report, and a smoke run
	of every suite at a tiny scale so the benchmarks never rot. Real numbers come from
	`require(game.ReplicatedStorage.LucyTests.Bench.Run).run()`; see docs/benchmarks.md.
]]
return function()
	local Bench = require(script.Parent.Bench)

	describe("stats", function()
		it("summarises an odd sample", function()
			local s = Bench.stats({ 5, 1, 3, 2, 4 })
			expect(s.min).to.equal(1)
			expect(s.max).to.equal(5)
			expect(s.mean).to.equal(3)
			expect(s.median).to.equal(3)
			expect(s.p95).to.equal(5)
		end)

		it("averages the middle pair of an even sample", function()
			local s = Bench.stats({ 4, 1, 3, 2 })
			expect(s.median).to.equal(2.5)
		end)

		it("does not reorder the caller's table", function()
			local samples = { 3, 1, 2 }
			Bench.stats(samples)
			expect(samples[1]).to.equal(3)
		end)
	end)

	describe("measure", function()
		local function busy(seconds: number)
			local stop = os.clock() + seconds
			local spins = 0
			while os.clock() < stop do
				spins += 1
			end
			return spins
		end

		it("runs setup, run and teardown for warmup plus iterations", function()
			local counts = { setup = 0, run = 0, teardown = 0 }
			local result = Bench.measure({
				warmup = 2,
				iterations = 3,
				setup = function()
					counts.setup += 1
					return counts.setup
				end,
				run = function(state)
					expect(state).to.equal(counts.setup)
					counts.run += 1
				end,
				teardown = function(state)
					expect(state).to.equal(counts.setup)
					counts.teardown += 1
				end,
			})
			expect(counts.setup).to.equal(5)
			expect(counts.run).to.equal(5)
			expect(counts.teardown).to.equal(5)
			expect(#result.samples).to.equal(3)
		end)

		it("times only run, in milliseconds", function()
			local result = Bench.measure({
				warmup = 0,
				iterations = 3,
				setup = function()
					busy(0.02)
					return nil
				end,
				run = function()
					busy(0.002)
				end,
			})
			expect(result.median >= 2).to.equal(true)
			expect(result.median < 15).to.equal(true)
			expect(result.heapKb == nil or typeof(result.heapKb) == "number").to.equal(true)
		end)
	end)

	describe("report", function()
		it("formats results as a markdown table", function()
			local text = Bench.markdown({
				{
					name = "Mount rows",
					group = "Lists",
					size = 1000,
					median = 12.345,
					p95 = 15,
					heapKb = 820.4,
				},
			})
			expect(string.find(text, "| Mount rows |", 1, true) ~= nil).to.equal(true)
			expect(string.find(text, "12.35", 1, true) ~= nil).to.equal(true)
			expect(string.find(text, "1,000", 1, true) ~= nil).to.equal(true)
		end)

		it("shows n/a when every heap sample was cut by a collection", function()
			local text = Bench.markdown({
				{ name = "Writes", group = "Core", size = 10, median = 1, p95 = 1, heapKb = nil },
			})
			expect(string.find(text, "| n/a |", 1, true) ~= nil).to.equal(true)
		end)

		it("ignores heap samples a collection made negative", function()
			expect(Bench.heap({ -300, 10, 20, -5 })).to.equal(15)
			expect(Bench.heap({ -300 })).to.equal(nil)
		end)
	end)

	describe("suites", function()
		local root = script.Parent.Parent.Parent
		local package = root and root:FindFirstChild("Lucy")
		if not package then
			return
		end
		local Suites = require(script.Parent.Suites)
		local Run = require(script.Parent.Run)

		it("has a name, group, size and run for every suite", function()
			expect(#Suites >= 8).to.equal(true)
			for _, suite in Suites do
				expect(typeof(suite.name)).to.equal("string")
				expect(typeof(suite.group)).to.equal("string")
				expect(typeof(suite.size)).to.equal("number")
				expect(typeof(suite.run)).to.equal("function")
			end
		end)

		it("runs every suite at a tiny scale and cleans up", function()
			local report = Run.run({ lucy = package, scale = 0.01, iterations = 1, warmup = 0, quiet = true })
			expect(#report.results).to.equal(#Suites)
			for _, result in report.results do
				expect(result.error).to.equal(nil)
				expect(typeof(result.median)).to.equal("number")
			end
			local Harness = require(package.Testing.Harness)
			for _, child in Harness.guiParent():GetChildren() do
				expect(string.sub(child.Name, 1, 10)).never.to.equal("LucyBench_")
			end
		end)
	end)
end
