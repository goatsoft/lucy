--!strict
--[[
	Floating (ADR 0057): places floating content beside a reference, on screen or in the world.
	Internal: Tooltip and Prompt use it; games use those components.

		local floating = Floating.use(app, {
			reference = button,       -- GuiObject | BasePart | Attachment | Model | handle | id
			content = frame,
			open = openRef,
			placement = "top",        -- side[-align], or side + align
			side = "top",             -- top | bottom | left | right | auto
			align = "center",         -- start | center | end
			sideOffset = 8,           -- pixels on screen (alias: offset)
			alignOffset = 0,          -- pixels along the alignment edge
			studsOffset = 0.5,        -- studs from the edge of a part in the world
			avoidCollisions = true,   -- flip and shift to stay on screen
			flip = true,
			shift = true,
			collisionPadding = 8,     -- screen edge margin (alias: padding)
			arrow = 10,               -- arrow size in pixels, for arrowOffset() and arrowCenter()
			arrowPadding = 6,         -- room left at rounded corners for the arrow
			maxDistance = nil,        -- world billboard MaxDistance
			alwaysOnTop = true,       -- world billboard AlwaysOnTop
		})
		floating.side()               -- side after flipping (tracked)
		floating.arrowOffset()        -- offset from the near corner in pixels (tracked)
		floating.arrowCenter()        -- offset from the near edge's centre in pixels (tracked)
		floating.visible()            -- whether it is shown (tracked)
		floating.place()              -- place again
]]

local GuiService = game:GetService("GuiService")

local Overlay = require(script.Parent.Overlay)
local Reactive = require(script.Parent.Reactive)
local World = require(script.Parent.World)

local Floating = {}

Floating.sides = { "top", "bottom", "left", "right" }
Floating.aligns = { "start", "center", "end" }
Floating.offset = 8
Floating.padding = 8
Floating.arrowPadding = 6
Floating.studsGap = 0.5

export type Rect = Overlay.Rect

export type ComputeInput = {
	view: Vector2,
	content: Vector2,
	reference: Rect,
	side: string?,
	align: string?,
	offset: number?,
	sideOffset: number?,
	alignOffset: number?,
	avoidCollisions: boolean?,
	flip: boolean?,
	shift: boolean?,
	padding: number?,
	collisionPadding: number?,
	top: number?,
	arrow: number?,
	arrowPadding: number?,
}

export type Computed = {
	position: Vector2,
	side: string,
	arrow: number,
	arrowCenter: number,
}

local function round(n: number): number
	return math.floor(n + 0.5)
end

local function checkSide(side: string, allowAuto: boolean?)
	if allowAuto and side == "auto" then
		return
	end
	if not table.find(Floating.sides, side) then
		error(`[Lucy] unknown Floating side "{tostring(side)}"`, 0)
	end
end

local function checkAlign(align: string)
	if not table.find(Floating.aligns, align) then
		error(`[Lucy] unknown Floating align "{tostring(align)}"`, 0)
	end
end

-- Splits a placement string like "top-start" into side and align.
function Floating.parsePlacement(placement: string?, side: string?, align: string?): (string, string)
	if type(placement) == "string" and placement ~= "" then
		local dash = string.find(placement, "-", 1, true)
		if dash then
			return string.sub(placement, 1, dash - 1), string.sub(placement, dash + 1)
		end
		return placement, align or "center"
	end
	return side or "top", align or "center"
end

-- Pure screen placement: side, align, offset, flip, shift and arrow offset along the edge.
function Floating.compute(input: ComputeInput): Computed
	local view = input.view
	local content = input.content
	local ref = input.reference
	local side = input.side or "top"
	local align = input.align or "center"
	checkSide(side, true)
	checkAlign(align)

	local offset = if input.sideOffset ~= nil
		then input.sideOffset
		elseif input.offset ~= nil then input.offset
		else Floating.offset
	local alignOffset = input.alignOffset or 0
	local avoid = input.avoidCollisions ~= false
	local doFlip = if input.flip ~= nil then input.flip else avoid
	local doShift = if input.shift ~= nil then input.shift else avoid
	local padding = if input.collisionPadding ~= nil
		then input.collisionPadding
		elseif input.padding ~= nil then input.padding
		else Floating.padding
	local top = math.max(0, input.top or 0)

	local refTop = ref.position.Y
	local refBottom = refTop + ref.size.Y
	local refLeft = ref.position.X
	local refRight = refLeft + ref.size.X

	local above = refTop - offset - padding - top
	local below = view.Y - refBottom - offset - padding
	local toLeft = refLeft - offset - padding
	local toRight = view.X - refRight - offset - padding

	if side == "auto" then
		if content.Y <= above then
			side = "top"
		elseif content.Y <= below then
			side = "bottom"
		elseif content.X <= toRight then
			side = "right"
		elseif content.X <= toLeft then
			side = "left"
		else
			side = if above >= below then "top" else "bottom"
		end
	elseif doFlip then
		if side == "top" and content.Y > above and below > above then
			side = "bottom"
		elseif side == "bottom" and content.Y > below and above > below then
			side = "top"
		elseif side == "left" and content.X > toLeft and toRight > toLeft then
			side = "right"
		elseif side == "right" and content.X > toRight and toLeft > toRight then
			side = "left"
		end
	end

	local arrowSize = input.arrow or 0
	local arrowPad = if input.arrowPadding ~= nil then input.arrowPadding else Floating.arrowPadding

	if side == "left" or side == "right" then
		local x = if side == "left" then refLeft - content.X - offset else refRight + offset
		local y: number
		if align == "start" then
			y = refTop
		elseif align == "end" then
			y = refBottom - content.Y
		else
			y = refTop + (ref.size.Y - content.Y) / 2
		end
		y += alignOffset
		if doShift then
			y = math.clamp(y, padding + top, math.max(padding + top, view.Y - content.Y - padding))
		end
		local minArrow = arrowPad + arrowSize / 2
		local maxArrow = math.max(minArrow, content.Y - arrowPad - arrowSize / 2)
		local refCenterY = refTop + ref.size.Y / 2
		local arrow = math.clamp(refCenterY - y, minArrow, maxArrow)
		local floatingCenterY = y + content.Y / 2
		local maxCenter = math.max(0, content.Y / 2 - minArrow)
		local arrowCenter = math.clamp(refCenterY - floatingCenterY, -maxCenter, maxCenter)
		return {
			position = Vector2.new(round(x), round(y)),
			side = side,
			arrow = round(arrow),
			arrowCenter = round(arrowCenter),
		}
	end

	local y = if side == "top" then refTop - content.Y - offset else refBottom + offset
	local x: number
	if align == "start" then
		x = refLeft
	elseif align == "end" then
		x = refRight - content.X
	else
		x = refLeft + (ref.size.X - content.X) / 2
	end
	x += alignOffset
	if doShift then
		x = math.clamp(x, padding, math.max(padding, view.X - content.X - padding))
	end
	local minArrow = arrowPad + arrowSize / 2
	local maxArrow = math.max(minArrow, content.X - arrowPad - arrowSize / 2)
	local refCenterX = refLeft + ref.size.X / 2
	local arrow = math.clamp(refCenterX - x, minArrow, maxArrow)
	local floatingCenterX = x + content.X / 2
	local maxCenter = math.max(0, content.X / 2 - minArrow)
	local arrowCenter = math.clamp(refCenterX - floatingCenterX, -maxCenter, maxCenter)
	return {
		position = Vector2.new(round(x), round(y)),
		side = side,
		arrow = round(arrow),
		arrowCenter = round(arrowCenter),
	}
end

-- World offset from a part's centre and BillboardGui SizeOffset for a side.
function Floating.worldOffset(side: string, partSize: Vector3, gap: number?): (Vector3, Vector2)
	checkSide(side, false)
	local g = if gap ~= nil then gap else 0
	if side == "bottom" then
		return Vector3.new(0, -(partSize.Y / 2 + g), 0), Vector2.new(0, -0.5)
	elseif side == "left" then
		return Vector3.new(-(partSize.X / 2 + g), 0, 0), Vector2.new(-0.5, 0)
	elseif side == "right" then
		return Vector3.new(partSize.X / 2 + g, 0, 0), Vector2.new(0.5, 0)
	end
	return Vector3.new(0, partSize.Y / 2 + g, 0), Vector2.new(0, 0.5)
end

local WORLD_ANCHOR: { [string]: { anchor: Vector2, pos: UDim2 } } = {
	top = { anchor = Vector2.new(0.5, 1), pos = UDim2.fromScale(0.5, 1) },
	bottom = { anchor = Vector2.new(0.5, 0), pos = UDim2.fromScale(0.5, 0) },
	left = { anchor = Vector2.new(1, 0.5), pos = UDim2.fromScale(1, 0.5) },
	right = { anchor = Vector2.new(0, 0.5), pos = UDim2.fromScale(0, 0.5) },
}

local function resolveTarget(app: any, reference: any): Instance?
	local target = reference
	if type(target) == "function" then
		target = target()
	end
	if type(target) == "string" and app and app.handle then
		local handle = app:handle(target)
		target = if handle and not handle.destroyed then handle.Instance else nil
	elseif type(target) == "table" and target.Instance then
		target = target.Instance
	end
	if typeof(target) == "Instance" then
		return target
	end
	return nil
end

local function isWorldTarget(target: Instance?): boolean
	return target ~= nil and (target:IsA("BasePart") or target:IsA("Attachment") or target:IsA("Model"))
end

local function worldAdornee(target: Instance): (Instance?, Vector3)
	if target:IsA("BasePart") then
		return target, target.Size
	elseif target:IsA("Attachment") then
		return target, Vector3.zero
	elseif target:IsA("Model") then
		local adornee: Instance? = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		local _, size = target:GetBoundingBox()
		return adornee, size
	end
	return nil, Vector3.zero
end

export type FloatingHandle = {
	world: boolean,
	gui: BillboardGui?,
	overlay: Overlay.Overlay?,
	side: () -> string,
	arrowOffset: () -> number,
	arrowCenter: () -> number,
	visible: () -> boolean,
	place: () -> (),
}

function Floating.use(app: any, options: { [string]: any }): FloatingHandle
	if not Reactive._hasOwner() then
		error("[Lucy] Floating.use needs an owner: call it in a component's render or an effectScope", 2)
	end

	local open: Reactive.Ref<boolean> = options.open or Reactive.ref(false)
	local content: GuiObject = options.content
	local target = resolveTarget(app, options.reference)

	local initialSide, initialAlign = Floating.parsePlacement(
		Reactive.toValue(options.placement),
		Reactive.toValue(options.side),
		Reactive.toValue(options.align)
	)
	local resolvedSide = if initialSide == "auto" then "top" else initialSide
	checkSide(resolvedSide, false)
	checkAlign(initialAlign)

	local sideRef = Reactive.ref(resolvedSide)
	local arrowRef = Reactive.ref(0)
	local arrowCenterRef = Reactive.ref(0)

	if isWorldTarget(target) then
		local adornee, partSize = worldAdornee(target :: Instance)
		if adornee == nil then
			error("[Lucy] Floating world target needs a BasePart, Attachment, or Model with a part", 2)
		end

		local gap = if options.studsOffset ~= nil then options.studsOffset else Floating.studsGap
		local studsOffset, sizeOffset = Floating.worldOffset(resolvedSide, partSize, gap)
		local gui = World.billboard(app, options.name or "Floating", {
			adornee = adornee,
			size = options.size or UDim2.fromOffset(320, 160),
			studsOffset = studsOffset,
			alwaysOnTop = options.alwaysOnTop ~= false,
			maxDistance = options.maxDistance,
			enabled = (Reactive.peek(open) :: any) == true,
		})
		gui.SizeOffset = sizeOffset
		content.Parent = gui

		local function placeWorld()
			local s, _ = Floating.parsePlacement(
				Reactive.toValue(options.placement),
				Reactive.toValue(options.side),
				Reactive.toValue(options.align)
			)
			if s == "auto" then
				s = "top"
			end
			checkSide(s, false)
			local _, liveSize = worldAdornee(target :: Instance)
			local wOff, sOff = Floating.worldOffset(s, liveSize, Reactive.toValue(options.studsOffset) or gap)
			gui.StudsOffset = wOff
			gui.SizeOffset = sOff
			local anchorInfo = WORLD_ANCHOR[s] or WORLD_ANCHOR.top
			content.AnchorPoint = anchorInfo.anchor
			content.Position = anchorInfo.pos
			sideRef(s)
			local span = if s == "left" or s == "right"
				then content.AbsoluteSize.Y
				else content.AbsoluteSize.X
			arrowRef(round(span / 2))
			arrowCenterRef(0)
		end

		placeWorld()
		local sizeConn = content:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeWorld)

		Reactive.watch(open, function(isOpen)
			gui.Enabled = isOpen == true
		end, { immediate = true })

		if type(options.side) == "function" or type(options.placement) == "function" then
			Reactive.watch(function()
				return Floating.parsePlacement(
					Reactive.toValue(options.placement),
					Reactive.toValue(options.side),
					Reactive.toValue(options.align)
				)
			end, placeWorld)
		end

		Reactive.onCleanup(function()
			sizeConn:Disconnect()
			if gui.Parent ~= nil then
				gui:Destroy()
			end
		end)

		return {
			world = true,
			gui = gui,
			overlay = nil,
			side = function(): string
				return sideRef()
			end,
			arrowOffset = function(): number
				return arrowRef()
			end,
			arrowCenter = function(): number
				return arrowCenterRef()
			end,
			visible = function(): boolean
				return open() == true
			end,
			place = placeWorld,
		}
	end

	local overlay = Overlay.use(app, {
		open = open,
		content = content,
		presentation = "popup",
		anchor = options.reference,
		modal = false,
		scrim = false,
		dismissible = false,
		closeOnOutside = false,
		host = options.host,
		parent = options.parent,
		name = options.name or "Floating",
		tags = options.tags,
		place = function(_presentation: string, input: Overlay.PlaceInput): Overlay.Placement
			local wantedSide, wantedAlign = Floating.parsePlacement(
				Reactive.toValue(options.placement),
				Reactive.toValue(options.side),
				Reactive.toValue(options.align)
			)
			local anchorRect = input.anchor
			if anchorRect == nil then
				return {
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.fromOffset(round(input.view.X / 2), round(input.view.Y / 2)),
					maxHeight = input.view.Y,
					side = if wantedSide == "auto" then "top" else wantedSide,
				}
			end
			local computed = Floating.compute({
				view = input.view,
				content = input.content,
				reference = anchorRect,
				side = wantedSide,
				align = wantedAlign,
				offset = Reactive.toValue(options.offset),
				sideOffset = Reactive.toValue(options.sideOffset),
				alignOffset = Reactive.toValue(options.alignOffset),
				avoidCollisions = Reactive.toValue(options.avoidCollisions),
				flip = options.flip,
				shift = options.shift,
				padding = Reactive.toValue(options.padding),
				collisionPadding = Reactive.toValue(options.collisionPadding),
				top = input.top or math.max(0, GuiService.TopbarInset.Max.Y),
				arrow = Reactive.toValue(options.arrow),
				arrowPadding = Reactive.toValue(options.arrowPadding),
			})
			sideRef(computed.side)
			arrowRef(computed.arrow)
			arrowCenterRef(computed.arrowCenter)
			return {
				anchorPoint = Vector2.zero,
				position = UDim2.fromOffset(computed.position.X, computed.position.Y),
				maxHeight = input.view.Y,
				side = computed.side,
			}
		end,
	})

	for _, source in
		{
			options.side,
			options.align,
			options.offset,
			options.sideOffset,
			options.alignOffset,
			options.avoidCollisions,
			options.collisionPadding,
			options.placement,
			options.arrow,
			options.arrowPadding,
		}
	do
		if type(source) == "function" then
			Reactive.watch(source, function()
				overlay.place()
			end)
		end
	end

	return {
		world = false,
		gui = nil,
		overlay = overlay,
		side = function(): string
			return sideRef()
		end,
		arrowOffset = function(): number
			return arrowRef()
		end,
		arrowCenter = function(): number
			return arrowCenterRef()
		end,
		visible = overlay.visible,
		place = overlay.place,
	}
end

return Floating
