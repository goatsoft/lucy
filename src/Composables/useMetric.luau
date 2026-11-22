--!strict
local Component = require(script.Parent.Parent.Core.Component)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local useDensity = require(script.Parent.useDensity)
local requireOwner = require(script.Parent.requireOwner)

-- Bumped when control heights change without a density change (text size).
local function metricsVersion(app: any): () -> number
	local shared = app._lucyMetrics
	if shared then
		return shared
	end
	local count = 0
	local version = Reactive.ref(count)
	app.maid:give(app.theme.MetricsChanged:Connect(function()
		count += 1
		version(count)
	end))
	local function read(): number
		return version()
	end
	app._lucyMetrics = read
	return read
end

-- A control size token (ControlSm, ControlMd, ControlLg, ControlXl, ControlIcon) in pixels.
-- Follows the density and the player's text size.
local function useMetric(app: any, token: string): Reactive.Computed<number>
	requireOwner("useMetric")
	local density = useDensity(app)
	local metrics = metricsVersion(app)
	return Reactive.computed(function()
		density()
		metrics()
		return Component.metric(app, token)
	end)
end

return useMetric
