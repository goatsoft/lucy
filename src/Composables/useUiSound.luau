--!strict
local UiEvents = require(script.Parent.Parent.Core.UiEvents)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Maps the moments components report (activate, toggle, select, open, close) to
	the game's own functions, for components made inside this owner. Lucy plays no
	audio. The closest map that names an event wins and `false` silences it; a map
	in a top-level scope also covers components made with no owner. Stops with its
	owner. Each function gets (handle, value): toggle passes the new checked state,
	select the picked value.
]]
local function useUiSound(app: any, map: UiEvents.Map)
	requireOwner("useUiSound")
	UiEvents.listen(app, map)
end

return useUiSound
