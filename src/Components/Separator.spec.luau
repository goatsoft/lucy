return function()
	local Separator = require(script.Parent.Separator)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("follows a reactive orientation", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local orientation = Reactive.ref("horizontal")
		local separator = Separator.new({ app = app, Parent = gui, orientation = orientation })
		expect(separator.Instance.Size).to.equal(UDim2.new(1, 0, 0, 1))
		orientation("vertical")
		expect(separator.Instance.Size).to.equal(UDim2.new(0, 1, 1, 0))
	end)

	it("is a 1px full-width line by default", function()
		local separator = Separator.new({ app = app, Parent = gui })
		expect(separator.Instance.Size).to.equal(UDim2.new(1, 0, 0, 1))
	end)

	it("can be vertical", function()
		local separator = Separator.new({ app = app, Parent = gui, orientation = "vertical" })
		expect(separator.Instance.Size).to.equal(UDim2.new(0, 1, 1, 0))
	end)

	it("uses the border colour", function()
		local separator = Separator.new({ app = app, Parent = gui })
		Harness.flush()
		expect(
			Harness.colorEq(
				Harness.styled(separator.Instance, "BackgroundColor3"),
				app.theme:resolve("Border")
			)
		).to.equal(true)
	end)
end
