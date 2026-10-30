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
end
