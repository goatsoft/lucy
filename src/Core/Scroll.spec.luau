return function()
	local Scroll = require(script.Parent.Scroll)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	describe("offsetFor", function()
		it("keeps the position when the item is in view", function()
			expect(Scroll.offsetFor(100, 200, 150, 250, 8)).to.equal(100)
		end)

		it("scrolls up to show an item above the view, with the margin", function()
			expect(Scroll.offsetFor(100, 200, 40, 80, 8)).to.equal(32)
		end)

		it("never goes below zero", function()
			expect(Scroll.offsetFor(100, 200, 4, 40, 8)).to.equal(0)
		end)

		it("scrolls down to show an item below the view, with the margin", function()
			expect(Scroll.offsetFor(0, 200, 300, 340, 8)).to.equal(148)
		end)

		it("shows the top of an item taller than the view", function()
			expect(Scroll.offsetFor(0, 100, 300, 600, 0)).to.equal(300)
		end)

		it("treats a missing margin as zero", function()
			expect(Scroll.offsetFor(0, 200, 300, 340)).to.equal(140)
		end)

		it("goes all the way to the start when it would stop just short of it", function()
			-- a heading above the first item: stopping at 32 would leave it cut off
			expect(Scroll.offsetFor(300, 200, 40, 80, 8, 1000)).to.equal(0)
			-- further down it stops at the item, as ever
			expect(Scroll.offsetFor(300, 200, 100, 140, 8, 1000)).to.equal(92)
		end)

		it("goes all the way to the end when it would stop just short of it", function()
			expect(Scroll.offsetFor(0, 200, 950, 990, 8, 1000)).to.equal(800)
			expect(Scroll.offsetFor(0, 200, 700, 740, 8, 1000)).to.equal(548)
		end)

		it("goes to the end for the last item when it only just overflows, not back to the start", function()
			-- a row of tabs 3 px wider than its room: the start and the end are both near, and the
			-- last tab (under the end's fade) needs the end
			expect(Scroll.offsetFor(0, 638, 516, 642, 8, 641)).to.equal(3)
			-- and the first tab, from the end, still goes back to the start
			expect(Scroll.offsetFor(3, 638, 0, 253, 8, 641)).to.equal(0)
		end)

		it("stays put when the item is in view, however near an end", function()
			expect(Scroll.offsetFor(30, 200, 100, 140, 8, 1000)).to.equal(30)
			expect(Scroll.offsetFor(790, 200, 900, 940, 8, 1000)).to.equal(790)
		end)

		it("keeps the top of an item taller than the view at the end", function()
			expect(Scroll.offsetFor(0, 200, 760, 1000, 0, 1000)).to.equal(760)
		end)
	end)

	describe("scaleOf", function()
		it("multiplies the UIScales above an object", function()
			local gui = Instance.new("ScreenGui")
			local a = Instance.new("UIScale")
			a.Scale = 2
			a.Parent = gui
			local frame = Instance.new("Frame")
			frame.Parent = gui
			local b = Instance.new("UIScale")
			b.Scale = 1.5
			b.Parent = frame
			local child = Instance.new("Frame")
			child.Parent = frame
			expect(Scroll.scaleOf(child)).to.equal(3)
			expect(Scroll.scaleOf(Instance.new("Frame"))).to.equal(1)
			gui:Destroy()
		end)
	end)

	describe("whenNear", function()
		local app, cleanup, gui
		beforeEach(function()
			app, cleanup = Harness.app()
			gui = Harness.mount(app)
		end)
		afterEach(function()
			cleanup()
		end)

		-- A 200 x 100 scroll area over a 1000 px canvas, and an item at `y`
		local function build(y: number, parent: Instance?): (ScrollingFrame, Frame)
			local frame = Instance.new("ScrollingFrame")
			frame.Size = UDim2.fromOffset(200, 100)
			frame.CanvasSize = UDim2.fromOffset(0, 1000)
			local item = Instance.new("Frame")
			item.Size = UDim2.fromOffset(50, 40)
			item.Position = UDim2.fromOffset(0, y)
			item.Parent = frame
			frame.Parent = parent or gui
			return frame, item
		end

		it("calls back at once for what is in view, once", function()
			if not Harness.laysOutLive() then
				return
			end
			local frame, item = build(20)
			local calls = 0
			Scroll.whenNear(item, function()
				calls += 1
			end)
			expect(Harness.waitFor(function()
				return calls == 1
			end)).to.equal(true)
			frame.CanvasPosition = Vector2.new(0, 500)
			frame.CanvasPosition = Vector2.new(0, 0)
			task.wait()
			task.wait()
			expect(calls).to.equal(1)
		end)

		it("waits for what is more than a view away to be scrolled near", function()
			if not Harness.laysOutLive() then
				return
			end
			-- the view is 100 px: near is within 100 px of it, so up to 200
			local frame, item = build(500)
			local calls = 0
			Scroll.whenNear(item, function()
				calls += 1
			end)
			for _ = 1, 4 do
				task.wait()
			end
			expect(calls).to.equal(0)
			frame.CanvasPosition = Vector2.new(0, 250)
			for _ = 1, 4 do
				task.wait()
			end
			expect(calls).to.equal(0)
			frame.CanvasPosition = Vector2.new(0, 320)
			expect(Harness.waitFor(function()
				return calls == 1
			end)).to.equal(true)
		end)

		it("takes how many views count as near", function()
			if not Harness.laysOutLive() then
				return
			end
			local _, item = build(500)
			local calls = 0
			Scroll.whenNear(item, function()
				calls += 1
			end, 5)
			expect(Harness.waitFor(function()
				return calls == 1
			end)).to.equal(true)
		end)

		it("waits while it, or something above it, is hidden", function()
			if not Harness.laysOutLive() then
				return
			end
			local panel = Instance.new("Frame")
			panel.Size = UDim2.fromOffset(200, 100)
			panel.Visible = false
			panel.Parent = gui
			local _, item = build(20, panel)
			item.Visible = false
			local calls = 0
			Scroll.whenNear(item, function()
				calls += 1
			end)
			panel.Visible = true
			for _ = 1, 4 do
				task.wait()
			end
			expect(calls).to.equal(0)
			item.Visible = true
			expect(Harness.waitFor(function()
				return calls == 1
			end)).to.equal(true)
		end)

		it("stops looking when told to", function()
			if not Harness.laysOutLive() then
				return
			end
			local frame, item = build(500)
			local calls = 0
			local stop = Scroll.whenNear(item, function()
				calls += 1
			end)
			stop()
			frame.CanvasPosition = Vector2.new(0, 450)
			for _ = 1, 4 do
				task.wait()
			end
			expect(calls).to.equal(0)
		end)

		it("looks again as the scroll area scrolls, a little at a time", function()
			if not Harness.laysOutLive() then
				return
			end
			-- as gamepad focus scrolls a list: small steps, a frame apart. The engine updates what is
			-- past the visible part lazily, so the object's own place may not say it moved
			local frame, item = build(500)
			local calls = 0
			Scroll.whenNear(item, function()
				calls += 1
			end)
			for y = 0, 320, 20 do
				frame.CanvasPosition = Vector2.new(0, y)
				task.wait()
			end
			expect(Harness.waitFor(function()
				return calls == 1
			end)).to.equal(true)
		end)

		it("calls back for what shows with no scroll area around it", function()
			if not Harness.laysOutLive() then
				return
			end
			local item = Instance.new("Frame")
			item.Size = UDim2.fromOffset(50, 40)
			local calls = 0
			Scroll.whenNear(item, function()
				calls += 1
			end)
			expect(calls).to.equal(0) -- in no gui yet
			item.Parent = gui
			expect(Harness.waitFor(function()
				return calls == 1
			end)).to.equal(true)
		end)
	end)

	describe("reveal", function()
		local app, cleanup, gui
		beforeEach(function()
			app, cleanup = Harness.app()
			gui = Harness.mount(app)
		end)
		afterEach(function()
			cleanup()
		end)

		local function build()
			local frame = Instance.new("ScrollingFrame")
			frame.Size = UDim2.fromOffset(200, 100)
			frame.CanvasSize = UDim2.fromOffset(0, 1000)
			frame.Parent = gui
			local item = Instance.new("Frame")
			item.Size = UDim2.fromOffset(50, 40)
			item.Position = UDim2.fromOffset(0, 500)
			item.Parent = frame
			Harness.flush()
			return frame, item
		end

		it("scrolls a ScrollingFrame ancestor to show the object", function()
			local frame, item = build()
			Scroll.reveal(item)
			Harness.flush()
			local top = item.AbsolutePosition.Y - frame.AbsolutePosition.Y
			local bottom = top + item.AbsoluteSize.Y
			expect(top >= 0).to.equal(true)
			expect(bottom <= frame.AbsoluteWindowSize.Y).to.equal(true)
		end)

		it("shows what is above the first item when focus comes back up to it", function()
			local frame = Instance.new("ScrollingFrame")
			frame.Size = UDim2.fromOffset(200, 100)
			frame.CanvasSize = UDim2.fromOffset(0, 1000)
			frame.Parent = gui
			-- a 20 px heading's worth of room above the first item
			local item = Instance.new("Frame")
			item.Size = UDim2.fromOffset(50, 40)
			item.Position = UDim2.fromOffset(0, 20)
			item.Parent = frame
			frame.CanvasPosition = Vector2.new(0, 400)
			Harness.flush()
			Scroll.reveal(item)
			Harness.flush()
			expect(frame.CanvasPosition.Y).to.equal(0)
		end)

		it("scrolls only the ScrollingFrame it is given, never one around it", function()
			local outer = Instance.new("ScrollingFrame")
			outer.Size = UDim2.fromOffset(300, 100)
			outer.CanvasSize = UDim2.fromOffset(0, 1000)
			outer.Parent = gui
			local inner = Instance.new("ScrollingFrame")
			inner.Size = UDim2.fromOffset(200, 60)
			inner.Position = UDim2.fromOffset(0, 500)
			inner.CanvasSize = UDim2.fromOffset(1000, 0)
			inner.Parent = outer
			local item = Instance.new("Frame")
			item.Size = UDim2.fromOffset(50, 40)
			item.Position = UDim2.fromOffset(600, 0)
			item.Parent = inner
			Harness.flush()
			Scroll.reveal(item, nil, inner)
			Harness.flush()
			expect(inner.CanvasPosition.X > 0).to.equal(true)
			expect(outer.CanvasPosition.Y).to.equal(0)
		end)

		it("does nothing outside a ScrollingFrame", function()
			local item = Instance.new("Frame")
			item.Parent = gui
			Scroll.reveal(item)
		end)

		it("runs when keyboard focus moves", function()
			local frame, item = build()
			app.input:setMode("keyboard")
			app.input:markFocus(item)
			Harness.flush()
			expect(frame.CanvasPosition.Y > 0).to.equal(true)
		end)

		it("does not scroll for a mouse player", function()
			local frame, item = build()
			app.input:setMode("mouse")
			app.input:markFocus(item)
			Harness.flush()
			expect(frame.CanvasPosition.Y).to.equal(0)
		end)
	end)

	describe("right stick", function()
		local app, cleanup, gui
		beforeEach(function()
			app, cleanup = Harness.app()
			gui = Harness.mount(app)
		end)
		afterEach(function()
			cleanup()
		end)

		-- A page scrolling down, with a row in it scrolling sideways, and a button in each
		local function build()
			local page = Instance.new("ScrollingFrame")
			page.Size = UDim2.fromOffset(300, 100)
			page.CanvasSize = UDim2.fromOffset(0, 1000)
			page.Parent = gui
			local row = Instance.new("ScrollingFrame")
			row.Size = UDim2.fromOffset(200, 60)
			row.CanvasSize = UDim2.fromOffset(1000, 0)
			row.ScrollingDirection = Enum.ScrollingDirection.X
			row.Parent = page
			local inRow = Instance.new("TextButton")
			inRow.Size = UDim2.fromOffset(50, 40)
			inRow.Parent = row
			local onPage = Instance.new("TextButton")
			onPage.Size = UDim2.fromOffset(50, 20)
			onPage.Position = UDim2.fromOffset(0, 70)
			onPage.Parent = page
			Harness.flush()
			return page, row, inRow, onPage
		end

		it("does nothing in the deadzone, then speeds up with the tilt", function()
			expect(Scroll.stickStep(0.1, 100, 1)).to.equal(0)
			local half = Scroll.stickStep(0.6, 100, 1)
			local full = Scroll.stickStep(1, 100, 1)
			expect(half > 0 and half < full / 2).to.equal(true)
			expect(full).to.equal(Scroll.stickSpeed * 100)
			expect(Scroll.stickStep(-1, 100, 1)).to.equal(-full)
		end)

		it("finds the scroller for each way, past one that does not scroll that way", function()
			local page, row, inRow, onPage = build()
			expect(Scroll.along(inRow, "X")).to.equal(row)
			expect(Scroll.along(inRow, "Y")).to.equal(page)
			expect(Scroll.along(onPage, "Y")).to.equal(page)
			expect(Scroll.along(onPage, "X")).to.equal(nil)
		end)

		it("scrolls down the page for down, and along the row for right", function()
			local page, row, inRow = build()
			Scroll.byStick(inRow, Vector2.new(0, -1), 0.1)
			expect(page.CanvasPosition.Y > 0).to.equal(true)
			expect(row.CanvasPosition.X).to.equal(0)
			Scroll.byStick(inRow, Vector2.new(1, 0), 0.1)
			expect(row.CanvasPosition.X > 0).to.equal(true)
		end)

		it("stops at the ends", function()
			local page, _, _, onPage = build()
			Scroll.byStick(onPage, Vector2.new(0, 1), 1)
			expect(page.CanvasPosition.Y).to.equal(0)
			for _ = 1, 20 do
				Scroll.byStick(onPage, Vector2.new(0, -1), 1)
			end
			expect(page.CanvasPosition.Y).to.equal(page.AbsoluteCanvasSize.Y - page.AbsoluteWindowSize.Y)
		end)

		it("moves focus scrolled out of view to what shows", function()
			local page, _, inRow = build()
			local further = Instance.new("TextButton")
			further.Size = UDim2.fromOffset(50, 20)
			further.Position = UDim2.fromOffset(0, 400)
			further.Parent = page
			Harness.flush()
			app.input:setMode("gamepad")
			app.input:markFocus(inRow)
			page.CanvasPosition = Vector2.new(0, 370)
			Harness.flush()
			app.input:_keepInView(page)
			expect(app.input:focused()).to.equal(further)
		end)
	end)
end
