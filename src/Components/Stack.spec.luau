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

	it("scales a row down to the width it has with fit", function()
		local room = Instance.new("Frame")
		room.Size = UDim2.fromOffset(100, 100)
		room.Parent = gui
		local children = {}
		for i = 1, 3 do
			local f = Instance.new("Frame")
			f.Size = UDim2.fromOffset(80, 20)
			children[i] = f
		end
		local stack =
			Stack.new({ app = app, Parent = room, direction = "horizontal", fit = 0.1, children = children })
		local scale = stack.Instance:FindFirstChild("LucyFit") :: UIScale
		expect(scale).to.be.ok()
		if not Harness.laysOutLive() then
			return -- the scale follows live layout only (Harness.laysOutLive)
		end
		local waited = 0
		while math.abs(scale.Scale - 100 / 240) > 0.01 and waited < 1 do
			waited += task.wait()
		end
		expect(scale.Scale).to.be.near(100 / 240, 0.01)
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

	describe("mount = intersect", function()
		local Devtools = require(script.Parent.Parent.Core.Devtools)

		-- A 400 px tall scroll area around a stack of a heading and `count` sections built by
		-- functions, each holding 300 px until it is built
		local function list(count: number, extra: { [string]: any }?)
			local scroller = Instance.new("ScrollingFrame")
			scroller.Size = UDim2.fromOffset(300, 400)
			scroller.CanvasSize = UDim2.fromOffset(0, 0)
			scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
			scroller.Parent = gui
			local counts, made = {}, {}
			local heading = Instance.new("TextLabel")
			heading.Name = "Heading"
			heading.Size = UDim2.new(1, 0, 0, 20)
			local children: { any } = { heading }
			for i = 1, count do
				counts[i] = 0
				table.insert(children, function()
					counts[i] += 1
					local section = Instance.new("Frame")
					section.Name = `Section{i}`
					section.Size = UDim2.new(1, 0, 0, 300)
					made[i] = section
					return section
				end)
			end
			local props: { [string]: any } =
				{ app = app, Parent = scroller, mount = "intersect", estimate = 300, children = children }
			local more: { [string]: any } = extra or {}
			for key, value in more do
				props[key] = value
			end
			return Stack.new(props), counts, made, scroller, heading
		end

		it("calls a function child at once without it, as before", function()
			local called = 0
			local stack = Stack.new({
				app = app,
				Parent = gui,
				children = {
					function(parent)
						called += 1
						Instance.new("Frame").Parent = parent
					end,
				},
			})
			expect(called).to.equal(1)
			expect(stack.slots).to.equal(nil)
			expect(stack.build).to.equal(nil)
		end)

		it("gives each function child a slot holding its room, in order with the rest", function()
			local stack, counts, _, _, heading = list(8)
			expect(#stack.slots).to.equal(8)
			expect(counts[8]).to.equal(0)
			expect(heading.Parent).to.equal(stack.Instance)
			expect(heading.LayoutOrder < stack.slots[1].LayoutOrder).to.equal(true)
			expect(stack.slots[1].LayoutOrder < stack.slots[2].LayoutOrder).to.equal(true)
			local hold = stack.slots[8]:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint
			expect(hold.MinSize).to.equal(Vector2.new(0, 300))
		end)

		it("builds the children near the view, then others as they are scrolled to", function()
			if not Harness.laysOutLive() then
				return
			end
			local stack, counts, made, scroller = list(8)
			expect(Harness.waitFor(function()
				return counts[3] == 1
			end)).to.equal(true)
			expect(counts[5]).to.equal(0)
			-- built in its slot, which no longer holds room of its own
			expect(made[1].Parent).to.equal(stack.slots[1])
			expect(stack.slots[1]:FindFirstChildOfClass("UISizeConstraint")).to.equal(nil)
			scroller.CanvasPosition = Vector2.new(0, 900)
			expect(Harness.waitFor(function()
				return counts[6] == 1
			end)).to.equal(true)
			expect(counts[1]).to.equal(1)
			expect(counts[8]).to.equal(0)
		end)

		it("builds one child, or all of them, when asked", function()
			local stack, counts = list(8)
			stack:build(7)
			expect(counts[7]).to.equal(1)
			expect(counts[8]).to.equal(0)
			stack:build()
			stack:build()
			for i = 1, 8 do
				expect(counts[i]).to.equal(1)
			end
		end)

		it("holds room across a row", function()
			local stack = list(8, { direction = "horizontal", estimate = 120 })
			local hold = stack.slots[8]:FindFirstChildOfClass("UISizeConstraint") :: UISizeConstraint
			expect(hold.MinSize).to.equal(Vector2.new(120, 0))
		end)

		it("takes only immediate or intersect, and no keep", function()
			expect(function()
				Stack.new({ app = app, Parent = gui, mount = "shown" })
			end).to.throw("mount")
			expect(function()
				Stack.new({ app = app, Parent = gui, mount = "intersect", keep = false })
			end).to.throw("keep")
		end)

		it("tells Devtools which children are not built yet", function()
			local stack = list(8, { id = "gear" })
			stack:build(7)
			local node = Devtools.tree({ app = app, root = "gear" })[1]
			local unbuilt = table.concat(node.unbuilt, ",")
			-- the first few may be built already, being in view; 7 is not listed, 8 is
			expect((string.find(unbuilt, "7", 1, true))).to.equal(nil)
			expect(string.sub(unbuilt, -1)).to.equal("8")
		end)
	end)

	it("accepts component handles as children", function()
		local inner = Stack.new({ app = app })
		local outer = Stack.new({ app = app, Parent = gui, children = { inner } })
		expect(inner.Instance.Parent).to.equal(outer.Instance)
	end)
end
