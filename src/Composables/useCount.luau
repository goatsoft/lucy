--!strict
local Animate = require(script.Parent.Parent.Core.Animate)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Signal = require(script.Parent.Parent.Core.Signal)
local requireOwner = require(script.Parent.requireOwner)

export type Count = {
	value: Reactive.Computed<number>,
	counting: Reactive.Computed<boolean>,
	skip: () -> (),
	done: Signal.Signal,
}

--[[
	Counts a number up (or down) to `value`: from `options.from` (default 0) at first,
	and from where it is whenever `value` changes, over `options.seconds` (default 0.8),
	easing out as it lands. Returns { value, counting, skip, done }: `value` is the
	number now (not rounded: round or format it to show it, Lucy.Format.number);
	`skip()` lands it at once; `done` (a Signal) fires each time it lands. Runs on
	Animate's driver.
]]
local function useCount(
	value: Reactive.MaybeRef<number>,
	options: { seconds: number?, from: number? }?
): Count
	requireOwner("useCount")
	local seconds = math.max((options and options.seconds) or 0.8, 0)
	local shown = Reactive.ref((options and options.from) or 0)
	local moving = Reactive.ref(false)
	local done = Signal.new()
	local goal: number = Reactive.peek(shown :: any)
	local stopDrive: (() -> ())? = nil
	local function halt()
		if stopDrive then
			stopDrive()
			stopDrive = nil
		end
	end
	local function land()
		halt()
		shown(goal)
		if Reactive.peek(moving) then
			moving(false)
			done:Fire()
		end
	end
	Reactive.watch(function()
		return tonumber(Reactive.toValue(value)) or 0
	end, function(target)
		halt()
		goal = target
		local from: number = Reactive.peek(shown :: any)
		if from == goal or seconds <= 0 then
			shown(goal)
			moving(false)
			return
		end
		local elapsed = 0
		moving(true)
		stopDrive = Animate.drive(function(dt: number): boolean
			elapsed += dt
			local k = elapsed / seconds
			if k >= 1 then
				stopDrive = nil
				land()
				return true
			end
			shown(from + (goal - from) * (1 - (1 - k) ^ 3))
			return false
		end)
	end, { immediate = true })
	Reactive.onCleanup(function()
		halt()
		done:DisconnectAll()
	end)
	return {
		value = Reactive.computed(function()
			return shown()
		end),
		counting = Reactive.computed(function()
			return moving()
		end),
		skip = land,
		done = done,
	}
end

return useCount
