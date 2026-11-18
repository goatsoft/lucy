--!strict
--[[
	Preload: one queue that fetches images before they are shown, so a shop or a long list opens
	with its pictures already there instead of grey boxes filling in.

		local job = Lucy.preload({ 12345, "rbxassetid://678", decal })
		job.progress()   -- 0 to 1, a getter (bind it to a loading bar)
		job.done()       -- true once every image in this call has been fetched
		Lucy.preload(urgent, { first = true })   -- ahead of what is already waiting

	Ids are asset ids, content urls or instances (anything ContentProvider:PreloadAsync takes).
	An image fetched before (or waiting already) is not fetched again. The queue works in batches
	of Preload.batchSize, one batch at a time, so a long list never holds up the game; a failed
	image counts as done (PreloadAsync reports it, the picture just shows when it can).

	On a client, an asset id or url is drawn once: a batch of tiny, nearly see-through ImageLabels
	in a ScreenGui under everything, kept until each is IsLoaded (or Preload.warmTimeout). PreloadAsync
	alone only downloads a picture; the first time it is drawn still takes a while, and that is what
	a player sees as a grey box. Measured in Studio (Dance Lab's pass renders): preloaded with
	PreloadAsync, a picture took 0.6 to 1.4 s to show; drawn once this way (8 at a time, 0.7 s for
	the batch), it showed in about 0.1 s, also after the tiny copies were gone. With no player
	(a server, edit mode, tests) ids go to PreloadAsync as before.

	Pinned (ADR 0051): Lucy.preload(ids, { pin = true }) keeps each drawn copy for as long as it is
	pinned, so Roblox never counts the picture unused and unloads it; job.release() lets it go. For
	what must always be ready (icon sheets, the first screens); the rest is warmed before it is needed.

	Preload.isLoaded(id) says whether an image has been fetched through the queue, Preload.isPinned(id)
	whether it is pinned, and Preload.stats() counts what is pinned, warmed and waiting.
	Tests swap Preload.provider for a fake with a PreloadAsync(list, callback) method, and
	Preload.surface for where the drawn copies go (a function returning an Instance, or nil).
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Reactive = require(script.Parent.Reactive)

local Preload = {}

Preload.batchSize = 8
Preload.provider = ContentProvider :: any
-- Seconds a batch's drawn copies wait to load before the queue moves on
Preload.warmTimeout = 5

-- Where pictures are drawn once: a ScreenGui in the player's PlayerGui, under every other one.
-- nil with no player (a server, edit mode)
local holderGui: ScreenGui? = nil
function Preload.surface(): Instance?
	if holderGui and holderGui.Parent then
		return holderGui
	end
	local player = if RunService:IsClient() then Players.LocalPlayer else nil
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LucyPreload"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1000000
	gui.Parent = playerGui
	holderGui = gui
	return gui
end

-- Draws each url once, tiny and nearly see-through, until it has loaded (see the header)
local function draw(urls: { string }, surface: Instance)
	local labels: { ImageLabel } = {}
	for _, url in urls do
		local label = Instance.new("ImageLabel")
		label.Name = "Preload"
		label.Size = UDim2.fromOffset(2, 2)
		label.BackgroundTransparency = 1
		label.ImageTransparency = 0.98
		label.Image = url
		label.Parent = surface
		table.insert(labels, label)
	end
	local started = os.clock()
	while os.clock() - started < Preload.warmTimeout do
		local all = true
		for _, label in labels do
			if not label.IsLoaded then
				all = false
				break
			end
		end
		if all then
			break
		end
		task.wait()
	end
	for _, label in labels do
		label:Destroy()
	end
end

export type Job = {
	progress: () -> number,
	done: () -> boolean,
	-- With pin: lets the pictures go again (they stay loaded until Roblox drops them)
	release: () -> (),
}

type Entry = { key: any, jobs: { () -> () } }

local loaded: { [any]: boolean } = {}
-- Pinned pictures: how many jobs hold each, and its kept copy once it has loaded (ADR 0051)
local pins: { [any]: { count: number, label: ImageLabel? } } = {}
local waiting: { [any]: Entry } = {}
local queue: { Entry } = {}
local running = false

-- The key an id is known by: a url for asset ids, the instance itself otherwise
local function keyOf(id: any): any
	if type(id) == "number" then
		return if id > 0 then "rbxassetid://" .. tostring(id) else nil
	end
	if type(id) == "string" then
		if id == "" then
			return nil
		end
		return if string.match(id, "^%d+$") then "rbxassetid://" .. id else id
	end
	if typeof(id) == "Instance" then
		return id
	end
	return nil
end

-- Whether a picture is pinned (ADR 0051): kept in use until every job pinning it releases it
function Preload.isPinned(id: any): boolean
	local key = keyOf(id)
	return key ~= nil and pins[key] ~= nil
end

function Preload.isLoaded(id: any): boolean
	local key = keyOf(id)
	return key ~= nil and loaded[key] == true
end

-- A pinned picture's copy, drawn for as long as it is pinned so Roblox never counts it unused.
-- Made once it has loaded (the queue's batches set the pace); only urls are drawn.
local function keep(key: any)
	local pin = pins[key]
	if not pin or pin.label or not loaded[key] or type(key) ~= "string" then
		return
	end
	local surface = Preload.surface()
	if not surface then
		return
	end
	local label = Instance.new("ImageLabel")
	label.Name = "Pinned"
	label.Size = UDim2.fromOffset(2, 2)
	label.BackgroundTransparency = 1
	label.ImageTransparency = 0.98
	label.Image = key
	label.Parent = surface
	pin.label = label
end

local function finish(entry: Entry)
	loaded[entry.key] = true
	keep(entry.key)
	waiting[entry.key] = nil
	for _, notify in entry.jobs do
		notify()
	end
end

local function run()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local batch: { Entry } = {}
			local list: { any } = {}
			local urls: { string } = {}
			local surface = Preload.surface()
			while #queue > 0 and #batch < Preload.batchSize do
				local entry = table.remove(queue, 1) :: Entry
				table.insert(batch, entry)
				if surface and type(entry.key) == "string" then
					table.insert(urls, entry.key)
				else
					table.insert(list, entry.key)
				end
			end
			if #list > 0 then
				pcall(function()
					Preload.provider:PreloadAsync(list)
				end)
			end
			if surface and #urls > 0 then
				pcall(draw, urls, surface)
			end
			for _, entry in batch do
				finish(entry)
			end
		end
		running = false
	end)
end

-- Fetches `ids` through the queue; returns the job's progress and done getters.
function Preload.preload(ids: { any }, options: { first: boolean?, pin: boolean? }?): Job
	local first = options ~= nil and options.first == true
	local pin = options ~= nil and options.pin == true
	local held: { any } = {}
	local total, count = 0, Reactive.ref(0)
	local function notify()
		count(count() + 1)
	end
	local fresh: { Entry } = {}
	local seen: { [any]: boolean } = {}
	for _, id in ids do
		local key = keyOf(id)
		if key == nil or seen[key] then
			continue
		end
		seen[key] = true
		total += 1
		if pin then
			local entry = pins[key] or { count = 0 }
			entry.count += 1
			pins[key] = entry
			table.insert(held, key)
			keep(key)
		end
		if loaded[key] then
			count(count() + 1)
		elseif waiting[key] then
			local entry = waiting[key]
			table.insert(entry.jobs, notify)
			if first then
				local at = table.find(queue, entry)
				if at then
					table.remove(queue, at)
					table.insert(fresh, entry)
				end
			end
		else
			local entry: Entry = { key = key, jobs = { notify } }
			waiting[key] = entry
			table.insert(fresh, entry)
		end
	end
	if first then
		for i = #fresh, 1, -1 do
			table.insert(queue, 1, fresh[i])
		end
	else
		for _, entry in fresh do
			table.insert(queue, entry)
		end
	end
	if #queue > 0 then
		run()
	end
	return {
		progress = function(): number
			return if total == 0 then 1 else math.min(1, count() / total)
		end,
		done = function(): boolean
			return count() >= total
		end,
		release = function()
			for _, key in held do
				local entry = pins[key]
				if entry then
					entry.count -= 1
					if entry.count <= 0 then
						if entry.label then
							entry.label:Destroy()
						end
						pins[key] = nil
					end
				end
			end
			table.clear(held)
		end,
	}
end

-- How many pictures are pinned, have been warmed (loaded through the queue) and are waiting
function Preload.stats(): { pinned: number, warmed: number, waiting: number }
	local pinned, warmed, waitingCount = 0, 0, 0
	for _ in pins do
		pinned += 1
	end
	for _ in loaded do
		warmed += 1
	end
	for _ in waiting do
		waitingCount += 1
	end
	return { pinned = pinned, warmed = warmed, waiting = waitingCount }
end

-- Forgets every image (tests)
function Preload._reset()
	for _, entry in pins do
		if entry.label then
			entry.label:Destroy()
		end
	end
	table.clear(pins)
	table.clear(loaded)
	table.clear(waiting)
	table.clear(queue)
end

return Preload
