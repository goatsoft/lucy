--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

local UserInputService = game:GetService("UserInputService")

export type DragOptions = {
	onStart: ((point: Vector2) -> ())?,
	onMove: ((delta: Vector2, point: Vector2) -> ())?,
	onEnd: ((delta: Vector2) -> ())?,
	disabled: Reactive.MaybeRef<boolean>?,
	-- tests: the press signal (instead of target.InputBegan) and the input service
	began: RBXScriptSignal?,
	input: any?,
}

export type Drag = {
	dragging: Reactive.Computed<boolean>,
	delta: Reactive.Computed<Vector2>,
	cancel: () -> (),
}

local function pointOf(input: any): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

--[[
	Follows the mouse or a finger dragging from `target` (a GuiObject, or a ref or
	getter for one, such as h:ref), in screen pixels. A press on the target starts
	it; moving anywhere on the screen moves it; letting go ends it. Returns
	{ dragging, delta, cancel }: `delta` is how far it has moved since the press,
	back to zero after. options: onStart(point), onMove(delta, point), onEnd(delta),
	disabled (a ref or getter: no new drags, and turning it on ends one). Stopping
	the owner ends a drag too, calling onEnd.

	A gamepad has no pointer: give console players a stick or buttons for the same
	thing.
]]
local function useDrag(target: Reactive.MaybeRef<GuiObject?>, options: DragOptions?): Drag
	requireOwner("useDrag")
	local opts: DragOptions = options or {}
	local input: any = opts.input or UserInputService
	local dragging = Reactive.ref(false)
	local delta = Reactive.ref(Vector2.zero)
	local origin = Vector2.zero
	local connections: { RBXScriptConnection } = {}

	local function stopListening()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function finish()
		stopListening()
		if not Reactive.peek(dragging) then
			return
		end
		local moved: Vector2 = Reactive.peek(delta :: any)
		Reactive.batch(function()
			dragging(false)
			delta(Vector2.zero)
		end)
		if opts.onEnd then
			opts.onEnd(moved)
		end
	end

	local function start(pressed: any)
		local kind = pressed.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if Reactive.untrack(function()
			return Reactive.toValue(opts.disabled)
		end) then
			return
		end
		finish()
		origin = pointOf(pressed)
		dragging(true)
		if opts.onStart then
			opts.onStart(origin)
		end
		table.insert(
			connections,
			input.InputChanged:Connect(function(changed: any)
				local moved = if kind == Enum.UserInputType.Touch
					then changed == pressed
					else changed.UserInputType == Enum.UserInputType.MouseMovement
				if moved then
					local point = pointOf(changed)
					delta(point - origin)
					if opts.onMove then
						opts.onMove(point - origin, point)
					end
				end
			end)
		)
		table.insert(
			connections,
			input.InputEnded:Connect(function(ended: any)
				local released = if kind == Enum.UserInputType.Touch
					then ended == pressed
					else ended.UserInputType == Enum.UserInputType.MouseButton1
				if released then
					finish()
				end
			end)
		)
	end

	-- Presses on the target, while there is one
	Reactive.watchEffect(function(onCleanup)
		local signal: RBXScriptSignal? = opts.began
		if not signal then
			local gui: GuiObject? = Reactive.toValue(target) :: any
			signal = if gui then gui.InputBegan else nil
		end
		if not signal then
			return
		end
		local connection = signal:Connect(start)
		onCleanup(function()
			connection:Disconnect()
		end)
	end)
	-- Turning disabled on ends a drag
	Reactive.watchEffect(function()
		if Reactive.toValue(opts.disabled) then
			Reactive.untrack(finish)
		end
	end)
	Reactive.onCleanup(finish)

	return {
		dragging = Reactive.computed(function()
			return dragging()
		end),
		delta = Reactive.computed(function()
			return delta()
		end),
		cancel = finish,
	}
end

return useDrag
