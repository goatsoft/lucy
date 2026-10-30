--[[
	Animate: springs and tweens that are themselves reactive sources (ADR 0014).

		local open = Lucy.ref(false)
		local x = Lucy.spring(function() return if open() then 0 else -300 end, 6, 0.8)
		Lucy.new "Frame" { Position = function() return UDim2.fromOffset(x(), 0) end }

		local color = Lucy.tween(themeColor, TweenInfo.new(0.2, Enum.EasingStyle.Quad))

	spring(source, speed = 10, damping = 1): speed is the natural frequency in Hz
	(how quick), damping 1 is critically damped, below 1 bounces. Both may be refs.
	tween(source, info = TweenInfo.new(0.2)): eases from wherever it is to the new
	target using info.Time, EasingStyle, EasingDirection and DelayTime (repeats and
	reverses are ignored).

	Animates number, Vector2, Vector3, UDim, UDim2 and Color3. Colours move through
	Oklab, so a spring from red to blue passes through a clean purple, not mud. Any
	other type, or a change of type, snaps. One Heartbeat connection drives all
	animations and disconnects when everything is at rest.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Oklab = require(script.Parent.Oklab)
local Reactive = require(script.Parent.Reactive)

type Animator = { step: (dt: number) -> boolean }

local Animate = {}

-- Tests set this and drive frames with Animate.step(dt).
Animate.manual = false

local EPSILON = 1e-4

local active: { [Animator]: boolean } = {}
local connection: RBXScriptConnection? = nil

local function stepAll(dt: number)
	Reactive.batch(function()
		for animator in active do
			if animator.step(dt) then
				active[animator] = nil
			end
		end
	end)
	if next(active) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function start(animator: Animator)
	active[animator] = true
	if connection == nil and not Animate.manual then
		connection = RunService.Heartbeat:Connect(stepAll)
	end
end

local function stop(animator: Animator)
	active[animator] = nil
end

function Animate.step(dt: number)
	stepAll(dt)
end

local function pack(value: any): (string?, { number }?)
	local kind = typeof(value)
	if kind == "number" then
		return kind, { value }
	elseif kind == "Vector2" then
		return kind, { value.X, value.Y }
	elseif kind == "Vector3" then
		return kind, { value.X, value.Y, value.Z }
	elseif kind == "UDim" then
		return kind, { value.Scale, value.Offset }
	elseif kind == "UDim2" then
		return kind, { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "Color3" then
		local L, a, b = Oklab.toOklab(value)
		return kind, { L, a, b }
	end
	return nil, nil
end

local function unpack(kind: string, p: { number }): any
	if kind == "number" then
		return p[1]
	elseif kind == "Vector2" then
		return Vector2.new(p[1], p[2])
	elseif kind == "Vector3" then
		return Vector3.new(p[1], p[2], p[3])
	elseif kind == "UDim" then
		return UDim.new(p[1], p[2])
	elseif kind == "UDim2" then
		return UDim2.new(p[1], p[2], p[3], p[4])
	end
	return Oklab.fromOklab(p[1], p[2], p[3])
end

local function zeros(n: number): { number }
	return table.create(n, 0)
end

local function readOnly<T>(output: Reactive.Ref<T>): Reactive.Computed<T>
	return Reactive.computed(function()
		return output()
	end)
end

function Animate.spring<T>(
	source: Reactive.MaybeRef<T>,
	speed: Reactive.MaybeRef<number>?,
	damping: Reactive.MaybeRef<number>?
): Reactive.Computed<T>
	local initial = Reactive.peek(source)
	local output = Reactive.ref(initial)
	local kind, position = pack(initial)
	local goal = if position then table.clone(position) else nil
	local velocity = if position then zeros(#position) else nil

	local animator = {} :: Animator
	function animator.step(dt: number): boolean
		if kind == nil or position == nil or goal == nil or velocity == nil then
			return true
		end
		local omega = 2 * math.pi * math.max(Reactive.peek(speed or 10) :: number, 0.01)
		local zeta = math.max(Reactive.peek(damping or 1) :: number, 0)
		local maxStep = math.min(1 / 240, 0.5 / omega)
		local remaining = dt
		while remaining > 0 do
			local h = math.min(remaining, maxStep)
			remaining -= h
			for i = 1, #position do
				local x, v = position[i], velocity[i]
				v += (-omega * omega * (x - goal[i]) - 2 * zeta * omega * v) * h
				position[i], velocity[i] = x + v * h, v
			end
		end
		local settled = true
		for i = 1, #position do
			if math.abs(position[i] - goal[i]) > EPSILON or math.abs(velocity[i]) > EPSILON then
				settled = false
				break
			end
		end
		if settled then
			position = table.clone(goal)
			velocity = zeros(#goal)
		end
		output(unpack(kind, position :: { number }))
		return settled
	end

	Reactive.watch(function()
		return Reactive.toValue(source)
	end, function(target)
		local newKind, packed = pack(target)
		if newKind == nil or newKind ~= kind or packed == nil then
			kind, position, goal = newKind, packed, if packed then table.clone(packed) else nil
			velocity = if packed then zeros(#packed) else nil
			stop(animator)
			output(target)
			return
		end
		goal = packed
		start(animator)
	end)
	Reactive.onCleanup(function()
		stop(animator)
	end)
	return readOnly(output)
end

function Animate.tween<T>(
	source: Reactive.MaybeRef<T>,
	info: Reactive.MaybeRef<TweenInfo>?
): Reactive.Computed<T>
	local initial = Reactive.peek(source)
	local output = Reactive.ref(initial)
	local kind, current = pack(initial)
	local from, to = current, current
	local elapsed, duration, delay = 0, 0, 0
	local style, direction = Enum.EasingStyle.Quad, Enum.EasingDirection.Out

	local animator = {} :: Animator
	function animator.step(dt: number): boolean
		if kind == nil or from == nil or to == nil then
			return true
		end
		elapsed += dt
		local alpha = if duration <= 0 then 1 else math.clamp((elapsed - delay) / duration, 0, 1)
		local done = alpha >= 1
		if done then
			current = table.clone(to)
		else
			local eased = TweenService:GetValue(alpha, style, direction)
			local values = table.create(#to)
			for i = 1, #to do
				values[i] = from[i] + (to[i] - from[i]) * eased
			end
			current = values
		end
		output(unpack(kind, current :: { number }))
		return done
	end

	Reactive.watch(function()
		return Reactive.toValue(source)
	end, function(target)
		local newKind, packed = pack(target)
		if newKind == nil or newKind ~= kind or packed == nil then
			kind, current, from, to = newKind, packed, packed, packed
			stop(animator)
			output(target)
			return
		end
		local tweenInfo = (Reactive.peek(info) or TweenInfo.new(0.2)) :: TweenInfo
		from, to = table.clone(current :: { number }), packed
		elapsed, duration, delay = 0, tweenInfo.Time, tweenInfo.DelayTime
		style, direction = tweenInfo.EasingStyle, tweenInfo.EasingDirection
		start(animator)
	end)
	Reactive.onCleanup(function()
		stop(animator)
	end)
	return readOnly(output)
end

return Animate
