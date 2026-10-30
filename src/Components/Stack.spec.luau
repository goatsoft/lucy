return function()
	local Stack = require(script.Parent.Stack)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("lays children out vertically by default, in order", function()
		local a, b = Instance.new("Frame"), Instance.new("Frame")
		local stack = Stack.new({ app = app, Parent = gui, children = { a, b } })
		expect(stack.layout.FillDirection).to.equal(Enum.FillDirection.Vertical)
		expect(a.Parent).to.equal(stack.Instance)
		expect(a.LayoutOrder < b.LayoutOrder).to.equal(true)
	end)

	it("resolves gap tokens", function()
		local stack = Stack.new({ app = app, Parent = gui, gap = "Space4" })
		expect(stack.layout.Padding).to.equal(app.theme:resolve("Space4"))
		local px = Stack.new({ app = app, Parent = gui, gap = 10 })
		expect(px.layout.Padding).to.equal(UDim.new(0, 10))
	end)

	it("maps align and justify for rows", function()
		local stack = Stack.new({ app = app, Parent = gui, direction = "horizontal", align = "center", justify = "end" })
		expect(stack.layout.FillDirection).to.equal(Enum.FillDirection.Horizontal)
		expect(stack.layout.VerticalAlignment).to.equal(Enum.VerticalAlignment.Center)
		expect(stack.layout.HorizontalAlignment).to.equal(Enum.HorizontalAlignment.Right)
	end)

	it("adds padding when asked", function()
		local stack = Stack.new({ app = app, Parent = gui, padding = 12 })
		expect(stack.Instance:FindFirstChildOfClass("UIPadding").PaddingTop).to.equal(UDim.new(0, 12))
	end)

	it("switches direction and gap responsively", function()
		local stack = Stack.new({
			app = app,
			Parent = gui,
			direction = { mobile = "vertical", default = "horizontal" },
			gap = { touch = 16, default = 8 },
		})
		expect(stack.layout.FillDirection).to.equal(Enum.FillDirection.Horizontal)
		expect(stack.layout.Padding).to.equal(UDim.new(0, 8))
		app.input:setCaps(Harness.caps.mobile)
		app.input:setMode("touch")
		expect(stack.layout.FillDirection).to.equal(Enum.FillDirection.Vertical)
		expect(stack.layout.Padding).to.equal(UDim.new(0, 16))
	end)

	it("accepts component handles as children", function()
		local inner = Stack.new({ app = app })
		local outer = Stack.new({ app = app, Parent = gui, children = { inner } })
		expect(inner.Instance.Parent).to.equal(outer.Instance)
	end)
end
