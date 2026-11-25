--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Reactive = require(script.Parent.Parent.Core.Reactive)
local World = require(script.Parent.Parent.Core.World)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Whether the player's character is near something in the world.

		local near = Lucy.useProximity(app, workspace.Booth, {
			distance = 10,            -- studs (a number or getter)
			hysteresis = 1,           -- studs more to leave than to come in, so it does not
			                          -- flicker at the edge
			lineOfSight = false,      -- true: a wall between turns it off
			origin = nil,             -- () -> Vector3?: where to measure from (default the
			                          -- local character's root part)
		})
		near.active()                 -- tracked
		near.distance()               -- studs to it (tracked), math.huge with no character
		near.check()                  -- measure now (the app's loop does it every frame)

	The target is a BasePart, an Attachment, a Model (its pivot) or a Vector3. Every
	useProximity in an app shares one Heartbeat loop, which stops when the last one does.
	World.positionOf(target) is how it finds where the target is.
]]
export type ProximityOptions = {
	distance: Reactive.MaybeRef<number>?,
	hysteresis: number?,
	lineOfSight: boolean?,
	origin: (() -> Vector3?)?,
}
export type Proximity = {
	active: () -> boolean,
	distance: () -> number,
	check: () -> (),
}

type Watcher = { check: () -> () }
type Loop = { watchers: { Watcher }, connection: RBXScriptConnection? }

local positionOf = World.positionOf

local function characterPosition(): Vector3?
	local player = Players.LocalPlayer
	if not player then
		if not RunService:IsRunning() and workspace.CurrentCamera then
			return workspace.CurrentCamera.CFrame.Position
		end
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function clear(from: Vector3, target: any): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local player = Players.LocalPlayer
	if player and player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local to = positionOf(target)
	if not to then
		return false
	end
	local hit = workspace:Raycast(from, to - from, params)
	if not hit then
		return true
	end
	local object = if typeof(target) == "Instance" and target:IsA("Attachment") then target.Parent else target
	return typeof(object) == "Instance" and (hit.Instance == object or hit.Instance:IsDescendantOf(object))
end

local function loopOf(app: any): Loop
	local loop = app._lucyProximity
	if not loop then
		loop = { watchers = {}, connection = nil }
		app._lucyProximity = loop
	end
	return loop
end

local function useProximity(app: any, target: any, options: ProximityOptions?): Proximity
	requireOwner("useProximity")
	local opts: ProximityOptions = options or {}
	local hysteresis = opts.hysteresis or 1
	local origin: () -> Vector3? = opts.origin or characterPosition
	local active = Reactive.ref(false)
	local distance = Reactive.ref(math.huge)

	local function check()
		local from = origin()
		local at = positionOf(Reactive.toValue(target))
		if from == nil or at == nil then
			Reactive.batch(function()
				distance(math.huge)
				active(false)
			end)
			return
		end
		local d = (at - from).Magnitude
		local limit = Reactive.toValue(opts.distance) or 10
		local on = Reactive.peek(active)
		local near = if on then d <= limit + hysteresis else d <= limit
		if near and opts.lineOfSight then
			near = clear(from, Reactive.toValue(target))
		end
		Reactive.batch(function()
			distance(d)
			active(near)
		end)
	end

	local loop = loopOf(app)
	local watcher: Watcher = { check = check }
	table.insert(loop.watchers, watcher)
	if loop.connection == nil and RunService:IsRunning() then
		loop.connection = RunService.Heartbeat:Connect(function()
			for _, each in table.clone(loop.watchers) do
				each.check()
			end
		end)
	end
	check()
	Reactive.onCleanup(function()
		local index = table.find(loop.watchers, watcher)
		if index then
			table.remove(loop.watchers, index)
		end
		if #loop.watchers == 0 and loop.connection then
			loop.connection:Disconnect()
			loop.connection = nil
		end
	end)

	return {
		active = function(): boolean
			return active()
		end,
		distance = function(): number
			return distance()
		end,
		check = check,
	}
end

return useProximity
