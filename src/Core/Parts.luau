--!strict
--[[
	Parts: a part of a component placed outside the component's own frame (Tabs' bar in a
	Sheet's header, say) still belongs to that component. Lucy's input follows the component
	tree, not the Instance tree, as a portal does: from the part, the next one up is its
	component, wherever the part sits.

		Parts.own(handle, part)          part belongs to handle's component, wherever it is placed
		Parts.parent(app, node) -> Instance?
		                                 the next one up from node: its component's root when node
		                                 is an owned part (and the component is still there),
		                                 otherwise node.Parent

	What walks up with it: InputManager's LB / RB (shoulder), arrows (nudge) and presses on a
	part of a component (press), and Devtools' component tree. Visibility and layout still follow
	the Instance tree: a part shows where it is placed.

	The link is the part's LucyOwner attribute, the owner's id (as LucyId names a component's
	root), so it shows in Studio's Explorer.
]]

local Parts = {}

Parts.ATTRIBUTE = "LucyOwner"

function Parts.own(handle: any, part: Instance)
	part:SetAttribute(Parts.ATTRIBUTE, handle.id)
end

function Parts.parent(app: any, node: Instance): Instance?
	local id = node:GetAttribute(Parts.ATTRIBUTE)
	if type(id) == "string" then
		local owner: any = app:handle(id)
		if owner and not owner.destroyed and owner.Instance and owner.Instance ~= node then
			return owner.Instance
		end
	end
	return node.Parent
end

return Parts
