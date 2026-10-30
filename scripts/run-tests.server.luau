-- Entry point for headless runs (run-in-roblox in CI, or Play in the test place).
-- Errors on failure so run-in-roblox exits non-zero.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local summary = require(ReplicatedStorage:WaitForChild("LucyTests"):WaitForChild("Runner")).run()
print(`[Lucy] {summary.passed} passed, {summary.failed} failed, {summary.skipped} skipped`)
if not summary.ok then
	error(`[Lucy] tests failed:\n{table.concat(summary.errors, "\n")}`)
end
