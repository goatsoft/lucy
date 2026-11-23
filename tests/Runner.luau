--[[
	Runs every *.spec module under Lucy (specs live next to the code they test)
	and under LucyTests. Used by scripts/run-tests.server.luau in CI and called
	directly from Studio (command bar or the Studio MCP):

		require(game.ReplicatedStorage.LucyTests.Runner).run()
		require(game.ReplicatedStorage.LucyTests.Runner).run({ pattern = "Button" })

	Each run tests fresh copies of Lucy, LucyTests and LucyExamples (siblings in a folder of
	their own, removed after), because Studio keeps the first loaded copy of a module: in edit
	mode a spec would otherwise run against code from before Rojo's last sync. { fresh = false }
	runs the originals. The Runner itself is still the first loaded copy; after changing this
	file, restart Studio or Play.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Runner = {}

-- Copies of the folders a run tests, side by side as in ReplicatedStorage, so specs that look
-- up their siblings (Stories.spec, Bench.spec) find the copies
local function copies(): (Folder, Instance, Instance?)
	local holder = Instance.new("Folder")
	holder.Name = "LucyTestRun"
	local lucy = ReplicatedStorage:WaitForChild("Lucy"):Clone()
	lucy.Parent = holder
	local tests: Instance? = nil
	for _, name in { "LucyTests", "LucyExamples" } do
		local original = ReplicatedStorage:FindFirstChild(name)
		if original then
			local copy = original:Clone()
			copy.Parent = holder
			if name == "LucyTests" then
				tests = copy
			end
		end
	end
	holder.Parent = ReplicatedStorage
	return holder, lucy, tests
end

function Runner.run(options: { pattern: string?, quiet: boolean?, fresh: boolean? }?)
	local opts = options or {}
	local TestEZ = require(ReplicatedStorage:WaitForChild("DevPackages"):WaitForChild("TestEZ"))
	local holder: Folder? = nil
	local roots: { Instance }
	if opts.fresh == false then
		roots = { ReplicatedStorage:WaitForChild("Lucy") }
		local extra = ReplicatedStorage:FindFirstChild("LucyTests")
		if extra then
			table.insert(roots, extra)
		end
	else
		local folder, lucy, tests = copies()
		holder = folder
		roots = { lucy }
		if tests then
			table.insert(roots, tests)
		end
	end

	local reporter = if opts.quiet then TestEZ.Reporters.TextReporterQuiet else TestEZ.Reporters.TextReporter
	local ran, results = pcall(function()
		return TestEZ.TestBootstrap:run(roots, reporter, {
			testNamePattern = opts.pattern,
		})
	end)
	if holder then
		holder:Destroy()
	end
	if not ran then
		error(results, 0)
	end

	local errors = {}
	for _, message in results.errors do
		table.insert(errors, tostring(message))
	end
	return {
		passed = results.successCount,
		failed = results.failureCount,
		skipped = results.skippedCount,
		errors = errors,
		ok = results.failureCount == 0 and #results.errors == 0,
	}
end

return Runner
