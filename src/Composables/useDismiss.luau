--!strict
local UserInputService = game:GetService("UserInputService")

local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)
local useBackHandler = require(script.Parent.useBackHandler)

--[[
	Closes something open on Back (Escape, B) and on a press outside it.

		Lucy.useDismiss(app, open, {
			back = true,              -- Back closes it (and is used up)
			inside = { tip, button }, -- presses on these keep it open; leave out for Back only
		})

	`open` is a writable ref (or computed): it is set to false. dismiss.press(point) runs
	the outside check by hand (specs, or your own input).
]]
export type DismissOptions = {
	back: boolean?,
	inside: { any }?,
	hits: ((object: GuiObject, point: Vector2) -> boolean)?,
}
export type Dismiss = { press: (point: Vector2) -> () }

local function within(object: GuiObject, point: Vector2): boolean
	if not object.Visible or object.Parent == nil then
		return false
	end
	local at, size = object.AbsolutePosition, object.AbsoluteSize
	return point.X >= at.X and point.Y >= at.Y and point.X <= at.X + size.X and point.Y <= at.Y + size.Y
end

local function useDismiss(app: any, open: Reactive.Ref<boolean>, options: DismissOptions?): Dismiss
	requireOwner("useDismiss")
	local opts: DismissOptions = options or {}
	local hits: (GuiObject, Vector2) -> boolean = opts.hits or within

	if opts.back ~= false then
		useBackHandler(app, function()
			return open()
		end, function()
			open(false)
			return true
		end)
	end

	local function press(point: Vector2)
		if not Reactive.peek(open) or opts.inside == nil then
			return
		end
		for _, object in opts.inside do
			if type(object) == "table" and object.Instance then
				object = object.Instance
			end
			if typeof(object) == "Instance" and object:IsA("GuiObject") and hits(object, point) then
				return
			end
		end
		open(false)
	end

	if opts.inside then
		local connection = UserInputService.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				press(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)
		Reactive.onCleanup(function()
			connection:Disconnect()
		end)
	end

	return { press = press }
end

return useDismiss
