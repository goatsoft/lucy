--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Whole seconds left until `endsAt` (a number, ref or getter in
	workspace:GetServerTimeNow() time, so every player sees the same count). Returns
	{ remaining, done }: `remaining` never goes below 0 and ticks once a second, on
	the second; `done` is true once it reaches 0. With no end time, remaining is 0
	and done is false. Follows `endsAt` when it changes. options.now replaces the
	clock (tests).
]]
local function useCountdown(
	endsAt: Reactive.MaybeRef<number?>,
	options: { now: (() -> number)? }?
): { remaining: Reactive.Computed<number>, done: Reactive.Computed<boolean> }
	requireOwner("useCountdown")
	local now: () -> number = (options and options.now)
		or function()
			return workspace:GetServerTimeNow()
		end
	local left = Reactive.ref(0)
	local ended = Reactive.ref(false)
	Reactive.watchEffect(function(onCleanup)
		local target: number? = Reactive.toValue(endsAt) :: any
		local thread: thread? = nil
		local function update()
			thread = nil
			if target == nil then
				Reactive.batch(function()
					left(0)
					ended(false)
				end)
				return
			end
			local seconds = target - now()
			local whole = math.max(math.ceil(seconds), 0)
			Reactive.batch(function()
				left(whole)
				ended(whole == 0)
			end)
			if whole > 0 then
				-- Until the count drops by one.
				thread = task.delay(seconds - (whole - 1), update)
			end
		end
		Reactive.untrack(update)
		onCleanup(function()
			if thread then
				task.cancel(thread)
				thread = nil
			end
		end)
	end)
	return {
		remaining = Reactive.computed(function()
			return left()
		end),
		done = Reactive.computed(function()
			return ended()
		end),
	}
end

return useCountdown
