return function()
	local Panel = require(script.Parent.Panel)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("follows reactive title and description", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local coins = Reactive.ref(0)
		local showTitle = Reactive.ref(false)
		local panel = Panel.new({
			app = app,
			Parent = gui,
			title = function()
				return if showTitle() then "Shop" else ""
			end,
			description = function()
				return if coins() > 0 then `{coins()} coins` else ""
			end,
		})
		expect(panel.header.Visible).to.equal(false)
		coins(5)
		expect(panel.header.Visible).to.equal(true)
		expect(panel.title.Visible).to.equal(false)
		showTitle(true)
		expect(panel.title.Text).to.equal("Shop")
		expect(panel.title.Visible).to.equal(true)
	end)

	it("renders header, content and footer regions", function()
		local child = Instance.new("Frame")
		local panel = Panel.new({ app = app, Parent = gui, title = "Loadout", children = { child } })
		expect(panel.title.Text).to.equal("Loadout")
		expect(child.Parent).to.equal(panel.content)
		expect(panel.footer.Visible).to.equal(false)
	end)

	it("hides the header when there is no title or description", function()
		local panel = Panel.new({ app = app, Parent = gui })
		expect(panel.header.Visible).to.equal(false)
		panel:set({ description = "Hi" })
		expect(panel.header.Visible).to.equal(true)
		expect(panel.title.Visible).to.equal(false)
	end)

	it("shows a footer when given", function()
		local panel = Panel.new({ app = app, Parent = gui, footer = { Instance.new("TextButton") } })
		expect(panel.footer.Visible).to.equal(true)
	end)

	it("adds size and aspect constraints", function()
		local panel = Panel.new({ app = app, Parent = gui, maxWidth = 480, aspectRatio = 2 })
		expect(panel.Instance:FindFirstChildOfClass("UISizeConstraint").MaxSize.X).to.equal(480)
		expect(panel.Instance:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio).to.equal(2)
	end)

	it("uses the card colour", function()
		local panel = Panel.new({ app = app, Parent = gui })
		Harness.flush()
		expect(Harness.colorEq(Harness.styled(panel.Instance, "BackgroundColor3"), app.theme:resolve("Card"))).to.equal(
			true
		)
	end)
end
