--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	The app's one delay group for floating content (tooltips): the first tip waits its
	delay, then while one is open, or for `skip` seconds after one closes, the next opens
	at once, so moving along a row of buttons does not wait at each. Only one tip is open
	at a time: claiming closes the one before.

		local group = Lucy.useDelayGroup(app, { skip = 0.3 })
		task.delay(group.wait(0.5), open)   -- 0.5, or 0 while warm
		group.claim(id, close)              -- now open; closes the one that was
		group.release(id)                   -- closed
		group.current()                     -- the open one's id (tracked), or nil

	Options are read the first time an app's group is made. A tip's claim is let go when
	the owner that claimed it stops.
]]
export type DelayGroup = {
	wait: (delay: number) -> number,
	claim: (id: string, close: () -> ()) -> (),
	release: (id: string) -> (),
	current: () -> string?,
	skip: number,
}

local DEFAULT_SKIP = 0.3

local function make(options: { skip: number? }?): DelayGroup
	local skip = if options and options.skip then options.skip else DEFAULT_SKIP
	local current = Reactive.ref(nil :: string?)
	local closeCurrent: (() -> ())? = nil
	local closedAt = -math.huge
	local group: DelayGroup
	group = {
		skip = skip,
		wait = function(delay: number): number
			local now: string? = Reactive.peek(current) :: any
			if now ~= nil or os.clock() - closedAt < group.skip then
				return 0
			end
			return delay
		end,
		claim = function(id: string, close: () -> ())
			local before: string? = Reactive.peek(current) :: any
			local closeBefore = closeCurrent
			current(id)
			closeCurrent = close
			if before ~= nil and before ~= id and closeBefore then
				closeBefore()
			end
		end,
		release = function(id: string)
			local now: string? = Reactive.peek(current) :: any
			if now == id then
				current(nil)
				closeCurrent = nil
				closedAt = os.clock()
			end
		end,
		current = function(): string?
			return current()
		end,
	}
	return group
end

local function useDelayGroup(app: any, options: { skip: number? }?): DelayGroup
	requireOwner("useDelayGroup")
	local group = app._lucyDelayGroup
	if not group then
		group = make(options)
		app._lucyDelayGroup = group
	end
	return group
end

return useDelayGroup
