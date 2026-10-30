--!strict
--[[
	UiEvents: the moments components tell the game about, so it can play its own
	sounds (Lucy plays none). Components emit; Lucy.useUiSound listens.

		activate   a button or pressable was clicked          fn(handle)
		toggle     a switch or checkbox changed by the player  fn(handle, checked)
		select     an item in a group was picked               fn(handle, value)
		open       a dialog opened                             fn(handle)
		close      a dialog closed                             fn(handle)

	Lookup: from the component's own scope up through its owners, the first map
	that names the event wins; `false` there silences it. A component with no map
	above it uses the newest map registered in a top-level scope (one with no
	owner), so components made by plain scripts are covered too. `sound = false`
	in a component's props silences that component.
]]

local Reactive = require(script.Parent.Reactive)

local UiEvents = {}

export type Map = { [string]: ((handle: any, value: any) -> ()) | false }

-- owner node -> its map. Weak, and cleared when the owner stops.
local maps: { [any]: Map } = setmetatable({}, { __mode = "k" }) :: any

-- Registers `map` on the current owner until it stops. One map per owner: a
-- second call in the same owner replaces the first.
function UiEvents.listen(app: any, map: Map)
	local node = Reactive._owner()
	assert(node ~= nil, "[Lucy] UiEvents.listen needs an owner")
	maps[node] = map
	local roots: { Map }? = nil
	if not node.owner then
		local list: { Map } = app._uiSoundRoots or {}
		app._uiSoundRoots = list
		table.insert(list, map)
		roots = list
	end
	Reactive.onCleanup(function()
		if maps[node] == map then
			maps[node] = nil
		end
		if roots then
			local index = table.find(roots, map)
			if index then
				table.remove(roots, index)
			end
		end
	end)
end

local function find(handle: any, event: string): any
	local scope = handle.scope
	local node = scope and scope._node
	while node do
		local map = maps[node]
		if map then
			local entry = map[event]
			if entry ~= nil then
				return entry
			end
		end
		node = node.owner
	end
	local roots = handle.app._uiSoundRoots
	if roots then
		for i = #roots, 1, -1 do
			local entry = roots[i][event]
			if entry ~= nil then
				return entry
			end
		end
	end
	return nil
end

-- Tells the game `event` happened on `handle`. A failing listener is reported,
-- never raised, so a sound can't break a click.
function UiEvents.emit(handle: any, event: string, value: any?)
	if handle.props.sound == false then
		return
	end
	local fn = find(handle, event)
	if fn then
		local ok, err = pcall(fn, handle, value)
		if not ok then
			task.spawn(error, `[Lucy] ui sound for "{event}" errored: {err}`, 0)
		end
	end
end

return UiEvents
