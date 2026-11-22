--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Responsive = require(script.Parent.Parent.Core.Responsive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	A responsive value ({ touch = 16, default = 8 }, see Responsive) resolved
	against the app's input state, as a getter that follows it. A plain value is
	returned as a getter too, so callers bind either the same way. A getter (or a
	ref) is followed as it is: a layout that depends on the game's own state.
]]
local function useResponsive(app: any, value: any): () -> any
	requireOwner("useResponsive")
	if type(value) == "function" then
		return value
	end
	if not Responsive.isResponsive(value) then
		return function(): any
			return value
		end
	end
	local state = app.state
	local segments = state:_segments("input")
	return Reactive.computed(function(): any
		return Responsive.pick(state:_tracked(segments) or {}, value)
	end)
end

return useResponsive
