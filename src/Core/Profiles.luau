--!strict
--[[
	Profiles: players' saved data, held by one server at a time (ADR 0058). Built on a
	DataQueue: saves are paced and retried by the queue, and a profile is only ever written
	by the server that holds it.

		local queue = Lucy.DataQueue.new()
		local profiles = Lucy.Profiles.new(queue, "Profiles", {
			template = function() return { cash = 0, items = {} } end,
		})

		local profile, why = profiles:load(`u{player.UserId}`) -- yields; nil, "in use" | "failed"
		profile.data.cash += 100                               -- change data in place
		profile:save()                                         -- queued; also every autosave
		profile:release()                                      -- on leave: last save, let go

		-- MarketplaceService.ProcessReceipt: grants once, answers once it is saved
		local granted = profiles:receipt(profile, info.PurchaseId, function(data)
			data.cash += 0 -- never cash for Robux in Crime Spree; a cosmetic here
		end)

		-- After a trade: both sides saved before either player is told it is done
		local saved = Lucy.Profiles.commit({ a, b })

	Why one server at a time: a player who leaves one server and joins another at once
	would otherwise load what the first server has not saved yet, and keep both copies of
	anything they just traded away (the classic item dupe). load claims the profile with
	UpdateAsync, writing this server's JobId into it; another server that finds a fresh
	claim waits for it to be let go (tries x wait seconds) and then gives up with "in use",
	so the game can tell the player to try again in a moment. A claim older than `stale`
	seconds belongs to a server that died, and is taken over. Every save checks the claim
	is still this server's; if another server took it (this one stalled past `stale`), the
	profile is lost: nothing more is written and onLost hears about it (kick the player).

	The record in the store: { data, session = { job, at }?, receipts = { PurchaseId }, at }

	options (all optional):
		template   the data for a new player: a table (copied) or a function that makes one
		reconcile  fn(data) after a load, to fill fields added since the profile was made
		autosave   seconds between saves of every held profile (60)
		stale      seconds after which another server's claim is a dead server's (autosave
		           x 3 + 60)
		tries      how many times load reads a claimed profile before "in use" (6)
		wait       seconds between those reads (2.5)
		receipts   how many PurchaseIds a profile remembers (100)
		jobId      this server's id (game.JobId, or "studio" in Studio)
		bindToClose  false to leave BindToClose alone (specs)
		autoRun    false: no autosave loop (specs)
		time, sleep  wall clock seconds and a yield (specs)
]]

local RunService = game:GetService("RunService")

local Profiles = {}
Profiles.__index = Profiles

local Profile = {}
Profile.__index = Profile

export type Profile = typeof(setmetatable(
	{} :: {
		key: string,
		data: any,
		receipts: { string },
		active: boolean,
		lost: boolean,
		profiles: any,
		_granting: { [string]: boolean },
	},
	Profile
))

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, child in value do
		out[deepCopy(key)] = deepCopy(child)
	end
	return out
end

function Profiles.new(queue: any, name: string, options: { [string]: any }?): any
	local opts: { [string]: any } = options or {}
	local autosave = opts.autosave or 60
	local jobId = opts.jobId or (if game.JobId ~= "" then game.JobId else "studio")
	local self = setmetatable({
		queue = queue,
		handle = queue:store(name),
		name = name,
		template = opts.template or {},
		reconcile = opts.reconcile,
		autosave = autosave,
		stale = opts.stale or autosave * 3 + 60,
		tries = opts.tries or 6,
		wait = opts.wait or 2.5,
		receiptLimit = opts.receipts or 100,
		jobId = jobId,
		time = opts.time or os.time,
		sleep = opts.sleep or task.wait,
		held = {} :: { [string]: Profile },
		onLost = nil :: ((profile: Profile) -> ())?,
		destroyed = false,
		_connection = nil :: RBXScriptConnection?,
	}, Profiles)

	if opts.autoRun ~= false then
		local since = 0
		self._connection = RunService.Heartbeat:Connect(function(dt: number)
			since += dt
			if since >= self.autosave then
				since = 0
				self:saveAll()
			end
		end)
	end
	if opts.bindToClose ~= false then
		game:BindToClose(function()
			self:releaseAll()
			queue:flush(queue.closeTimeout)
		end)
	end
	return self
end

local function newData(self: any): any
	local template = self.template
	if type(template) == "function" then
		return template()
	end
	return deepCopy(template)
end

-- Whether a stored record is claimed by a live server other than this one
function Profiles._heldElsewhere(self: any, record: any): boolean
	local session = if type(record) == "table" then record.session else nil
	return type(session) == "table"
		and type(session.job) == "string"
		and session.job ~= self.jobId
		and type(session.at) == "number"
		and self.time() - session.at < self.stale
end

-- Claims the record at key for this server: (record) or (nil, "in use" | "failed", error?)
function Profiles._claim(self: any, key: string): (any, string?)
	local handle = self.handle
	local queue = self.queue
	if queue.offline or not handle.store then
		local record = handle.memory[key]
		if self:_heldElsewhere(record) then
			return nil, "in use"
		end
		record = if type(record) == "table" then record else { receipts = {} }
		record.session = { job = self.jobId, at = self.time() }
		handle.memory[key] = record
		return record
	end
	for try = 1, self.tries do
		local busy = false
		queue:_waitFor(Enum.DataStoreRequestType.UpdateAsync)
		local ok, result = pcall(function()
			return handle.store:UpdateAsync(key, function(old: any)
				if self:_heldElsewhere(old) then
					busy = true
					return nil -- leave it as it is
				end
				local record = if type(old) == "table" then old else { receipts = {} }
				record.session = { job = self.jobId, at = self.time() }
				return record
			end)
		end)
		if not ok then
			queue.warn(`[Lucy] Profiles: could not load "{key}" from "{self.name}": {result}`)
			if try == self.tries then
				return nil, "failed"
			end
		elseif not busy then
			handle.cache[key] = { value = result, at = queue.clock() }
			handle.memory[key] = result
			return result
		end
		if try < self.tries then
			self.sleep(self.wait)
		end
	end
	return nil, "in use"
end

-- Loads and holds the profile at key (yields). (profile) or (nil, "in use" | "failed").
-- Loading a key this server already holds answers the same profile.
function Profiles.load(self: any, key: string): (Profile?, string?)
	local existing = self.held[key]
	if existing then
		return existing
	end
	-- A release of this key from this server (a quick leave and rejoin) must land first, or the
	-- claim would read the data from before it and the release would then clear the new claim
	if not self.handle:await(key, self.tries * self.wait + 30) then
		return nil, "in use"
	end
	if self.held[key] then
		return self.held[key]
	end
	local record, why = self:_claim(key)
	if not record then
		return nil, why
	end
	if self.held[key] then
		return self.held[key] -- a second load finished first
	end
	local data = record.data
	if type(data) ~= "table" then
		data = newData(self)
	end
	if self.reconcile then
		self.reconcile(data)
	end
	local profile: Profile = setmetatable({
		key = key,
		data = data,
		receipts = if type(record.receipts) == "table" then record.receipts else {},
		active = true,
		lost = false,
		profiles = self,
		_granting = {},
	}, Profile) :: any
	self.held[key] = profile
	return profile
end

-- The profile this server holds at key, or nil
function Profiles.get(self: any, key: string): Profile?
	return self.held[key]
end

local function write(profile: Profile, release: boolean)
	local self = profile.profiles
	if not profile.active then
		return -- released or lost: never written again
	end
	if release then
		profile.active = false
		self.held[profile.key] = nil
	end
	self.handle:update(profile.key, function(old: any)
		-- Only load takes over a profile. A save writes only while the stored claim is still this
		-- server's: another server's claim (fresh or stale) or none at all (another server took it
		-- over and let it go) means this copy is out of date
		local session = if type(old) == "table" then old.session else nil
		local ours = type(session) == "table" and session.job == self.jobId
		if not ours then
			-- Another server holds it now: this copy must never be written again
			if not profile.lost then
				profile.lost = true
				profile.active = false
				if self.held[profile.key] == profile then
					self.held[profile.key] = nil
				end
				self.queue.warn(
					`[Lucy] Profiles: "{profile.key}" is held by another server; this copy is dropped`
				)
				if self.onLost then
					task.spawn(self.onLost, profile)
				end
			end
			return old
		end
		if profile.lost then
			return old
		end
		local now = self.time()
		return {
			data = profile.data,
			receipts = profile.receipts,
			session = if release then nil else { job = self.jobId, at = now },
			at = now,
		}
	end)
end

-- Queues a save (the DataQueue paces it). Also keeps this server's claim fresh.
function Profile.save(self: Profile)
	write(self, false)
end

-- The last save, letting the profile go so another server can load it. The profile is no
-- longer held: drop references to it.
function Profile.release(self: Profile)
	write(self, true)
end

-- Yields until every save so far has landed (true), or `timeout` seconds pass (false). False
-- too when the profile is lost: what it held was not saved.
function Profile.await(self: Profile, timeout: number?): boolean
	local landed = self.profiles.handle:await(self.key, timeout)
	return landed and not self.lost
end

-- Grants a purchase once: grant(data) runs only if this PurchaseId has not been granted,
-- then the profile is saved. True once the grant is saved (answer PurchaseGranted), false
-- if it is not saved yet (answer NotProcessedYet; Roblox asks again, and it is not granted
-- twice).
function Profiles.receipt(self: any, profile: Profile, purchaseId: string, grant: (data: any) -> ()): boolean
	if not profile.active then
		return false
	end
	-- Another call for this purchase is granting it (grant yielded): wait for it, never grant twice
	while profile._granting[purchaseId] do
		task.wait(0.05)
	end
	if not table.find(profile.receipts, purchaseId) then
		if not profile.active then
			return false
		end
		profile._granting[purchaseId] = true
		local ok, err = pcall(function()
			grant(profile.data)
		end)
		if ok then
			table.insert(profile.receipts, purchaseId)
			while #profile.receipts > self.receiptLimit do
				table.remove(profile.receipts, 1)
			end
		end
		profile._granting[purchaseId] = nil
		if not ok then
			self.queue.warn(`[Lucy] Profiles: granting {purchaseId} failed: {err}`)
			return false
		end
		profile:save()
	end
	return profile:await(15)
end

-- Saves every profile given and waits for all of them (after a trade: tell the players it
-- is done only when this is true). DataStores cannot write two keys as one, so this makes
-- the gap as short as it can be; with every profile held by this server, nobody can load
-- either side elsewhere in the meantime.
function Profiles.commit(profiles: { Profile }, timeout: number?): boolean
	-- Every profile checked before any is saved, so one side of a trade is never written alone
	for _, profile in profiles do
		if not profile.active then
			return false
		end
	end
	for _, profile in profiles do
		profile:save()
	end
	local ok = true
	for _, profile in profiles do
		if not profile:await(timeout or 15) then
			ok = false
		end
	end
	return ok
end

-- Saves every held profile (the autosave)
function Profiles.saveAll(self: any)
	for _, profile in self.held do
		profile:save()
	end
end

-- Releases every held profile (on close)
function Profiles.releaseAll(self: any)
	for _, profile: any in table.clone(self.held) do
		profile:release()
	end
end

function Profiles.destroy(self: any)
	self.destroyed = true
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return Profiles
