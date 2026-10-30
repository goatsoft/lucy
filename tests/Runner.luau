--[[
	Runs every *.spec module under Lucy (specs live next to the code they test)
	and under LucyTests. Used by scripts/run-tests.server.luau in CI and called
	directly from Studio (command bar or the Studio MCP):

		require(game.ReplicatedStorage.LucyTests.Runner).run()
		require(game.ReplicatedStorage.LucyTests.Runner).run({ pattern = "Button" })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Runner = {}

function Runner.run(options: { pattern: string?, quiet: boolean? }?)
	local opts = options or {}
	local TestEZ = require(ReplicatedStorage:WaitForChild("DevPackages"):WaitForChild("TestEZ"))
	local roots = { ReplicatedStorage:WaitForChild("Lucy") }
	local extra = ReplicatedStorage:FindFirstChild("LucyTests")
	if extra then
		table.insert(roots, extra)
	end

	local reporter = if opts.quiet then TestEZ.Reporters.TextReporterQuiet else TestEZ.Reporters.TextReporter
	local results = TestEZ.TestBootstrap:run(roots, reporter, {
		testNamePattern = opts.pattern,
	})

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
