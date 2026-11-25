--!strict
local UserInputService = game:GetService("UserInputService")

local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	A press on something, as on or off.

		local held = Lucy.usePress(card)                         -- on while held down
		local info = Lucy.usePress(icon, { mode = "toggle" })    -- each press flips it
		local peek = Lucy.usePress(item, { longPress = 0.4 })    -- on once held that long
		held.active()             -- tracked; writable (info.active(false) closes it)
		held.press() held.release()   -- drive it by hand

	It listens for a mouse button or a touch starting on the target, and for that input
	ending anywhere, so letting go off the target still turns a hold off.
]]
export type PressOptions = {
	mode: string?,
	longPress: number?,
}
export type Press = {
	active: Reactive.Ref<boolean>,
	press: () -> (),
	release: () -> (),
}

local MODES = { hold = true, toggle = true }

local function usePress(target: any, options: PressOptions?): Press
	requireOwner("usePress")
	local opts: PressOptions = options or {}
	local mode = opts.mode or "hold"
	if not MODES[mode] then
		error(`[Lucy] usePress: unknown mode "{tostring(mode)}" (expected hold or toggle)`, 2)
	end
	local active = Reactive.ref(false)
	local pending: thread? = nil
	local down = false

	local function cancel()
		if pending then
			if coroutine.status(pending) == "suspended" then
				task.cancel(pending)
			end
			pending = nil
		end
	end

	local function press()
		down = true
		if mode == "toggle" then
			active(not Reactive.peek(active))
			return
		end
		local wait = opts.longPress or 0
		if wait <= 0 then
			active(true)
			return
		end
		cancel()
		pending = task.delay(wait, function()
			pending = nil
			if down then
				active(true)
			end
		end)
	end
	local function release()
		down = false
		cancel()
		if mode == "hold" then
			active(false)
		end
	end

	local object = target
	if type(object) == "table" and object.Instance then
		object = object.Instance
	end
	local connections: { RBXScriptConnection } = {}
	local function isPress(input: InputObject): boolean
		local kind = input.UserInputType
		return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
	end
	if typeof(object) == "Instance" and object:IsA("GuiObject") then
		table.insert(
			connections,
			object.InputBegan:Connect(function(input: InputObject)
				if isPress(input) then
					press()
				end
			end)
		)
		table.insert(
			connections,
			UserInputService.InputEnded:Connect(function(input: InputObject)
				if down and isPress(input) then
					release()
				end
			end)
		)
	end
	Reactive.onCleanup(function()
		cancel()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	return { active = active, press = press, release = release }
end

return usePress
