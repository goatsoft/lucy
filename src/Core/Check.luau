--!strict
--[[
	Check: what a client may send, said once (ADR 0058). Each check is a function that takes
	a value and answers (true) or (false, why). Server.handle runs them on a request's
	arguments before the handler sees them, so a handler can trust its arguments' types.

		local Check = Lucy.Check

		server:handle("weapon.fire", fire, {
			check = { Check.string({ max = 32 }), Check.vector({ max = 4096 }), Check.boolean },
			rate = { perSecond = 12, burst = 6 },
		})

	Checks:
		Check.any                         anything but nil
		Check.boolean
		Check.string({ min?, max? })      length in bytes; max defaults to 200
		Check.number({ min?, max?, integer? })  never NaN or infinite
		Check.vector({ max? })            a finite Vector3 whose length is at most max
		Check.instance(className?)        an Instance that IsA className
		Check.oneOf({ "a", "b" })         one of these values
		Check.optional(check)             nil, or passes check
		Check.array(check, max?)          a list (1..n, no holes) of at most max (100)
		Check.map(keyCheck, valueCheck, max?)  a table of at most max (100) pairs
		Check.struct({ field = check })   a table with exactly these fields
		Check.args({ checks })            a list of checks for a call's arguments (what
		                                  Server.handle uses); more arguments than checks fail
]]

export type Check = (value: any) -> (boolean, string?)

local Check = {}

local DEFAULT_STRING = 200
local DEFAULT_COUNT = 100

function Check.any(value: any): (boolean, string?)
	if value == nil then
		return false, "is missing"
	end
	return true
end

function Check.boolean(value: any): (boolean, string?)
	if type(value) ~= "boolean" then
		return false, `should be a boolean, not {typeof(value)}`
	end
	return true
end

function Check.string(options: { min: number?, max: number? }?): Check
	local min = options and options.min or 0
	local max = options and options.max or DEFAULT_STRING
	return function(value: any)
		if type(value) ~= "string" then
			return false, `should be a string, not {typeof(value)}`
		end
		if #value < min or #value > max then
			return false, `should be {min} to {max} bytes long`
		end
		return true
	end
end

function Check.number(options: { min: number?, max: number?, integer: boolean? }?): Check
	local min = options and options.min or -math.huge
	local max = options and options.max or math.huge
	local integer = options and options.integer or false
	return function(value: any)
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return false, `should be a number, not {typeof(value)}`
		end
		if value < min or value > max then
			return false, `should be from {min} to {max}`
		end
		if integer and value % 1 ~= 0 then
			return false, "should be a whole number"
		end
		return true
	end
end

function Check.vector(options: { max: number? }?): Check
	local max = options and options.max or math.huge
	return function(value: any)
		if typeof(value) ~= "Vector3" then
			return false, `should be a Vector3, not {typeof(value)}`
		end
		local v = value :: Vector3
		local length = v.Magnitude
		-- NaN in any part makes the length NaN; an infinite part makes it infinite
		if length ~= length or length == math.huge then
			return false, "should be finite"
		end
		if length > max then
			return false, `should be at most {max} long`
		end
		return true
	end
end

function Check.instance(className: string?): Check
	return function(value: any)
		if typeof(value) ~= "Instance" then
			return false, `should be an Instance, not {typeof(value)}`
		end
		if className and not (value :: Instance):IsA(className) then
			return false, `should be a {className}`
		end
		return true
	end
end

function Check.oneOf(values: { any }): Check
	local allowed = {}
	for _, v in values do
		allowed[v] = true
	end
	return function(value: any)
		if value == nil or not allowed[value] then
			return false, "is not one of the allowed values"
		end
		return true
	end
end

function Check.optional(check: Check): Check
	return function(value: any)
		if value == nil then
			return true
		end
		return check(value)
	end
end

local function plainTable(value: any): boolean
	return type(value) == "table" and getmetatable(value) == nil
end

function Check.array(check: Check, max: number?): Check
	local limit = max or DEFAULT_COUNT
	return function(value: any)
		if not plainTable(value) then
			return false, `should be a list, not {typeof(value)}`
		end
		local count = 0
		for key in value do
			count += 1
			-- stop at once: never walk more of an oversized payload than the limit
			if count > limit then
				return false, `should have at most {limit} items`
			end
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				return false, "should be a list"
			end
		end
		-- n distinct whole keys, every one from 1 to n: no holes (# alone can stop at any border)
		for key in value do
			if key > count then
				return false, "should be a list with no holes"
			end
		end
		for i = 1, count do
			local ok, why = check(value[i])
			if not ok then
				return false, `item {i} {why}`
			end
		end
		return true
	end
end

function Check.map(keyCheck: Check, valueCheck: Check, max: number?): Check
	local limit = max or DEFAULT_COUNT
	return function(value: any)
		if not plainTable(value) then
			return false, `should be a table, not {typeof(value)}`
		end
		local count = 0
		for key, item in value do
			count += 1
			if count > limit then
				return false, `should have at most {limit} entries`
			end
			local ok, why = keyCheck(key)
			if not ok then
				return false, `key {tostring(key)} {why}`
			end
			ok, why = valueCheck(item)
			if not ok then
				return false, `[{tostring(key)}] {why}`
			end
		end
		return true
	end
end

function Check.struct(fields: { [string]: Check }): Check
	return function(value: any)
		if not plainTable(value) then
			return false, `should be a table, not {typeof(value)}`
		end
		for key in value do
			if type(key) ~= "string" or not fields[key] then
				return false, `has a field it should not ({tostring(key)})`
			end
		end
		for key, check in fields do
			local ok, why = check(value[key])
			if not ok then
				return false, `.{key} {why}`
			end
		end
		return true
	end
end

-- A call's arguments: (true) or (false, why). More arguments than checks fail.
function Check.args(checks: { Check }): (...any) -> (boolean, string?)
	return function(...)
		local n = select("#", ...)
		if n > #checks then
			-- Trailing nils are fine (optional arguments left off)
			for i = #checks + 1, n do
				if (select(i, ...)) ~= nil then
					return false, `takes at most {#checks} arguments`
				end
			end
		end
		for i, check in checks do
			local ok, why = check((select(i, ...)))
			if not ok then
				return false, `argument {i} {why}`
			end
		end
		return true
	end
end

return Check
