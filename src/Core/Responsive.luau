--[[
	Responsive: pick values by device, input mode, breakpoint or orientation.

	A responsive value is a table keyed by any of:
		device       mobile | tablet | desktop | console
		mode         touch | gamepad | keyboard | mouse
		breakpoint   compact | regular | wide
		orientation  portrait | landscape
		default      fallback
	The first matching key in that order wins:

		Responsive.pick(app, { mobile = "vertical", default = "horizontal" })
		Responsive.watch(app, { console = 4, touch = 3, default = 6 }, function(columns) end)

	Anything that is not such a table is returned unchanged, so props can accept
	plain or responsive values: Stack.new({ direction = { mobile = "vertical", default = "horizontal" } }).
]]

local Responsive = {}

Responsive.keys = {
	device = { "mobile", "tablet", "desktop", "console" },
	mode = { "touch", "gamepad", "keyboard", "mouse" },
	breakpoint = { "compact", "regular", "wide" },
	orientation = { "portrait", "landscape" },
}

local KNOWN = { default = true }
for _, list in Responsive.keys do
	for _, key in list do
		KNOWN[key] = true
	end
end

function Responsive.isResponsive(value: any): boolean
	if type(value) ~= "table" or getmetatable(value) ~= nil or value[1] ~= nil then
		return false
	end
	local any = false
	for key in value do
		if not KNOWN[key] then
			return false
		end
		any = true
	end
	return any
end

local function snapshot(source: any): { [string]: any }
	if type(source) == "table" and source.state then
		return source.state:get("input") or {}
	end
	return source or {}
end

-- Resolves a responsive value against an app (or a raw input snapshot).
function Responsive.pick(source: any, value: any): any
	if not Responsive.isResponsive(value) then
		return value
	end
	local input = snapshot(source)
	local candidates = {
		input.device,
		input.mode,
		input.breakpoint and string.lower(input.breakpoint),
		input.orientation,
	}
	for _, key in candidates do
		if key ~= nil and value[key] ~= nil then
			return value[key]
		end
	end
	return value.default
end

-- Calls fn(resolved) now and whenever the resolved value changes. Returns unsubscribe.
function Responsive.watch(app: any, value: any, fn: (any) -> ()): () -> ()
	local current = Responsive.pick(app, value)
	fn(current)
	if not Responsive.isResponsive(value) then
		return function() end
	end
	return app.state:subscribe("input", function()
		local resolved = Responsive.pick(app, value)
		if resolved ~= current then
			current = resolved
			fn(resolved)
		end
	end)
end

-- Convenience predicates for game code.
function Responsive.is(app: any, key: string): boolean
	local input = snapshot(app)
	return input.device == key
		or input.mode == key
		or (input.breakpoint and string.lower(input.breakpoint) == key)
		or input.orientation == key
end

return Responsive
