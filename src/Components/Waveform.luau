--!strict
--[[
	Waveform

	A row of columns, one per level: a song's loudness, an equaliser, a meter. Columns before
	`progress` are lit, the rest dim, so it doubles as a song's scrubber.

		Waveform.new({
			id = "song",
			levels = { 0.2, 0.9, 0.6 },  -- an array, a ref or a getter; one per column, 0 up, drawn
			                             -- against the loudest
			progress = 0.5,              -- state; 0 to 1, columns before it lit (default 1)
			variant = "bars",            -- state; bars | blocks | dots
			align = "bottom",            -- bottom | center (mirrored about the middle)
			cells = 12,                  -- blocks and dots: cells in a full column
			color = "$Primary",          -- a token, a Color3, or fn(column) returning one
			gradient = nil,              -- { bottom, top } tokens or Color3s: colour by height
			stops = nil,                 -- { { 0, "$Primary" }, { 0.5, "$Pink500" } }: colour along the
			                             -- width, blended between stops (in place of color)
			fade = 0,                    -- 0 to 1: how far cells fade out towards the top (or both
			                             -- edges when centred); 0 keeps them solid
			trail = 0,                   -- 0 to 1: a glow over the columns just behind the progress,
			                             -- this share of the width, so playing reads as moving
			track = false,               -- blocks and dots: the unlit cells too, faintly
			peaks = false,               -- a cap above each column
			stretch = false,             -- heights from just under the quietest level to the
			                             -- loudest, curved (loud mastered music otherwise looks flat)
			gap = 2,                     -- pixels between columns and between cells
			renderer = "auto",           -- auto | canvas | frames
			onSeek = fn(fraction),       -- a press or drag on it, 0 to 1 across; nil lets
			                             -- clicks through
		})

	Drawing: on a canvas (two EditableImages, the dim columns and the lit ones, the lit one
	clipped to the progress) when the device can make one, else with Frames (at most
	FRAME_COLUMNS columns and FRAME_CELLS cells, averaged down). A canvas is drawn again only
	when the levels, colours, theme or size change; playing only moves the clip. Live games need
	"Allow Mesh / Image APIs" on for the canvas; without it they get the Frames.

	With trail, a third canvas holds a lighter copy of the lit drawing (glow), shown only over the
	trail by a gradient (glowFade) that playing moves; with Frames the columns in the trail are
	lightened.

	Handle: mode ("canvas" | "frames"); canvas: lit, dim, glow? (the EditableImages), clip,
	glowFade?; frames: columns[i] = { bar?, cells, peak? }.
]]

local AssetService = game:GetService("AssetService")
local UserInputService = game:GetService("UserInputService")

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Waveform = {}

Waveform.variants = { "bars", "blocks", "dots" }

local MIN_SHARE = 0.06 -- the quietest column's height, so silence still shows
local FLOOR = 0.85 -- stretch: heights start just under the quietest level
local CURVE = 1.4 -- stretch: loud parts stand out
local DIM = 0.6 -- transparency of columns not yet played
local GLOW = 0.55 -- how far the trail lightens a colour towards white
local TRACK = 0.88 -- transparency of unlit cells with track
local PEAK = 2 -- a peak cap's thickness in pixels
local MAX_CANVAS = 1024 -- Roblox's largest EditableImage side
local RESOLUTION = 2 -- canvas pixels per screen pixel, so small dots stay round
local FRAME_COLUMNS = 64
local FRAME_CELLS = 12

local function checkVariant(variant: string)
	if not table.find(Waveform.variants, variant) then
		error(
			`[Lucy] unknown Waveform variant "{variant}" (expected {table.concat(Waveform.variants, ", ")})`,
			0
		)
	end
end

-- Each level as a share of the full height, 0 to 1 (see stretch)
function Waveform.heights(levels: { number }, stretch: boolean): { number }
	local loudest, quietest = 0, math.huge
	for _, v in levels do
		loudest = math.max(loudest, v)
		quietest = math.min(quietest, v)
	end
	local low = if stretch and quietest < math.huge then quietest * FLOOR else 0
	local range = loudest - low
	local out = table.create(#levels, MIN_SHARE)
	for index, v in levels do
		local share = if range > 0 then (v - low) / range else 0
		if stretch then
			share = share ^ CURVE
		end
		out[index] = math.max(MIN_SHARE, share)
	end
	return out
end

-- How many of `cells` a share lights: at least one
function Waveform.litCells(share: number, cells: number): number
	return math.clamp(math.ceil(share * cells - 1e-6), 1, cells)
end

-- 0 to 1 across `frame` at screen x
function Waveform.fractionAt(frame: GuiObject, x: number): number
	if frame.AbsoluteSize.X <= 0 then
		return 0
	end
	return math.clamp((x - frame.AbsolutePosition.X) / frame.AbsoluteSize.X, 0, 1)
end

-- The glow's transparency across the width: shown from `trail` behind `progress` (clear) up to
-- `progress` (solid), hidden elsewhere
function Waveform.trailFade(progress: number, trail: number): NumberSequence
	local at = math.clamp(progress, 0.002, 0.998)
	local from = math.max(0.001, at - math.max(trail, 0.001))
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(from, 1),
		NumberSequenceKeypoint.new(at, 0),
		NumberSequenceKeypoint.new(math.min(0.999, at + 0.001), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- A blank canvas, or nil when the device cannot make one (memory budget, or image APIs off).
-- Specs swap it.
function Waveform._createCanvas(size: Vector2): EditableImage?
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = size })
	end)
	return if ok then image else nil
end

-- `levels` averaged down to at most `count` columns
local function shrink(levels: { number }, count: number): { number }
	if #levels <= count then
		return levels
	end
	local out = table.create(count, 0)
	local per = #levels / count
	for column = 1, count do
		local first = math.floor((column - 1) * per) + 1
		local last = math.max(first, math.floor(column * per))
		local sum = 0
		for index = first, last do
			sum += levels[index]
		end
		out[column] = sum / (last - first + 1)
	end
	return out
end

-- Whether cell `row` (1 at the bottom) of `cells` is lit with `lit` lit, and how far up the
-- colour runs (0 at the bottom or the middle, 1 at the edge)
local function cellState(row: number, cells: number, lit: number, centred: boolean): (boolean, number)
	if centred then
		local middle = (cells + 1) / 2
		local away = math.abs(row - middle)
		local reach = math.max(0.5, middle - 1)
		return away <= (lit - 1) / 2 + 1e-6, math.clamp(away / reach, 0, 1)
	end
	return row <= lit, if cells > 1 then (row - 1) / (cells - 1) else 0
end

local spec: Component.Spec = {
	kind = "waveform",
	-- levels stay out of state, as a Table's rows do: state merges arrays in place
	defaults = { progress = 1, variant = "bars", visible = true },
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		checkVariant(h:get("variant"))
		local progressRef, variantRef = h:ref("progress"), h:ref("variant")
		local function levelsRef(): { number }
			return Reactive.toValue(p.levels) or {}
		end
		local centred = p.align == "center"
		local cellCount: number = p.cells or 12
		local gap: number = p.gap or 2
		local renderer: string = p.renderer or "auto"
		local fade: number = math.clamp(p.fade or 0, 0, 1)
		local trail: number = math.clamp(p.trail or 0, 0, 1)
		local WHITE = Color3.new(1, 1, 1)
		-- A transparency with the fade at height t (0 bottom or middle, 1 edge) on top of it
		local function faded(base: number, t: number): number
			return 1 - (1 - base) * (1 - fade * t)
		end

		-- Colours, resolved from the theme now (a token, a Color3 or a function of the column)
		local themeTick = Reactive.ref(0)
		local function resolve(value: any): Color3
			if typeof(value) == "Color3" then
				return value
			end
			local name = if type(value) == "string" then string.gsub(value, "^%$", "") else "Primary"
			local resolved = app.theme:resolve(name)
			return if typeof(resolved) == "Color3" then resolved else Color3.new(1, 1, 1)
		end
		-- Columns drawn, for stops (each column's colour is the blend at its middle)
		local columnCount = 1
		local function columnColour(index: number): Color3
			local stops = p.stops
			if stops and #stops > 0 then
				local at = (index - 0.5) / columnCount
				if at <= stops[1][1] then
					return resolve(stops[1][2])
				end
				for i = 2, #stops do
					local from, to = stops[i - 1], stops[i]
					if at <= to[1] then
						local span = to[1] - from[1]
						local t = if span > 0 then (at - from[1]) / span else 1
						return resolve(from[2]):Lerp(resolve(to[2]), t)
					end
				end
				return resolve(stops[#stops][2])
			end
			local c = p.color
			if type(c) == "function" then
				return resolve(c(index))
			end
			return resolve(c or "$Primary")
		end
		local function cellColour(index: number, height: number): Color3
			local g = p.gradient
			if g then
				return resolve(g[1]):Lerp(resolve(g[2]), height)
			end
			return columnColour(index)
		end

		local root = Element.new("Frame", {
			Name = "Waveform",
			BackgroundTransparency = 1,
			Size = p.size or (if p.height then UDim2.new(1, 0, 0, p.height) else UDim2.fromScale(1, 1)),
			Visible = h:ref("visible"),
			Tags = { "ui-waveform" },
		}) :: Frame

		h.mode = nil
		h.columns = {}

		-- Canvas -----------------------------------------------------------------------------

		-- The two pictures' labels exist from the start (hidden while drawing with Frames), so
		-- the waveform has its shape before the first drawing
		local dimLabel, litLabel, clip
		if renderer ~= "frames" then
			dimLabel = Instance.new("ImageLabel")
			dimLabel.Name = "Dim"
			dimLabel.BackgroundTransparency = 1
			dimLabel.Size = UDim2.fromScale(1, 1)
			dimLabel.Parent = root
			clip = Instance.new("Frame")
			clip.Name = "Lit"
			clip.BackgroundTransparency = 1
			clip.ClipsDescendants = true
			clip.Size = UDim2.fromScale(0, 1) -- applyProgress sets it after each drawing
			clip.Parent = root
			h.clip = clip
			litLabel = Instance.new("ImageLabel")
			litLabel.Name = "Image"
			litLabel.BackgroundTransparency = 1
			litLabel.Size = UDim2.fromScale(1, 1)
			litLabel.Parent = clip
		end
		local glowLabel: ImageLabel? = nil
		if renderer ~= "frames" and trail > 0 then
			local label = Instance.new("ImageLabel")
			label.Name = "Glow"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.ZIndex = 2
			label.Parent = root
			local gradient = Instance.new("UIGradient")
			gradient.Name = "Fade"
			gradient.Transparency = NumberSequence.new(1)
			gradient.Parent = label
			h.glowFade = gradient
			glowLabel = label
		end
		local function ensureCanvas(size: Vector2): boolean
			if h.lit and h.lit.Size == size then
				return true
			end
			local dim = Waveform._createCanvas(size)
			local lit = dim and Waveform._createCanvas(size)
			local glow = if lit and glowLabel then Waveform._createCanvas(size) else nil
			if not (dim and lit) or (glowLabel and not glow) then
				for _, image in { dim, lit, glow } do
					if image then
						image:Destroy()
					end
				end
				return false
			end
			if h.lit then
				h.lit:Destroy()
				h.dim:Destroy()
				if h.glow then
					h.glow:Destroy()
				end
			end
			h.dim, h.lit, h.glow = dim, lit, glow
			if glowLabel and glow then
				glowLabel.Visible = true
				glowLabel.ImageContent = Content.fromObject(glow)
			end
			dimLabel.Visible = true
			clip.Visible = true
			dimLabel.ImageContent = Content.fromObject(dim)
			litLabel.ImageContent = Content.fromObject(lit)
			return true
		end

		-- Gaps and caps are given in screen pixels; the canvas is RESOLUTION times as fine
		local function drawCanvas(levels: { number }, variant: string)
			local gap = gap * RESOLUTION
			local PEAK = PEAK * RESOLUTION
			local width = math.clamp(math.floor(root.AbsoluteSize.X * RESOLUTION), 1, MAX_CANVAS)
			local height = math.clamp(math.floor(root.AbsoluteSize.Y * RESOLUTION), 1, MAX_CANVAS)
			if not ensureCanvas(Vector2.new(width, height)) then
				return false
			end
			local dim = h.dim :: EditableImage
			local litImage = h.lit :: EditableImage
			local glowImage: EditableImage? = h.glow
			-- With trail, what is drawn lit is drawn on the glow too, lighter
			local lit: any = litImage
			if glowImage then
				lit = {
					DrawRectangle = function(
						_,
						at: Vector2,
						size: Vector2,
						colour: Color3,
						t: number,
						how: any
					)
						litImage:DrawRectangle(at, size, colour, t, how)
						glowImage:DrawRectangle(at, size, colour:Lerp(WHITE, GLOW), t, how)
					end,
					DrawCircle = function(
						_,
						at: Vector2,
						radius: number,
						colour: Color3,
						t: number,
						how: any
					)
						litImage:DrawCircle(at, radius, colour, t, how)
						glowImage:DrawCircle(at, radius, colour:Lerp(WHITE, GLOW), t, how)
					end,
				}
			end
			local full = Vector2.new(width, height)
			local overwrite = Enum.ImageCombineType.Overwrite
			dim:DrawRectangle(Vector2.zero, full, Color3.new(), 1, overwrite)
			lit:DrawRectangle(Vector2.zero, full, Color3.new(), 1, overwrite)
			local count = #levels
			if count == 0 then
				return true
			end
			columnCount = count
			local shares = Waveform.heights(levels, p.stretch == true)
			local columnWidth = width / count
			local function rect(
				image: any,
				x: number,
				y: number,
				w: number,
				hh: number,
				colour: Color3,
				t: number
			)
				local x0, y0 =
					math.clamp(math.floor(x), 0, width - 1), math.clamp(math.floor(y), 0, height - 1)
				local x1, y1 =
					math.clamp(math.floor(x + w), x0 + 1, width),
					math.clamp(math.floor(y + hh), y0 + 1, height)
				image:DrawRectangle(
					Vector2.new(x0, y0),
					Vector2.new(x1 - x0, y1 - y0),
					colour,
					t,
					Enum.ImageCombineType.BlendSourceOver
				)
			end
			for index, share in shares do
				local x = (index - 1) * columnWidth + gap / 2
				local w = math.max(1, columnWidth - gap)
				if variant == "bars" then
					-- Drawn in two pixel strips so a gradient can run up it
					local barHeight = math.max(1, share * height)
					local top = if centred then (height - barHeight) / 2 else height - barHeight
					local strip = if p.gradient or fade > 0 then 2 else barHeight
					local y = top
					while y < top + barHeight do
						local t = if centred
							then math.abs((y + strip / 2) - height / 2) / (height / 2)
							else (height - (y + strip / 2)) / height
						local colour = cellColour(index, math.clamp(t, 0, 1))
						t = math.clamp(t, 0, 1)
						rect(dim, x, y, w, strip, colour, faded(DIM, t))
						rect(lit, x, y, w, strip, colour, faded(0, t))
						y += strip
					end
					if p.peaks then
						rect(
							lit,
							x,
							math.max(0, top - gap - PEAK),
							w,
							PEAK,
							cellColour(index, 1),
							faded(0, 1)
						)
						rect(
							dim,
							x,
							math.max(0, top - gap - PEAK),
							w,
							PEAK,
							cellColour(index, 1),
							faded(DIM, 1)
						)
					end
				else
					local cellHeight = height / cellCount
					local lit_ = Waveform.litCells(share, cellCount)
					local topLit = height
					for row = 1, cellCount do
						local on, t = cellState(row, cellCount, lit_, centred)
						local y = height - row * cellHeight + gap / 2
						local hh = math.max(1, cellHeight - gap)
						local colour = cellColour(index, t)
						if on then
							topLit = math.min(topLit, y)
						end
						if variant == "dots" then
							local radius = math.max(1, math.min(w, hh) / 2)
							local centre = Vector2.new(math.floor(x + w / 2), math.floor(y + hh / 2))
							if on then
								lit:DrawCircle(
									centre,
									radius,
									colour,
									faded(0, t),
									Enum.ImageCombineType.BlendSourceOver
								)
								dim:DrawCircle(
									centre,
									radius,
									colour,
									faded(DIM, t),
									Enum.ImageCombineType.BlendSourceOver
								)
							elseif p.track then
								dim:DrawCircle(
									centre,
									radius,
									colour,
									faded(TRACK, t),
									Enum.ImageCombineType.BlendSourceOver
								)
							end
						else
							if on then
								rect(lit, x, y, w, hh, colour, faded(0, t))
								rect(dim, x, y, w, hh, colour, faded(DIM, t))
							elseif p.track then
								rect(dim, x, y, w, hh, colour, faded(TRACK, t))
							end
						end
					end
					if p.peaks and not centred then
						local y = math.max(0, topLit - cellHeight)
						rect(
							lit,
							x,
							y + cellHeight - gap / 2 - PEAK,
							w,
							PEAK,
							cellColour(index, 1),
							faded(0, 1)
						)
						rect(
							dim,
							x,
							y + cellHeight - gap / 2 - PEAK,
							w,
							PEAK,
							cellColour(index, 1),
							faded(DIM, 1)
						)
					end
				end
			end
			return true
		end

		-- Frames -----------------------------------------------------------------------------

		local framesRoot: Frame? = nil
		local function frame(name: string, parent: Instance): Frame
			local f = Instance.new("Frame")
			f.Name = name
			f.BorderSizePixel = 0
			f.Parent = parent
			return f
		end

		local function drawFrames(levels: { number }, variant: string)
			if framesRoot then
				framesRoot:Destroy()
			end
			local holder = frame("Columns", root)
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			framesRoot = holder
			local shown = shrink(levels, FRAME_COLUMNS)
			local cells = math.min(cellCount, FRAME_CELLS)
			local shares = Waveform.heights(shown, p.stretch == true)
			local count = #shown
			columnCount = math.max(1, count)
			local columns = {}
			for index, share in shares do
				local column = frame(`Column{index}`, holder)
				column.BackgroundTransparency = 1
				column.Position = UDim2.fromScale((index - 1) / count, 0)
				column.Size = UDim2.new(1 / count, -gap, 1, 0)
				local entry: { [string]: any } = { cells = {}, column = column }
				if variant == "bars" then
					local bar = frame("Bar", column)
					bar.AnchorPoint = Vector2.new(0, if centred then 0.5 else 1)
					bar.Position = UDim2.fromScale(0, if centred then 0.5 else 1)
					bar.Size = UDim2.fromScale(1, share)
					bar.BackgroundColor3 = cellColour(index, 0)
					bar:SetAttribute("colour", bar.BackgroundColor3)
					if p.gradient or fade > 0 then
						local g = Instance.new("UIGradient")
						g.Rotation = -90
						if p.gradient then
							g.Color = ColorSequence.new(resolve(p.gradient[1]), resolve(p.gradient[2]))
							bar.BackgroundColor3 = Color3.new(1, 1, 1)
						end
						-- The bar's top is `share` up the column, so it fades that far
						local edge = fade * share
						g.Transparency = if centred
							then NumberSequence.new({
								NumberSequenceKeypoint.new(0, edge),
								NumberSequenceKeypoint.new(0.5, 0),
								NumberSequenceKeypoint.new(1, edge),
							})
							else NumberSequence.new(0, edge)
						g.Parent = bar
					end
					entry.bar = bar
					entry.cells = { bar }
				else
					local lit = Waveform.litCells(share, cells)
					for row = 1, cells do
						local on, t = cellState(row, cells, lit, centred)
						local cell = frame(`Cell{row}`, column)
						cell.Position = UDim2.new(0, 0, 1 - row / cells, gap / 2)
						cell.Size = UDim2.new(1, 0, 1 / cells, -gap)
						cell.BackgroundColor3 = cellColour(index, t)
						cell:SetAttribute("colour", cell.BackgroundColor3)
						cell.Visible = on or p.track == true
						cell:SetAttribute("lit", on)
						cell:SetAttribute("height", t)
						if variant == "dots" then
							cell.SizeConstraint = Enum.SizeConstraint.RelativeXX
							local corner = Instance.new("UICorner")
							corner.CornerRadius = UDim.new(1, 0)
							corner.Parent = cell
							local aspect = Instance.new("UIAspectRatioConstraint")
							aspect.Parent = cell
						end
						entry.cells[row] = cell
					end
				end
				if p.peaks then
					local peak = frame("Peak", column)
					peak.AnchorPoint = Vector2.new(0, 1)
					peak.Position = UDim2.new(0, 0, 1 - share, -gap)
					peak.Size = UDim2.new(1, 0, 0, PEAK)
					peak.BackgroundColor3 = cellColour(index, 1)
					entry.peak = peak
				end
				columns[index] = entry
			end
			h.columns = columns
		end

		-- Lights the columns before the progress (frames) or moves the clip (canvas)
		local function applyProgress(progress: number)
			progress = math.clamp(progress, 0, 1)
			if h.mode == "canvas" then
				if clip then
					-- The lit image as wide as the whole waveform: a share of the clip, so it
					-- follows any layout
					clip.Size = UDim2.fromScale(progress, 1)
					litLabel.Size = UDim2.fromScale(if progress > 0 then 1 / progress else 1, 1)
				end
				if h.glowFade then
					h.glowFade.Transparency = Waveform.trailFade(progress, trail)
				end
				return
			end
			local count = #h.columns
			for index, entry in h.columns do
				local middle = (index - 0.5) / count
				local played = middle <= progress
				-- In the trail: lightened, most at the progress
				local glow = if trail > 0
						and played
						and progress - middle <= trail
					then GLOW * (1 - (progress - middle) / trail)
					else 0
				for _, cell in entry.cells do
					local own = cell:GetAttribute("colour") :: Color3?
					if own then
						cell.BackgroundColor3 = if glow > 0 then own:Lerp(WHITE, glow) else own
					end
					local on = cell:GetAttribute("lit") ~= false
					local t = (cell:GetAttribute("height") :: number?) or 0
					local base = if not on then TRACK elseif played then 0 else DIM
					cell.BackgroundTransparency = faded(base, t)
				end
				if entry.peak then
					entry.peak.BackgroundTransparency = faded(if played then 0 else DIM, 1)
				end
			end
		end

		-- Draws on the levels, the variant, the theme and the size; colour functions read
		-- inside are followed too
		local sizeTick = Reactive.ref(0)
		Reactive.watchEffect(function()
			local levels = levelsRef() or {}
			local variant = variantRef()
			themeTick()
			sizeTick()
			checkVariant(variant)
			local drawn = false
			if renderer ~= "frames" and root.AbsoluteSize.X > 0 then
				drawn = drawCanvas(levels, variant)
				if drawn and framesRoot then
					framesRoot:Destroy()
					framesRoot = nil
					h.columns = {}
				end
			end
			if drawn then
				h.mode = "canvas"
			elseif renderer ~= "frames" and root.AbsoluteSize.X == 0 then
				h.mode = nil -- a canvas waits for a size
				return
			else
				h.mode = "frames"
				if dimLabel then
					dimLabel.Visible = false
					clip.Visible = false
				end
				if glowLabel then
					glowLabel.Visible = false
				end
				drawFrames(levels, variant)
			end
			Reactive.untrack(function()
				applyProgress(progressRef())
			end)
		end)
		Reactive.watch(progressRef, function(progress: number)
			applyProgress(progress)
		end)

		local sizeConn = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			task.defer(function()
				if h.mode ~= "frames" or (renderer ~= "frames" and h.lit == nil) then
					sizeTick(sizeTick() + 1)
				end
			end)
		end)
		local themeConn = app.theme.Changed:Connect(function()
			themeTick(themeTick() + 1)
		end)
		Reactive.onCleanup(function()
			sizeConn:Disconnect()
			themeConn:Disconnect()
			if h.lit then
				h.lit:Destroy()
				h.dim:Destroy()
			end
			if h.glow then
				h.glow:Destroy()
			end
		end)

		-- A press or drag seeks
		local onSeek = p.onSeek
		if onSeek then
			local hit = Instance.new("TextButton")
			hit.Name = "Seek"
			hit.Text = ""
			hit.AutoButtonColor = false
			hit.Selectable = false
			hit.BackgroundTransparency = 1
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 3
			hit.Parent = root
			h.seek = hit
			local dragging = false
			local function isPointer(input: InputObject): boolean
				local kind = input.UserInputType
				return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
			end
			local connections = {
				hit.InputBegan:Connect(function(input: InputObject)
					if isPointer(input) then
						dragging = true
						onSeek(Waveform.fractionAt(root, input.Position.X))
					end
				end),
				UserInputService.InputChanged:Connect(function(input: InputObject)
					local kind = input.UserInputType
					if
						dragging
						and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch)
					then
						onSeek(Waveform.fractionAt(root, input.Position.X))
					end
				end),
				UserInputService.InputEnded:Connect(function(input: InputObject)
					if isPointer(input) then
						dragging = false
					end
				end),
			}
			Reactive.onCleanup(function()
				for _, c in connections do
					c:Disconnect()
				end
			end)
		end

		return root
	end,
}

function Waveform.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Waveform
