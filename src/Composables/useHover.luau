--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Whether the pointer is over something, with a delay to open and one to close.

		local hover = Lucy.useHover(button, {
			delay = 0.5,              -- seconds before it turns on (a number or getter)
			closeDelay = 0.1,         -- seconds before it turns off
			also = { tip },           -- more objects that count as over it (an interactive tip)
			group = Lucy.useDelayGroup(app), -- skip the delay while another tip is warm
		})
		hover.active()                -- tracked
		hover.enter() hover.leave()   -- drive it by hand (specs, or your own input)

	Leaving and coming back (or crossing onto something in `also`) before the close delay
	keeps it on, so the pointer can cross the gap between a button and its tip. A target
	may be an instance, a component handle or nil (nothing to listen to).
]]
export type HoverOptions = {
	delay: Reactive.MaybeRef<number>?,
	closeDelay: Reactive.MaybeRef<number>?,
	also: { any }?,
	group: any?,
}
export type Hover = {
	active: () -> boolean,
	enter: () -> (),
	leave: () -> (),
}

local function instanceOf(target: any): GuiObject?
	if type(target) == "table" and target.Instance then
		target = target.Instance
	end
	if typeof(target) == "Instance" and target:IsA("GuiObject") then
		return target
	end
	return nil
end

local function useHover(target: any, options: HoverOptions?): Hover
	requireOwner("useHover")
	local opts: HoverOptions = options or {}
	local active = Reactive.ref(false)
	local pending: thread? = nil
	local inside = 0

	local function cancel()
		if pending then
			if coroutine.status(pending) == "suspended" then
				task.cancel(pending)
			end
			pending = nil
		end
	end
	local function after(seconds: number, value: boolean)
		cancel()
		if seconds <= 0 then
			active(value)
			return
		end
		pending = task.delay(seconds, function()
			pending = nil
			active(value)
		end)
	end

	local function enter()
		inside += 1
		if Reactive.peek(active) then
			cancel()
			return
		end
		local delay = Reactive.toValue(opts.delay) or 0
		if opts.group then
			delay = opts.group.wait(delay)
		end
		after(delay, true)
	end
	local function leave()
		inside = math.max(0, inside - 1)
		if inside > 0 then
			return
		end
		if not Reactive.peek(active) then
			cancel()
			return
		end
		after(Reactive.toValue(opts.closeDelay) or 0, false)
	end

	local connections: { RBXScriptConnection } = {}
	local function listen(object: any)
		local gui = instanceOf(object)
		if gui then
			table.insert(connections, gui.MouseEnter:Connect(enter))
			table.insert(connections, gui.MouseLeave:Connect(leave))
		end
	end
	listen(target)
	local also: { any } = opts.also or {}
	for _, object in also do
		listen(object)
	end

	Reactive.onCleanup(function()
		cancel()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	return {
		active = function(): boolean
			return active()
		end,
		enter = enter,
		leave = leave,
	}
end

return useHover
