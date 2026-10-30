--[[
	Test helpers shared by every spec.

	Universal Styling only resolves for instances inside the DataModel under a
	ScreenGui with a StyleLink, so specs mount real ScreenGuis. In Studio edit
	mode and on the server that is StarterGui; on a client it is PlayerGui.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Harness = {}

-- Capability sets for InputManager, one per device class.
Harness.caps = {
	desktop = { keyboard = true, mouse = true, viewport = Vector2.new(1280, 720) },
	mobile = { touch = true, viewport = Vector2.new(844, 390) },
	tablet = { touch = true, viewport = Vector2.new(1180, 820) },
	console = { tenFoot = true, gamepad = true, viewport = Vector2.new(1920, 1080) },
}

function Harness.guiParent(): Instance
	local player = Players.LocalPlayer
	if player then
		return player:WaitForChild("PlayerGui")
	end
	return StarterGui
end

-- Creates an App whose guis live under a disposable folder-free parent.
-- Returns app, cleanup.
function Harness.app(config: { [string]: any }?)
	local App = require(script.Parent.Parent.Core.App)
	local options = table.clone(config or {})
	options.parent = options.parent or Harness.guiParent()
	options.setCurrent = false
	options.namePrefix = options.namePrefix or "LucyTest_"
	-- Deterministic desktop with no engine listeners unless a spec asks otherwise.
	options.input = options.input or {
		watch = false,
		caps = Harness.caps.desktop,
	}
	local app = App.new(options)
	return app, function()
		app:destroy()
	end
end

-- A linked ScreenGui on the app's theme to mount a component into.
function Harness.mount(app): ScreenGui
	return app:portal("test")
end

--[[
	Let the styling engine apply pending changes. Styles resolve a few frames
	after a rule, tag or StyleDerive changes (measured: 4 heartbeats in Studio),
	so wait 8 to be safe. StylingService:UpdateUnitTestOnly is engine-only.
]]
Harness.styleFrames = 8
function Harness.flush()
	for _ = 1, Harness.styleFrames do
		RunService.Heartbeat:Wait()
	end
end

--[[
	The value a property actually renders with. Reading a styled property
	directly returns the unstyled value by design; GetStyled returns the
	resolved one.
]]
function Harness.styled(instance: Instance, property: string): any
	local ok, value = pcall(function()
		return (instance :: any):GetStyled(property)
	end)
	if ok and value ~= nil then
		return value
	end
	return (instance :: any)[property]
end

function Harness.colorEq(a: Color3?, b: Color3?): boolean
	if typeof(a) ~= "Color3" or typeof(b) ~= "Color3" then
		return false
	end
	local epsilon = 1 / 255
	return math.abs(a.R - b.R) < epsilon and math.abs(a.G - b.G) < epsilon and math.abs(a.B - b.B) < epsilon
end

-- Finds the first pseudo or real child UI component of a class (UICorner, UIStroke, ...).
function Harness.findChildOfClass(instance: Instance, className: string): Instance?
	return instance:FindFirstChildOfClass(className)
end

return Harness
