--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Whether any GUI child of `target` has Visible on: a getter that follows each
	child's own Visible (not its ancestors') and children coming and going. False
	while there is no target. `target` may be a ref or a getter.

	For a slot that should drop out of its layout (gap and all) when everything put
	in it hides itself, such as key hints hidden on touch:

		Element.hydrate(slot, { Visible = Lucy.useHasVisibleChild(slot) })
]]
local function useHasVisibleChild(target: Reactive.MaybeRef<Instance?>): () -> boolean
	requireOwner("useHasVisibleChild")
	local shown = Reactive.ref(false)
	local last = false
	local function set(value: boolean)
		if value ~= last then
			last = value
			shown(value)
		end
	end
	Reactive.watchEffect(function(onCleanup)
		local parent: Instance? = Reactive.toValue(target) :: any
		if not parent then
			set(false)
			return
		end
		local function check()
			for _, child in parent:GetChildren() do
				if child:IsA("GuiObject") and child.Visible then
					set(true)
					return
				end
			end
			set(false)
		end
		local watched: { [Instance]: RBXScriptConnection } = {}
		local function watch(child: Instance)
			if not watched[child] and child:IsA("GuiObject") then
				watched[child] = child:GetPropertyChangedSignal("Visible"):Connect(check)
			end
		end
		for _, child in parent:GetChildren() do
			watch(child)
		end
		local added = parent.ChildAdded:Connect(function(child)
			watch(child)
			check()
		end)
		local removed = parent.ChildRemoved:Connect(function(child)
			local connection = watched[child]
			if connection then
				connection:Disconnect()
				watched[child] = nil
			end
			check()
		end)
		onCleanup(function()
			added:Disconnect()
			removed:Disconnect()
			for _, connection in watched do
				connection:Disconnect()
			end
		end)
		Reactive.untrack(check)
	end)
	return function(): boolean
		return shown()
	end
end

return useHasVisibleChild
