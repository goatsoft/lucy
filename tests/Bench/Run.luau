--!strict
--[[
	Runs every benchmark suite and returns the results plus a markdown table.
	In the Lucy dev place (edit mode, or the Studio MCP):

		require(game.ReplicatedStorage.LucyTests.Bench.Run).run()
		require(game.ReplicatedStorage.LucyTests.Bench.Run).run({ only = "List" })

	Options: lucy (the package Instance, default ReplicatedStorage.Lucy), scale
	(multiplies every suite's size), iterations, warmup, only (a name pattern) and
	quiet (skip printing). See docs/benchmarks.md for how the published numbers are made.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bench = require(script.Parent.Bench)
local Suites = require(script.Parent.Suites)

export type Result = Bench.Row

export type Report = {
	results: { Result },
	markdown: string,
	environment: { [string]: any },
}

local Run = {}

function Run.run(options: { [string]: any }?): Report
	local opts: { [string]: any } = options or {}
	local package: Instance = opts.lucy or ReplicatedStorage:WaitForChild("Lucy")
	local Lucy = (require :: any)(package)
	local Harness = (require :: any)((package :: any).Testing.Harness)
	local scale: number = opts.scale or 1
	local iterations: number = opts.iterations or 15
	local warmup: number = opts.warmup or 3

	local app, cleanup = Harness.app({ theme = "dark", namePrefix = "LucyBench_" })
	local gui = app:portal("bench")
	local ctx = { Lucy = Lucy, app = app, gui = gui }

	local results: { Result } = {}
	for _, suite in Suites do
		if opts.only and not string.find(suite.name, opts.only) then
			continue
		end
		local n = math.max(1, math.floor(suite.size * scale))
		local ok, measured = pcall(Bench.measure, {
			warmup = warmup,
			iterations = iterations,
			setup = function()
				return suite.setup(ctx, n)
			end,
			run = suite.run,
			teardown = suite.teardown,
		})
		if ok then
			table.insert(results, {
				name = suite.name,
				group = suite.group,
				size = n,
				median = measured.median,
				p95 = measured.p95,
				heapKb = measured.heapKb,
			})
		else
			table.insert(results, {
				name = suite.name,
				group = suite.group,
				size = n,
				median = 0,
				p95 = 0,
				heapKb = nil,
				error = tostring(measured),
			})
		end
		-- Let Studio breathe between suites.
		task.wait()
	end
	cleanup()

	local markdown = Bench.markdown(results)
	if not opts.quiet then
		print(markdown)
	end
	return {
		results = results,
		markdown = markdown,
		environment = {
			date = os.date("!%Y-%m-%d"),
			-- selene: allow(undefined_variable)
			studio = version(),
			iterations = iterations,
			warmup = warmup,
			scale = scale,
		},
	}
end

return Run
