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

	it("follows a reactive visible", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local shown = Reactive.ref(true)
		local stack = Stack.new({ app = app, Parent = gui, visible = shown })
		expect(stack.Instance.Visible).to.equal(true)
		shown(false)
		expect(stack.Instance.Visible).to.equal(false)
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
		local stack = Stack.new({
			app = app,
			Parent = gui,
			direction = "horizontal",
			align = "center",
			justify = "end",
		})
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

	it("follows a getter size", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local tall = Reactive.ref(false)
		local stack = Stack.new({
			app = app,
			Parent = gui,
			size = function()
				return UDim2.fromOffset(100, if tall() then 300 else 100)
			end,
		})
		expect(stack.Instance.Size).to.equal(UDim2.fromOffset(100, 100))
		tall(true)
		expect(stack.Instance.Size).to.equal(UDim2.fromOffset(100, 300))
	end)

	it("grows a child into the room left, while asked", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local growing = Reactive.ref(true)
		local fixed = Instance.new("Frame")
		fixed.Size = UDim2.new(1, 0, 0, 50)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 0)
		expect(Stack.grow(fill, growing)).to.equal(fill)
		local item = fill:FindFirstChildOfClass("UIFlexItem") :: UIFlexItem
		expect(item.FlexMode).to.equal(Enum.UIFlexMode.Fill)
		growing(false)
		expect(item.FlexMode).to.equal(Enum.UIFlexMode.None)
		growing(true)
		local stack = Stack.new({
			app = app,
			Parent = gui,
			gap = 0,
			size = UDim2.fromOffset(100, 200),
			children = { fill, fixed },
		})
		if not Harness.laysOutLive() then
			return -- the room left is laid out by the engine: live layout only (Harness.laysOutLive)
		end
		task.wait()
		local scale = stack.Instance.AbsoluteSize.Y / 200
		expect(math.abs(fill.AbsoluteSize.Y / scale - 150) < 1).to.equal(true)
	end)

	it("puts a row's texts on one baseline with align baseline", function()
		local Baseline = require(script.Parent.Parent.Core.Baseline)
		local big, small = Instance.new("TextLabel"), Instance.new("TextLabel")
		big.TextSize, small.TextSize = 40, 18
		local stack = Stack.new({
			app = app,
			Parent = gui,
			direction = "horizontal",
			align = "baseline",
			children = { big, small },
		})
		expect(stack.layout.VerticalAlignment).to.equal(Enum.VerticalAlignment.Bottom)
		local padding = small:FindFirstChild(Baseline.paddingName) :: UIPadding
		expect(padding).to.be.ok()
		expect(padding.PaddingBottom.Offset).to.equal(math.round(Baseline.descent * 22))
		expect(big:FindFirstChild(Baseline.paddingName)).to.equal(nil)
	end)

	it("stretches children across a column with align stretch", function()
		local stack = Stack.new({ app = app, Parent = gui, align = "stretch" })
		expect(stack.layout.HorizontalFlex).to.equal(Enum.UIFlexAlignment.Fill)
		expect(stack.layout.VerticalFlex).to.equal(Enum.UIFlexAlignment.None)
		expect(stack.layout.HorizontalAlignment).to.equal(Enum.HorizontalAlignment.Left)
	end)

	it("stretches children down a row with align stretch", function()
		local stack = Stack.new({ app = app, Parent = gui, direction = "horizontal", align = "stretch" })
		expect(stack.layout.VerticalFlex).to.equal(Enum.UIFlexAlignment.Fill)
		expect(stack.layout.HorizontalFlex).to.equal(Enum.UIFlexAlignment.None)
		expect(stack.layout.VerticalAlignment).to.equal(Enum.VerticalAlignment.Top)
	end)

	it("keeps justify between on the main axis while align stretches the cross axis", function()
		local stack = Stack.new({
			app = app,
			Parent = gui,
			direction = "horizontal",
			align = "stretch",
			justify = "between",
		})
		expect(stack.layout.HorizontalFlex).to.equal(Enum.UIFlexAlignment.SpaceBetween)
		expect(stack.layout.VerticalFlex).to.equal(Enum.UIFlexAlignment.Fill)
	end)

	it("makes a child as wide as a stretched column", function()
		local child = Instance.new("Frame")
		child.Size = UDim2.fromOffset(20, 20)
		local stack = Stack.new({
			app = app,
			Parent = gui,
			align = "stretch",
			size = UDim2.fromOffset(200, 100),
			children = { child },
		})
		task.wait()
		-- The harness may scale the screen: compare with the stack, not with 200
		expect(stack.Instance.AbsoluteSize.X > 20).to.equal(true)
		expect(child.AbsoluteSize.X).to.equal(stack.Instance.AbsoluteSize.X)
	end)

	it("accepts component handles as children", function()
		local inner = Stack.new({ app = app })
		local outer = Stack.new({ app = app, Parent = gui, children = { inner } })
		expect(inner.Instance.Parent).to.equal(outer.Instance)
	end)
end
