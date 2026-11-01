return function()
	local Badge = require(script.Parent.Badge)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("follows reactive text and variant", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local kills = Reactive.ref(0)
		local badge = Badge.new({
			app = app,
			Parent = gui,
			text = Reactive.computed(function()
				return tostring(kills())
			end),
			variant = function()
				return if kills() >= 10 then "destructive" else "default"
			end,
		})
		expect(badge.Instance.Text).to.equal("0")
		kills(12)
		expect(badge.Instance.Text).to.equal("12")
		expect(badge.Instance:HasTag("ui-badge-variant-destructive")).to.equal(true)
	end)

	it("renders an auto-sized, tagged label", function()
		local badge = Badge.new({ app = app, Parent = gui, text = "New" })
		expect(badge.Instance:IsA("TextLabel")).to.equal(true)
		expect(badge.Instance.Text).to.equal("New")
		expect(badge.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
		expect(badge.Instance:HasTag("ui-badge-variant-default")).to.equal(true)
	end)

	it("updates text and variant from state", function()
		local badge = Badge.new({ app = app, id = "kills", Parent = gui })
		app.state:merge("ui.kills", { text = "12", variant = "destructive" })
		expect(badge.Instance.Text).to.equal("12")
		expect(badge.Instance:HasTag("ui-badge-variant-destructive")).to.equal(true)
	end)

	it("styles the destructive variant", function()
		local badge = Badge.new({ app = app, Parent = gui, variant = "destructive" })
		Harness.flush()
		expect(
			Harness.colorEq(
				Harness.styled(badge.Instance, "BackgroundColor3"),
				app.theme:resolve("Destructive")
			)
		).to.equal(true)
	end)

	it("is rounded by default and only slightly rounded when square", function()
		local round = Badge.new({ app = app, Parent = gui, text = "NEW" })
		local square = Badge.new({ app = app, Parent = gui, text = "RARE", shape = "square" })
		expect(round.Instance:HasTag("ui-badge-shape-square")).to.equal(false)
		expect(square.Instance:HasTag("ui-badge-shape-square")).to.equal(true)
		local radius
		for _, rule in Badge.rules do
			if rule.selector == ".ui-badge-shape-square::UICorner" then
				radius = rule.properties.CornerRadius
			end
		end
		expect(radius).to.equal("$RadiusSm")
		square:set("shape", "rounded")
		expect(square.Instance:HasTag("ui-badge-shape-square")).to.equal(false)
	end)

	it("rejects unknown shapes", function()
		expect(function()
			Badge.new({ app = app, shape = "star" })
		end).to.throw()
	end)

	it("rejects unknown variants", function()
		expect(function()
			Badge.new({ app = app, variant = "gold" })
		end).to.throw()
	end)
end
