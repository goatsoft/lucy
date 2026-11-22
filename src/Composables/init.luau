--!strict
--[[
	Composables (ADR 0018): plain functions that create reactive state inside the
	current owner (a component's render, an effect, an effectScope) and return it.
	Everything they create stops with that owner. Called with no owner they error,
	since nothing would ever stop them.

		render = function(h)
			local density = Lucy.useDensity(h.app)               -- "default" | "touch" | "tv"
			local height = Lucy.useMetric(h.app, "ControlMd")     -- pixels, follows density
			Lucy.useBackHandler(h.app, open, function() h:close() return true end)
			Lucy.useFocusScope(h.app, open, { root = content })
			Lucy.useUiSound(h.app, { activate = playClick })     -- the game's own sounds
			local gap = Lucy.useResponsive(h.app, { touch = 16, default = 8 })
			local room = Lucy.useSize(body)                      -- room().Y: its height in the scene's units
			local scale = Lucy.useFit(row, { min = 0.5 })        -- scale(): 1, or less to fit the parent's width
			local visible = Lucy.useHasVisibleChild(slot)           -- visible(): a child of slot has Visible on
			local board = Lucy.useTable({ data = players, columns = columns })
			local dances = Lucy.useSort({ data = list, columns = columns, multi = true })  -- dances.items()
			Lucy.useWhile(open, function() return signal:Connect(onFire) end)  -- only while open
			local timer = Lucy.useCountdown(endsAt)              -- timer.remaining(), timer.done()
			local drag = Lucy.useDrag(handle, { onMove = move })  -- drag.dragging(), drag.delta()
			local typed = Lucy.useReveal(line, { rate = 34 })    -- typed.visible(): characters shown
			local xp = Lucy.useCount(xpRef, { seconds = 0.8 })   -- xp.value(): counting up to it
			local board = Lucy.useRequest(h.app, "boards.get", args) -- board.data(), board.loading()
			...
		end

	Write your own the same way: take refs or getters, return refs or computeds,
	and register any cleanup with Lucy.onCleanup.
]]

-- One module per composable, in this folder; this is their index (Lucy.use* come from here)
local useFocusZone = require(script.useFocusZone)
local useDrag = require(script.useDrag)
local useReveal = require(script.useReveal)
local useCount = require(script.useCount)
export type FocusZone = useFocusZone.FocusZone
export type DragOptions = useDrag.DragOptions
export type Drag = useDrag.Drag
export type Reveal = useReveal.Reveal
export type Count = useCount.Count

return {
	useDensity = require(script.useDensity),
	useMetric = require(script.useMetric),
	useResponsive = require(script.useResponsive),
	useSize = require(script.useSize),
	useFit = require(script.useFit),
	useHasVisibleChild = require(script.useHasVisibleChild),
	useBackHandler = require(script.useBackHandler),
	useFocusScope = require(script.useFocusScope),
	useFocusZone = useFocusZone,
	useHoldArrows = require(script.useHoldArrows),
	useUiSound = require(script.useUiSound),
	useSort = require(script.useSort),
	useTable = require(script.useTable),
	useWhile = require(script.useWhile),
	useCountdown = require(script.useCountdown),
	useDrag = useDrag,
	useReveal = useReveal,
	useCount = useCount,
	useRequest = require(script.useRequest),
	useIntersect = require(script.useIntersect),
}
