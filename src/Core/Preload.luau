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

	Preload.isLoaded(id) says whether an image has been fetched through the queue.
	Tests swap Preload.provider for a fake with a PreloadAsync(list, callback) method.
]]

local ContentProvider = game:GetService("ContentProvider")

local Reactive = require(script.Parent.Reactive)

local Preload = {}

Preload.batchSize = 8
Preload.provider = ContentProvider :: any

export type Job = {
	progress: () -> number,
	done: () -> boolean,
}

type Entry = { key: any, jobs: { () -> () } }

local loaded: { [any]: boolean } = {}
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

function Preload.isLoaded(id: any): boolean
	local key = keyOf(id)
	return key ~= nil and loaded[key] == true
end

local function finish(entry: Entry)
	loaded[entry.key] = true
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
			while #queue > 0 and #batch < Preload.batchSize do
				local entry = table.remove(queue, 1) :: Entry
				table.insert(batch, entry)
				table.insert(list, entry.key)
			end
			pcall(function()
				Preload.provider:PreloadAsync(list)
			end)
			for _, entry in batch do
				finish(entry)
			end
		end
		running = false
	end)
end

-- Fetches `ids` through the queue; returns the job's progress and done getters.
function Preload.preload(ids: { any }, options: { first: boolean? }?): Job
	local first = options ~= nil and options.first == true
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
	}
end

-- Forgets every image (tests)
function Preload._reset()
	table.clear(loaded)
	table.clear(waiting)
	table.clear(queue)
end

return Preload
