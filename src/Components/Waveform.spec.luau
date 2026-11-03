return function()
	local Waveform = require(script.Parent.Waveform)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Reactive = require(script.Parent.Parent.Core.Reactive)

	describe("heights", function()
		it("scales levels so the loudest is full", function()
			local h = Waveform.heights({ 0.5, 1, 0.25 }, false)
			expect(h[1]).to.equal(0.5)
			expect(h[2]).to.equal(1)
			expect(h[3]).to.equal(0.25)
		end)

		it("stretches loud music between its quietest and loudest", function()
			local h = Waveform.heights({ 0.6, 1, 0.8 }, true)
			expect(h[2]).to.equal(1)
			-- The quietest stays a little above nothing, the middle drops well below its share
			expect(h[1] > 0 and h[1] < 0.3).to.equal(true)
			expect(h[3] < 0.8).to.equal(true)
		end)

		it("keeps a floor so silence still shows", function()
			local h = Waveform.heights({ 0, 1 }, false)
			expect(h[1] > 0).to.equal(true)
		end)

		it("copes with nothing and with silence", function()
			expect(#Waveform.heights({}, true)).to.equal(0)
			local h = Waveform.heights({ 0, 0 }, true)
			expect(h[1] > 0).to.equal(true)
		end)
	end)

	it("lights the cells a height needs, at least one", function()
		expect(Waveform.litCells(1, 10)).to.equal(10)
		expect(Waveform.litCells(0.55, 10)).to.equal(6)
		expect(Waveform.litCells(0, 10)).to.equal(1)
	end)

	describe("component", function()
		local app, cleanup, gui
		beforeEach(function()
			app, cleanup = Harness.app()
			gui = Harness.mount(app)
		end)
		afterEach(function()
			cleanup()
		end)

		local function sizeOf()
			return UDim2.fromOffset(400, 80)
		end

		it("draws a column per level, as tall as its share (bars)", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 0.5, 1 },
				variant = "bars",
				size = sizeOf(),
			})
			expect(#w.columns).to.equal(2)
			expect(w.columns[1].bar.Size.Y.Scale).to.equal(0.5)
			expect(w.columns[2].bar.Size.Y.Scale).to.equal(1)
		end)

		it("lights whole cells in blocks and hides the rest", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 0.5 },
				variant = "blocks",
				cells = 4,
				size = sizeOf(),
			})
			local shown = 0
			for _, cell in w.columns[2].cells do
				if cell.Visible then
					shown += 1
				end
			end
			expect(#w.columns[2].cells).to.equal(4)
			expect(shown).to.equal(2)
		end)

		it("shows the unlit cells faintly with track", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 0.25 },
				variant = "blocks",
				cells = 4,
				track = true,
				size = sizeOf(),
			})
			local top = w.columns[2].cells[4]
			local bottom = w.columns[2].cells[1]
			expect(top.Visible).to.equal(true)
			expect(top.BackgroundTransparency > bottom.BackgroundTransparency).to.equal(true)
		end)

		it("lights the columns before progress and dims the rest", function()
			local progress = Reactive.ref(0.5)
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 1, 1, 1 },
				variant = "bars",
				progress = progress,
				size = sizeOf(),
			})
			expect(w.columns[1].bar.BackgroundTransparency).to.equal(0)
			expect(w.columns[4].bar.BackgroundTransparency > 0).to.equal(true)
			progress(1)
			expect(w.columns[4].bar.BackgroundTransparency).to.equal(0)
		end)

		it("lights every column with no progress", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 1 },
				size = sizeOf(),
			})
			expect(w.columns[2].cells[1].BackgroundTransparency).to.equal(0)
		end)

		it("colours each column from a token, a Color3 or a function", function()
			local red = Color3.fromRGB(255, 0, 0)
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 1 },
				variant = "bars",
				color = function(index)
					return if index == 1 then red else "$Primary"
				end,
				size = sizeOf(),
			})
			expect(Harness.colorEq(w.columns[1].bar.BackgroundColor3, red)).to.equal(true)
			expect(Harness.colorEq(w.columns[2].bar.BackgroundColor3, app.theme:resolve("Primary"))).to.equal(
				true
			)
		end)

		it("blends column colours between stops along its width", function()
			local red, blue = Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255)
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 1, 1 },
				variant = "bars",
				stops = { { 0, red }, { 1, blue } },
				size = sizeOf(),
			})
			-- The middle column sits half way along
			expect(Harness.colorEq(w.columns[2].bar.BackgroundColor3, red:Lerp(blue, 0.5))).to.equal(true)
			expect(Harness.colorEq(w.columns[1].bar.BackgroundColor3, red:Lerp(blue, 1 / 6))).to.equal(true)
		end)

		it("holds the first and last stop's colour past them", function()
			local red, blue = Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255)
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 1, 1, 1 },
				variant = "bars",
				stops = { { 0.4, red }, { 0.6, blue } },
				size = sizeOf(),
			})
			expect(Harness.colorEq(w.columns[1].bar.BackgroundColor3, red)).to.equal(true)
			expect(Harness.colorEq(w.columns[4].bar.BackgroundColor3, blue)).to.equal(true)
		end)

		it("colours cells by height with a gradient", function()
			local bottom, top = Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 0, 0)
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1 },
				variant = "blocks",
				cells = 5,
				gradient = { bottom, top },
				size = sizeOf(),
			})
			expect(Harness.colorEq(w.columns[1].cells[1].BackgroundColor3, bottom)).to.equal(true)
			expect(Harness.colorEq(w.columns[1].cells[5].BackgroundColor3, top)).to.equal(true)
		end)

		it("fades cells towards the top with fade", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1 },
				variant = "dots",
				cells = 5,
				fade = 0.8,
				size = sizeOf(),
			})
			local cells = w.columns[1].cells
			expect(cells[1].BackgroundTransparency).to.equal(0)
			expect(cells[5].BackgroundTransparency).to.be.near(0.8, 0.001)
			expect(cells[3].BackgroundTransparency > 0 and cells[3].BackgroundTransparency < 0.8).to.equal(
				true
			)
		end)

		it("fades the dimmed columns on top of their dimming", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 1 },
				variant = "blocks",
				cells = 4,
				fade = 0.5,
				progress = 0,
				size = sizeOf(),
			})
			local cells = w.columns[2].cells
			expect(cells[4].BackgroundTransparency > cells[1].BackgroundTransparency).to.equal(true)
		end)

		it("rounds dots", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1 },
				variant = "dots",
				cells = 3,
				size = sizeOf(),
			})
			local corner = w.columns[1].cells[1]:FindFirstChildOfClass("UICorner")
			expect(corner and corner.CornerRadius).to.equal(UDim.new(1, 0))
		end)

		it("caps each column with peaks", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1, 0.5 },
				peaks = true,
				size = sizeOf(),
			})
			expect(w.columns[1].peak ~= nil).to.equal(true)
			expect(w.columns[1].peak.Visible).to.equal(true)
		end)

		it("follows reactive levels, adding columns", function()
			local levels = Reactive.ref({ 1 })
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = levels,
				variant = "bars",
				size = sizeOf(),
			})
			expect(#w.columns).to.equal(1)
			levels({ 1, 0.5, 0.25 })
			expect(#w.columns).to.equal(3)
			expect(w.columns[3].bar.Size.Y.Scale).to.equal(0.25)
		end)

		it("mirrors columns about the middle when centred", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 0.5 },
				variant = "bars",
				align = "center",
				size = sizeOf(),
			})
			expect(w.columns[1].bar.AnchorPoint.Y).to.equal(0.5)
			expect(w.columns[1].bar.Position.Y.Scale).to.equal(0.5)
		end)

		it("turns a press into the fraction across it", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1 },
				size = sizeOf(),
				onSeek = function() end,
			})
			expect(w.seek ~= nil).to.equal(true)
			local left = w.Instance.AbsolutePosition.X
			local width = w.Instance.AbsoluteSize.X
			expect(Waveform.fractionAt(w.Instance, left + width * 0.25)).to.be.near(0.25, 0.01)
			expect(Waveform.fractionAt(w.Instance, left - 50)).to.equal(0)
		end)

		it("takes no clicks without onSeek", function()
			local w = Waveform.new({
				app = app,
				Parent = gui,
				renderer = "frames",
				levels = { 1 },
				size = sizeOf(),
			})
			expect(w.seek).to.equal(nil)
		end)

		describe("canvas", function()
			local function pixel(image, x, y)
				local b = image:ReadPixelsBuffer(Vector2.new(x, y), Vector2.new(1, 1))
				return Color3.fromRGB(buffer.readu8(b, 0), buffer.readu8(b, 1), buffer.readu8(b, 2)),
					buffer.readu8(b, 3)
			end

			it("draws on a canvas when it can", function()
				local w = Waveform.new({
					app = app,
					Parent = gui,
					levels = { 1, 1 },
					variant = "blocks",
					cells = 4,
					color = "$Primary",
					size = sizeOf(),
				})
				Harness.flush()
				expect(w.mode).to.equal("canvas")
				local size = w.lit.Size
				-- The middle of the first column's bottom cell is lit in the colour
				local colour, alpha = pixel(w.lit, math.floor(size.X / 4), size.Y - math.floor(size.Y / 8))
				expect(alpha).to.equal(255)
				expect(Harness.colorEq(colour, app.theme:resolve("Primary"))).to.equal(true)
			end)

			it("fades the top of the canvas with fade", function()
				local w = Waveform.new({
					app = app,
					Parent = gui,
					levels = { 1 },
					variant = "blocks",
					cells = 4,
					fade = 0.8,
					size = sizeOf(),
				})
				Harness.flush()
				local size = w.lit.Size
				local x = math.floor(size.X / 2)
				local _, bottom = pixel(w.lit, x, size.Y - math.floor(size.Y / 8))
				local _, top = pixel(w.lit, x, math.floor(size.Y / 8))
				expect(top < bottom).to.equal(true)
			end)

			it("clips the lit drawing to the progress", function()
				local progress = Reactive.ref(0.25)
				local w = Waveform.new({
					app = app,
					Parent = gui,
					levels = { 1, 1 },
					progress = progress,
					size = sizeOf(),
				})
				Harness.flush()
				expect(w.clip.Size.X.Scale).to.equal(0.25)
				progress(0.75)
				expect(w.clip.Size.X.Scale).to.equal(0.75)
			end)

			it("draws again when the theme changes", function()
				local w = Waveform.new({
					app = app,
					Parent = gui,
					levels = { 1 },
					variant = "blocks",
					cells = 2,
					color = "$Foreground",
					size = sizeOf(),
				})
				Harness.flush()
				local other = if app.theme:get() == "dark" then "light" else "dark"
				app.theme:set(other)
				Harness.flush()
				local size = w.lit.Size
				-- The middle of the bottom of its two cells
				local colour = pixel(w.lit, math.floor(size.X / 2), size.Y - math.floor(size.Y / 4))
				expect(Harness.colorEq(colour, app.theme:resolve("Foreground"))).to.equal(true)
			end)

			it("falls back to frames when a canvas cannot be made", function()
				local create = Waveform._createCanvas
				Waveform._createCanvas = function()
					return nil
				end
				local ok, w =
					pcall(Waveform.new, { app = app, Parent = gui, levels = { 1, 0.5 }, size = sizeOf() })
				-- The first drawing waits for a size
				Harness.flush()
				Waveform._createCanvas = create
				expect(ok).to.equal(true)
				expect(w.mode).to.equal("frames")
				expect(#w.columns).to.equal(2)
			end)
		end)

		it("rejects an unknown variant", function()
			expect(function()
				Waveform.new({
					app = app,
					Parent = gui,
					renderer = "frames",
					levels = { 1 },
					variant = "wiggle",
				})
			end).to.throw()
		end)
	end)
end
