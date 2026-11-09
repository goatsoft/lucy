return function()
	local Attribution = require(script.Parent.Attribution)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("renders an auto-sized, tagged attribution frame", function()
		local badge = Attribution.new({ app = app, Parent = gui })
		expect(badge.Instance:IsA("GuiObject")).to.equal(true)
		expect(badge.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
		expect(badge.Instance:HasTag("ui-attribution")).to.equal(true)
		expect(badge.Instance:HasTag("ui-attribution-variant-default")).to.equal(true)
		expect(badge.Instance:HasTag("ui-attribution-size-md")).to.equal(true)

		-- Check image and labels
		local image = badge.parts.image :: ImageLabel
		local label = badge.parts.label :: TextLabel
		local brand = badge.parts.brand :: TextLabel
		expect(image:IsA("ImageLabel")).to.equal(true)
		expect(label:IsA("TextLabel")).to.equal(true)
		expect(brand:IsA("TextLabel")).to.equal(true)
		expect(label.Text).to.equal("Built with")
		expect(brand.Text).to.equal("Lucy")
	end)

	it("follows reactive label and brand", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local count = Reactive.ref(1)
		local badge = Attribution.new({
			app = app,
			Parent = gui,
			label = function()
				return if count() == 1 then "Made with" else "Powered by"
			end,
			brand = "Lucy v2",
		})
		expect(badge.parts.label.Text).to.equal("Made with")
		expect(badge.parts.brand.Text).to.equal("Lucy v2")
		count(2)
		expect(badge.parts.label.Text).to.equal("Powered by")
	end)

	it("switches masthead asset between dark and light variants and themes", function()
		app.theme:set("dark")
		local badgeDark = Attribution.new({ app = app, Parent = gui, variant = "default" })
		local badgeLight = Attribution.new({ app = app, Parent = gui, variant = "light" })
		expect(badgeDark.parts.image.Image).to.equal(Attribution.assets.dark)
		expect(badgeLight.parts.image.Image).to.equal(Attribution.assets.light)

		badgeDark:set("variant", "light")
		expect(badgeDark.parts.image.Image).to.equal(Attribution.assets.light)

		badgeDark:set("variant", "default")
		expect(badgeDark.parts.image.Image).to.equal(Attribution.assets.dark)

		app.theme:set("light")
		expect(badgeDark.parts.image.Image).to.equal(Attribution.assets.light)
	end)

	it("styles variants with tags", function()
		local badge = Attribution.new({ app = app, Parent = gui, variant = "brand" })
		expect(badge.Instance:HasTag("ui-attribution-variant-brand")).to.equal(true)

		badge:set("variant", "outline")
		expect(badge.Instance:HasTag("ui-attribution-variant-outline")).to.equal(true)
	end)

	it("is rounded by default and square when requested", function()
		local round = Attribution.new({ app = app, Parent = gui })
		local square = Attribution.new({ app = app, Parent = gui, shape = "square" })
		expect(round.Instance:HasTag("ui-attribution-shape-square")).to.equal(false)
		expect(square.Instance:HasTag("ui-attribution-shape-square")).to.equal(true)

		square:set("shape", "rounded")
		expect(square.Instance:HasTag("ui-attribution-shape-square")).to.equal(false)
	end)

	it("supports size variants", function()
		local sm = Attribution.new({ app = app, Parent = gui, size = "sm" })
		local md = Attribution.new({ app = app, Parent = gui, size = "md" })
		local lg = Attribution.new({ app = app, Parent = gui, size = "lg" })
		expect(sm.Instance:HasTag("ui-attribution-size-sm")).to.equal(true)
		expect(md.Instance:HasTag("ui-attribution-size-md")).to.equal(true)
		expect(lg.Instance:HasTag("ui-attribution-size-lg")).to.equal(true)
	end)

	it("fires onClick when clicked", function()
		local clicked = false
		local badge = Attribution.new({
			app = app,
			Parent = gui,
			onClick = function()
				clicked = true
			end,
		})
		expect(badge.Instance:IsA("GuiButton")).to.equal(true)
		badge:click()
		expect(clicked).to.equal(true)
	end)

	it("rejects unknown variants", function()
		expect(function()
			Attribution.new({ app = app, variant = "neon" })
		end).to.throw()
	end)

	it("rejects unknown shapes", function()
		expect(function()
			Attribution.new({ app = app, shape = "circle" })
		end).to.throw()
	end)

	it("rejects unknown sizes", function()
		expect(function()
			Attribution.new({ app = app, size = "huge" })
		end).to.throw()
	end)
end
