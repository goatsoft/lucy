--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	The theme's density as a read-only ref. Follows the theme itself (not the
	store key), so anything read alongside it, such as tokens, is already updated.
	One per app, shared by every caller and stopped with the app: a component
	asking for it costs nothing.
]]
local function useDensity(app: any): Reactive.Computed<string>
	requireOwner("useDensity")
	local shared = app._lucyDensity
	if shared then
		return shared
	end
	local density = Reactive.ref(app.theme:getDensity())
	app.maid:give(app.theme.DensityChanged:Connect(function(name: string)
		density(name)
	end))
	local function read(): string
		return density()
	end
	app._lucyDensity = read
	return read
end

return useDensity
