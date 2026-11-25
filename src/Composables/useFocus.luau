--!strict
local requireOwner = require(script.Parent.requireOwner)

--[[
	Whether gamepad or keyboard focus is on something (or inside it).

		local focus = Lucy.useFocus(app, button)
		focus.active()     -- tracked

	It follows app.input:focusRef(), so it moves with the selection whoever moved it.
]]
export type Focus = { active: () -> boolean }

local function useFocus(app: any, target: any): Focus
	requireOwner("useFocus")
	local focused = app.input:focusRef()
	return {
		active = function(): boolean
			local object = target
			if type(object) == "table" and object.Instance then
				object = object.Instance
			end
			local now = focused()
			if typeof(object) ~= "Instance" or now == nil then
				return false
			end
			return now == object or now:IsDescendantOf(object)
		end,
	}
end

return useFocus
