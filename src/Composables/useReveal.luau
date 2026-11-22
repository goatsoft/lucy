--!strict
local Animate = require(script.Parent.Parent.Core.Animate)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Signal = require(script.Parent.Parent.Core.Signal)
local requireOwner = require(script.Parent.requireOwner)

-- How many characters a reader sees: rich text tags take none, an entity takes one
local ENTITIES = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }
local function visibleLength(text: string, rich: boolean): number
	if rich then
		text = text:gsub("<[^>]*>", ""):gsub("&(%a+);", function(name)
			return ENTITIES[name]
		end)
	end
	return utf8.len(text) or #text
end

export type Reveal = {
	visible: Reactive.Computed<number>,
	revealing: Reactive.Computed<boolean>,
	skip: () -> (),
	done: Signal.Signal,
}

--[[
	Types a text out: how many of its characters to show, rising at `rate` a second
	(default 40), from none each time the text changes. Bind `visible` to a
	TextLabel's MaxVisibleGraphemes: the whole text is laid out from the start, so
	words never jump to the next line as they appear. Returns { visible, revealing,
	skip, done }: `visible` is -1 once it is all out; `skip()` shows the rest at
	once; `done` (a Signal) fires each time a text is all out. options.rich: the
	text has rich text tags, which take no time. Runs on Animate's driver.
]]
local function useReveal(text: Reactive.MaybeRef<string>, options: { rate: number?, rich: boolean? }?): Reveal
	requireOwner("useReveal")
	local rate = math.max((options and options.rate) or 40, 1)
	local rich = options ~= nil and options.rich == true
	local shown = Reactive.ref(-1)
	local typing = Reactive.ref(false)
	local done = Signal.new()
	local stopDrive: (() -> ())? = nil
	local function halt()
		if stopDrive then
			stopDrive()
			stopDrive = nil
		end
	end
	local function finish()
		halt()
		shown(-1)
		if Reactive.peek(typing) then
			typing(false)
			done:Fire()
		end
	end
	Reactive.watch(function()
		return Reactive.toValue(text)
	end, function(value)
		halt()
		local total = visibleLength(tostring(value or ""), rich)
		if total == 0 then
			shown(-1)
			typing(false)
			return
		end
		local elapsed = 0
		shown(0)
		typing(true)
		stopDrive = Animate.drive(function(dt: number): boolean
			elapsed += dt
			local count = math.floor(elapsed * rate + 1e-6)
			if count >= total then
				stopDrive = nil
				finish()
				return true
			end
			shown(count)
			return false
		end)
	end, { immediate = true })
	Reactive.onCleanup(function()
		halt()
		done:DisconnectAll()
	end)
	return {
		visible = Reactive.computed(function()
			return shown()
		end),
		revealing = Reactive.computed(function()
			return typing()
		end),
		skip = finish,
		done = done,
	}
end

return useReveal
