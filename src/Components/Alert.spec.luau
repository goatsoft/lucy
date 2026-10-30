return function()
	local Alert = require(script.Parent.Alert)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("shows a title and a description", function()
		local alert = Alert.new({
			app = app,
			Parent = gui,
			title = "Server restarting",
			description = "Your progress is saved.",
		})
		expect(alert.title.Text).to.equal("Server restarting")
		expect(alert.description.Text).to.equal("Your progress is saved.")
		expect(alert.description.Visible).to.equal(true)
		alert:set("description", "")
		expect(alert.description.Visible).to.equal(false)
	end)

	it("hides an empty title", function()
		local alert = Alert.new({ app = app, Parent = gui, description = "Just text" })
		expect(alert.title.Visible).to.equal(false)
	end)

	it("puts an icon before the text and children after the description", function()
		local icon, button = Instance.new("ImageLabel"), Instance.new("TextButton")
		local alert = Alert.new({ app = app, Parent = gui, title = "Hi", icon = icon, children = { button } })
		expect(icon.Parent).to.equal(alert.icon)
		expect(alert.icon.Visible).to.equal(true)
		expect(button:IsDescendantOf(alert.content)).to.equal(true)
		expect(button.LayoutOrder > alert.description.LayoutOrder).to.equal(true)
		local plain = Alert.new({ app = app, Parent = gui, title = "Hi" })
		expect(plain.icon.Visible).to.equal(false)
	end)

	it("fills the width and fits its text", function()
		local alert = Alert.new({ app = app, Parent = gui, title = "Hi" })
		expect(alert.Instance.Size).to.equal(UDim2.fromScale(1, 0))
		expect(alert.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.Y)
	end)

	it("tags its variant on the box and the text", function()
		local variant = Reactive.ref("destructive")
		local alert = Alert.new({ app = app, Parent = gui, title = "Hi", variant = variant })
		expect(alert.Instance:HasTag("ui-alert-variant-destructive")).to.equal(true)
		expect(alert.title:HasTag("ui-alert-title-destructive")).to.equal(true)
		variant("success")
		expect(alert.Instance:HasTag("ui-alert-variant-destructive")).to.equal(false)
		expect(alert.Instance:HasTag("ui-alert-variant-success")).to.equal(true)
		expect(alert.title:HasTag("ui-alert-title-success")).to.equal(true)
	end)

	it("rejects an unknown variant", function()
		expect(function()
			Alert.new({ app = app, Parent = gui, variant = "neon" })
		end).to.throw()
	end)

	it("colours the title for the destructive variant", function()
		local alert = Alert.new({ app = app, Parent = gui, title = "Hi", variant = "destructive" })
		Harness.flush()
		expect(Harness.colorEq(Harness.styled(alert.title, "TextColor3"), app.theme:resolve("Destructive"))).to.equal(
			true
		)
	end)
end
