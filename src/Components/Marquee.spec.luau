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

	it("refuses an unknown variant", function()
		expect(function()
			Marquee.new({ app = app, Parent = box, text = "x", variant = "giant" })
		end).to.throw()
	end)
end
