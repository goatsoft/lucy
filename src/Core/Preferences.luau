--!strict
--[[
	Preferences: the accessibility settings a player picks in the Roblox menu,
	as tracked getters (ADR 0029).

		Lucy.Preferences.reducedMotion()  -- true when the player asked for less motion
		Lucy.Preferences.textSize()       -- "Medium" | "Large" | "Larger" | "Largest"
		Lucy.Preferences.added(14)        -- px Roblox adds to 14 px text at that size

	Both follow GuiService live. A game with its own "reduce motion" toggle sets
	it with Preferences.setReducedMotion(true); nil follows Roblox again. Text
	size can't be set: Roblox draws the text, so Lucy only follows it.

	What Lucy does with them:
	  reduced motion  springs, and tweens of positions and sizes, jump to where
	                  they end; colour and number tweens still fade (Animate).
	                  The Switch thumb jumps, the Spinner pulses, a Collapsible
	                  opens at once.
	  text size       control heights grow by what their text grows (App, Theme).
]]

local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

local Reactive = require(script.Parent.Reactive)

local Preferences = {}

local function readMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

local function readTextSize(): string
	local ok, value = pcall(function()
		return GuiService.PreferredTextSize.Name
	end)
	return if ok and type(value) == "string" then value else "Medium"
end

local deviceMotion = Reactive.ref(readMotion())
local deviceTextSize = Reactive.ref(readTextSize())
local motionOverride: Reactive.Ref<boolean?> = Reactive.ref(nil :: boolean?)

-- Reading GuiService fails outside a client in some contexts; then the defaults stand.
pcall(function()
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		deviceMotion(readMotion())
	end)
	GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(function()
		deviceTextSize(readTextSize())
	end)
end)

-- True when motion should be cut: the game's own setting if it set one, else Roblox's.
function Preferences.reducedMotion(): boolean
	local override = motionOverride()
	if override ~= nil then
		return override
	end
	return deviceMotion()
end

-- Turn reduced motion on or off from the game's own settings; nil follows Roblox.
function Preferences.setReducedMotion(value: boolean?)
	motionOverride(value)
end

-- The player's text size, by Enum.PreferredTextSize name.
function Preferences.textSize(): string
	return deviceTextSize()
end

-- How many pixels taller Roblox draws text of `size` at the player's text size.
function Preferences.added(size: number): number
	local ok, bounds = pcall(function()
		return TextService:GetTextSize("", size, Enum.Font.BuilderSans, Vector2.new(1e6, 1e6))
	end)
	if not ok then
		return 0
	end
	return math.max(0, math.ceil(bounds.Y - size))
end

-- Tests: stand in for the Roblox settings. A key left out reads GuiService again.
function Preferences._setDevice(values: { reducedMotion: boolean?, textSize: string? })
	Reactive.batch(function()
		deviceMotion(if values.reducedMotion ~= nil then values.reducedMotion else readMotion())
		deviceTextSize(values.textSize or readTextSize())
	end)
end

return Preferences
