--!strict
--[[
	Tiles: a card a gamepad or the keys treat as one stop (an Item with focus = "tile").

	A tile's root is tagged ui-tile, and ui-tile-open while the player is inside it. While it is
	closed it is the only stop: focus that lands on something inside it goes to the tile, keys and
	the default focus skip what is in it (InputManager.selectables), its left and right lead into
	it, and its up and down go to the nearest stop above and below. Moving onto a control inside
	it from the tile (left or right), or A on it, opens it: the tile becomes a SelectionGroup that
	stops at its edges and a focus scope, so the D-pad and keys stay on its controls, and B
	(a back handler) closes it, focus back on the tile. Focus going anywhere else closes it too.
	The mouse and touch are left alone: a click on a control inside a closed tile still reaches it.

	The component owns the tile (its state, its tags, enter and leave); InputManager calls
	Tiles.landed each time focus moves, and Tiles.closedAround for selectables.

		Tiles.TAG, Tiles.OPEN               the tags
		Tiles.closedAround(object, stop?)   the nearest closed tile holding object (below stop)
		Tiles.opened(input, handle)         a tile was entered (Item:enter)
		Tiles.closed(input, handle)         a tile was left (Item:leave)
		Tiles.landed(input, object, previous)
		Tiles.toward(input, from, direction) the nearest stop that way, nil when none
]]

local Tiles = {}

Tiles.TAG = "ui-tile"
Tiles.OPEN = "ui-tile-open"

-- The tiles each input has open (one, but a tile in a tile could make two)
local open: { [any]: { any } } = setmetatable({}, { __mode = "k" }) :: any

local function openOf(input: any): { any }
	local list = open[input]
	if not list then
		list = {}
		open[input] = list
	end
	return list
end

-- The nearest tile holding `object` (not object itself) below `stop`, if it is closed
function Tiles.closedAround(object: Instance, stop: Instance?): GuiObject?
	local node = object.Parent
	while node and node ~= stop do
		if node:HasTag(Tiles.TAG) then
			return if node:HasTag(Tiles.OPEN) then nil else node :: GuiObject
		end
		node = node.Parent
	end
	return nil
end

function Tiles.opened(input: any, handle: any)
	local list = openOf(input)
	if not table.find(list, handle) then
		table.insert(list, handle)
	end
end

function Tiles.closed(input: any, handle: any)
	local list = openOf(input)
	local index = table.find(list, handle)
	if index then
		table.remove(list, index)
	end
end

local function handleOf(input: any, object: Instance): any
	local id = object:GetAttribute("LucyId")
	return id and input.app:handle(id)
end

local function centre(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2
end

-- The nearest stop past `from`'s edge that way (keys' order: a closed tile counts as one),
-- preferring one in line with it
function Tiles.toward(input: any, from: GuiObject, direction: Vector2): GuiObject?
	local at = centre(from)
	local half = from.AbsoluteSize / 2
	local best, bestScore = nil, math.huge
	for _, root in input:_scopeRoots() do
		for _, other in input:selectables(root) do
			if other ~= from and not other:IsDescendantOf(from) then
				local offset = centre(other) - at
				local reach = other.AbsoluteSize / 2
				-- How far past from's edge the other's near edge is, along the direction
				local along = if direction.X ~= 0
					then offset.X * direction.X - half.X - reach.X
					else offset.Y * direction.Y - half.Y - reach.Y
				local across = if direction.X ~= 0 then math.abs(offset.Y) else math.abs(offset.X)
				if along > -2 then
					local score = math.max(along, 0) + across * 2
					if score < bestScore then
						best, bestScore = other, score
					end
				end
			end
		end
	end
	return best
end

-- Focus moved to `object` (from `previous`), while navigating
function Tiles.landed(input: any, object: GuiObject?, previous: GuiObject?)
	if not object or not input:isNavigating() then
		return
	end
	-- Focus left an open tile: it closes
	for _, handle in table.clone(openOf(input)) do
		if handle.destroyed or not object:IsDescendantOf(handle.Instance) then
			handle:leave()
		end
	end
	if input._focused ~= object then
		return -- closing one moved focus on
	end
	-- Inside a closed tile: from the tile itself (left or right) it opens there, otherwise the
	-- tile takes the focus
	local tile = Tiles.closedAround(object)
	if tile then
		local handle = handleOf(input, tile)
		if previous == tile and handle and handle.enter then
			handle:enter(object)
		else
			input:focus(tile)
		end
		return
	end
	-- On a closed tile: left and right lead in, up and down to the stops around it
	if object:HasTag(Tiles.TAG) and not object:HasTag(Tiles.OPEN) then
		local first = input:selectables(object)[1]
		object.NextSelectionLeft = first
		object.NextSelectionRight = first
		object.NextSelectionUp = Tiles.toward(input, object, Vector2.new(0, -1))
		object.NextSelectionDown = Tiles.toward(input, object, Vector2.new(0, 1))
	end
end

return Tiles
