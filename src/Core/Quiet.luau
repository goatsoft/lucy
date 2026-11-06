--!strict
--[[
	Quiet (ADR 0038): a counted stack of reasons the app should not talk to the
	player, with channels. Every App has one at app.quiet.

		local release = app.quiet:push("tour", { allow = { "tour" } })
		app.quiet:active()             -- tracked: any reason pushed
		app.quiet:allows("rewards")    -- tracked: not quiet, or every reason allows it
		local cancel = app.quiet:after("rewards", fn)  -- now if allowed, else once it is
		release()

	A channel is any string a game picks. A reason allows only the channels it
	lists; "essential" is always allowed. push is cleaned up with the current
	owner when there is one, and its release function is safe to call twice.
	The reasons are published at quiet.reasons ({ reason, allow }, newest last).

	Toasts follow it by themselves (Components/Toaster: channel and quiet
	options); a game holds its own prompts with after.
]]

local Reactive = require(script.Parent.Reactive)

local Quiet = {}
Quiet.__index = Quiet

Quiet.ESSENTIAL = "essential"

local PATH = "quiet.reasons"

export type Entry = { reason: string, allow: { string }, key: number }

export type Quiet = typeof(setmetatable(
	{} :: {
		app: any,
		_reasons: Reactive.Ref<any>,
		_counter: number,
	},
	Quiet
))

function Quiet.new(app: any): Quiet
	local self = setmetatable({
		app = app,
		_reasons = app.state:ref(PATH),
		_counter = 0,
	}, Quiet)
	app.state:set(PATH, {})
	return self
end

function Quiet.push(self: Quiet, reason: string, options: { allow: { string }? }?): () -> ()
	if type(reason) ~= "string" then
		error("[Lucy] app.quiet:push needs a reason (a string)", 2)
	end
	self._counter += 1
	local key = self._counter
	local allow = table.clone(options and options.allow or {})
	self.app.state:update(PATH, function(list: { any }?)
		local out = table.clone(list or {})
		table.insert(out, { reason = reason, allow = allow, key = key })
		return out
	end)
	local released = false
	local function release()
		if released then
			return
		end
		released = true
		if self.app.destroyed then
			return
		end
		self.app.state:update(PATH, function(list: { any }?)
			local out = {}
			for _, entry in (list or {}) :: { any } do
				if entry.key ~= key then
					table.insert(out, entry)
				end
			end
			return out
		end)
	end
	Reactive.onCleanup(release)
	return release
end

function Quiet.active(self: Quiet): boolean
	local list = self._reasons()
	return list ~= nil and #list > 0
end

function Quiet.allows(self: Quiet, channel: string): boolean
	local list = self._reasons()
	if list == nil or #list == 0 or channel == Quiet.ESSENTIAL then
		return true
	end
	for _, entry in list do
		if not table.find(entry.allow, channel) then
			return false
		end
	end
	return true
end

-- Runs fn once, the first time `channel` is allowed (now, if it is). Returns a
-- cancel function; cancelled with the current owner too.
function Quiet.after(self: Quiet, channel: string, fn: () -> ()): () -> ()
	if Reactive.untrack(function()
		return self:allows(channel)
	end) then
		fn()
		return function() end
	end
	local scope = Reactive.effectScope(true)
	local done = false
	local function cancel()
		if not done then
			done = true
			scope:stop()
		end
	end
	scope:run(function()
		Reactive.watchEffect(function()
			if done or not self:allows(channel) then
				return
			end
			done = true
			-- Stop watching before running, so fn can push quiet again safely.
			task.defer(function()
				scope:stop()
			end)
			Reactive.untrack(fn)
		end)
	end)
	Reactive.onCleanup(cancel)
	return cancel
end

return Quiet
