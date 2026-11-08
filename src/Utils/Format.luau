--!strict
--[[
	Format: turning values into text for the screen. Plain functions, no state.

		Lucy.Format.number(4200)              -- "4,200"
		Lucy.Format.number(1234.5678, 2)      -- "1,234.57"
		Lucy.Format.number(1234567, 0, ".")   -- "1.234.567"

	Luau's string.format pads and rounds ("%.1f", "%05d") but has no thousands separators.
]]

local Format = {}

-- A number with its thousands grouped, rounded to `decimals` places (default 0), with
-- `separator` between the groups (default ",")
function Format.number(n: number, decimals: number?, separator: string?): string
	local places = math.max(0, math.floor(decimals or 0))
	local sep = separator or ","
	local text = string.format(`%.{places}f`, math.abs(n))
	local whole, fraction = text:match("^(%d+)(.*)$")
	local grouped = (whole :: string):reverse():gsub("(%d%d%d)", "%1" .. sep:reverse()):reverse()
	if grouped:sub(1, #sep) == sep then
		grouped = grouped:sub(#sep + 1)
	end
	local negative = n < 0 and tonumber(text) ~= 0
	return (if negative then "-" else "") .. grouped .. (fraction :: string)
end

return Format
