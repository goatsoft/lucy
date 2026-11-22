--!strict
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Scroll = require(script.Parent.Parent.Core.Scroll)
local requireOwner = require(script.Parent.requireOwner)

--[[
	Whether `target` has come near what the scroll area around it shows: false until the first
	time it is shown and within a view of the visible part (Scroll.whenNear), true from then on.
	For building something heavy only once the player scrolls to it, in a layout that is not a
	Stack (a Stack does this itself with mount = "intersect"):

		local cell = Lucy.ref(nil)
		local reached = Lucy.useIntersect(cell)
		Lucy.new "Frame" {
			Size = UDim2.fromOffset(120, 160),      -- the room it holds until it is built
			[Lucy.instance] = cell,
			Lucy.show(reached, buildCard),
		}

	`target` is an Instance, a handle, or a ref or getter of one (nil until it exists). It needs
	a size of its own before it is built. options.enabled (a ref, getter or value): nothing is
	looked at while it is false, for a list that is about to be scrolled somewhere else.
	options.overscan: how many views beyond each edge count as near (Scroll.overscan, 1).

	Connecting to the engine's layout signals is the side effect here, so it is an effect.
]]
local function useIntersect(
	target: any,
	options: { enabled: Reactive.MaybeRef<boolean>?, overscan: number? }?
): () -> boolean
	requireOwner("useIntersect")
	local reached = Reactive.ref(false)
	local enabled: any = options and options.enabled
	local overscan = options and options.overscan
	Reactive.watchEffect(function(onCleanup)
		if Reactive.peek(reached) then
			return
		end
		if enabled ~= nil and not Reactive.toValue(enabled) then
			return
		end
		local object: any = Reactive.toValue(target)
		if type(object) == "table" then
			object = object.Instance
		end
		if typeof(object) ~= "Instance" then
			return
		end
		onCleanup(Scroll.whenNear(object :: GuiObject, function()
			reached(true)
		end, overscan))
	end)
	return function(): boolean
		return reached()
	end
end

return useIntersect
