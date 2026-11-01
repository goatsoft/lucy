return function()
	local Marquee = require(script.Parent.Marquee)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Preferences = require(script.Parent.Parent.Core.Preferences)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local LONG = "Future Bounce VIP (Extended Club Mix) by DJ GOD and the Basement Crew"

	local app, cleanup, gui, box
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
		-- A narrow column to scroll in
		box = Instance.new("Frame")
		box.Size = UDim2.fromOffset(120, 40)
		box.Parent = gui
	end)
	afterEach(function()
		Preferences.setReducedMotion(nil)
		cleanup()
	end)

	local function offset(marquee: any): number
		return marquee.strip.Position.X.Offset
	end

	it("shows its text in the theme's text styles", function()
		local marquee = Marquee.new({ app = app, Parent = box, text = "Now playing", variant = "large" })
		expect(marquee.strip.Text).to.equal("Now playing")
		expect(marquee.strip:HasTag("ui-text")).to.equal(true)
		expect(marquee.strip:HasTag("ui-text-variant-large")).to.equal(true)
		expect(marquee.Instance.ClipsDescendants).to.equal(true)
	end)

	it("follows its text", function()
		local text = Reactive.ref("One")
		local marquee = Marquee.new({ app = app, Parent = box, text = text })
		text("Two")
		expect(marquee.strip.Text).to.equal("Two")
	end)

	it("stays put when the text fits", function()
		local marquee = Marquee.new({ app = app, Parent = box, text = "Hi", pause = 0, speed = 400 })
		Harness.flush()
		task.wait(0.2)
		expect(offset(marquee)).to.equal(0)
		expect(marquee.scrolling).to.equal(false)
	end)

	it("scrolls a text too long to fit, after a pause at the start", function()
		local marquee = Marquee.new({ app = app, Parent = box, text = LONG, pause = 0.3, speed = 400 })
		Harness.flush()
		expect(offset(marquee)).to.equal(0)
		task.wait(0.6)
		expect(marquee.scrolling).to.equal(true)
		expect(offset(marquee) < 0).to.equal(true)
	end)

	it("never scrolls past the end of the text", function()
		local marquee = Marquee.new({ app = app, Parent = box, text = LONG, pause = 0.05, speed = 4000 })
		Harness.flush()
		task.wait(0.3)
		local overflow = marquee.strip.AbsoluteSize.X - marquee.Instance.AbsoluteSize.X
		expect(-offset(marquee) <= overflow + 1).to.equal(true)
	end)

	it("stays still when the player asks for reduced motion", function()
		Preferences.setReducedMotion(true)
		local marquee = Marquee.new({ app = app, Parent = box, text = LONG, pause = 0, speed = 400 })
		Harness.flush()
		task.wait(0.3)
		expect(offset(marquee)).to.equal(0)
		expect(marquee.scrolling).to.equal(false)
	end)

	it("stops while hidden and when destroyed", function()
		local visible = Reactive.ref(true)
		local marquee =
			Marquee.new({ app = app, Parent = box, text = LONG, pause = 0, speed = 400, visible = visible })
		Harness.flush()
		task.wait(0.2)
		expect(marquee.scrolling).to.equal(true)
		visible(false)
		expect(marquee.scrolling).to.equal(false)
		expect(marquee.Instance.Visible).to.equal(false)
		marquee:destroy()
		expect(marquee.scrolling).to.equal(false)
	end)

	it("loops a long text round without a jump when loop is on", function()
		local marquee = Marquee.new({
			app = app,
			Parent = box,
			text = LONG,
			loop = true,
			gap = 40,
			pause = 0,
			speed = 4000,
		})
		Harness.flush()
		task.wait(0.3)
		expect(marquee.scrolling).to.equal(true)
		local copy = marquee.repeatStrip
		expect(copy.Text).to.equal(LONG)
		expect(copy.Visible).to.equal(true)
		local width = marquee.strip.AbsoluteSize.X
		-- Never further than one text and its gap: the copy is then where the strip began
		expect(-offset(marquee) >= 0 and -offset(marquee) <= width + 40).to.equal(true)
		expect(math.abs(copy.Position.X.Offset - (offset(marquee) + width + 40)) <= 1).to.equal(true)
	end)

	it("wraps its loop after one text and its gap, holding only at the very start", function()
		-- 100 px a second, a 0.5 s hold, a 300 px text and a 50 px gap: one lap is 3.5 s
		expect(Marquee.loopOffsetAt(0.2, 350, 100, 0.5)).to.equal(0)
		expect(Marquee.loopOffsetAt(1.5, 350, 100, 0.5)).to.equal(100)
		expect(math.abs(Marquee.loopOffsetAt(4.5, 350, 100, 0.5) - 50) < 1e-6).to.equal(true)
	end)

	it("hides the loop's copy while the text fits", function()
		local marquee =
			Marquee.new({ app = app, Parent = box, text = "Hi", loop = true, pause = 0, speed = 400 })
		Harness.flush()
		task.wait(0.2)
		expect(offset(marquee)).to.equal(0)
		expect(marquee.repeatStrip.Visible).to.equal(false)
	end)

	it("styles the loop's copy like the strip", function()
		local marquee = Marquee.new({ app = app, Parent = box, text = LONG, loop = true })
		marquee.strip.TextSize = 33
		marquee.strip.TextColor3 = Color3.new(1, 0, 0)
		expect(marquee.repeatStrip.TextSize).to.equal(33)
		expect(marquee.repeatStrip.TextColor3).to.equal(Color3.new(1, 0, 0))
	end)

	it("refuses an unknown variant", function()
		expect(function()
			Marquee.new({ app = app, Parent = box, text = "x", variant = "giant" })
		end).to.throw()
	end)
end
