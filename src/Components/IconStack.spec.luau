return function()
	local Icon = require(script.Parent.Icon)
	local IconStack = require(script.Parent.IconStack)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui, unregister
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
		unregister = Icon.register({
			["test:heart"] = { image = 111, rect = { 0, 0, 48, 48 } },
			["test:star"] = { image = 111, rect = { 48, 0, 48, 48 } },
		})
	end)
	afterEach(function()
		unregister()
		cleanup()
	end)

	-- The stack's icons (not their cutouts), in the order they were laid out
	local function icons(stack: any): { ImageLabel }
		local out = {}
		for _, child in stack.Instance:GetChildren() do
			if child:IsA("ImageLabel") and child:HasTag("ui-icon") then
				table.insert(out, child)
			end
		end
		table.sort(out, function(a, b)
			return a.Position.X.Offset < b.Position.X.Offset
		end)
		return out
	end
	local function cutouts(stack: any): { ImageLabel }
		local out = {}
		for _, child in stack.Instance:GetChildren() do
			if child:IsA("ImageLabel") and child:HasTag("ui-icon-stack-cutout") then
				table.insert(out, child)
			end
		end
		return out
	end

	it("draws one icon by default, as big as an Icon of its size", function()
		local stack = IconStack.new({ app = app, Parent = gui, icon = "test:heart", size = "lg" })
		local drawn = icons(stack)
		expect(#drawn).to.equal(1)
		expect(drawn[1].Image).to.equal("rbxassetid://111")
		expect(drawn[1].Size).to.equal(UDim2.fromOffset(Icon.sizes.lg, Icon.sizes.lg))
		expect(stack.Instance.Size).to.equal(UDim2.fromOffset(Icon.sizes.lg, Icon.sizes.lg))
	end)

	it("fans a count out from the biggest in the middle, which sits on top", function()
		local stack = IconStack.new({ app = app, Parent = gui, icon = "test:heart", count = 3, size = 40 })
		local drawn = icons(stack)
		expect(#drawn).to.equal(3)
		local left, middle, right = drawn[1], drawn[2], drawn[3]
		expect(middle.Size.X.Offset).to.equal(40)
		expect(left.Size.X.Offset < 40).to.equal(true)
		expect(left.Size).to.equal(right.Size)
		expect(left.Rotation < 0).to.equal(true)
		expect(right.Rotation).to.equal(-left.Rotation)
		expect(middle.Rotation).to.equal(0)
		expect(middle.ZIndex > left.ZIndex and middle.ZIndex > right.ZIndex).to.equal(true)
		-- The frame is wider than one icon, so a layout gives the whole fan its room
		expect(stack.Instance.Size.X.Offset > 40).to.equal(true)
	end)

	it("lays a row out evenly, each one on top of the one before", function()
		local stack = IconStack.new({
			app = app,
			Parent = gui,
			icon = "test:heart",
			count = 4,
			arrange = "row",
			size = 20,
		})
		local drawn = icons(stack)
		expect(#drawn).to.equal(4)
		local step = drawn[2].Position.X.Offset - drawn[1].Position.X.Offset
		expect(step > 0 and step < 20).to.equal(true)
		for i = 2, 4 do
			expect(drawn[i].Position.X.Offset - drawn[i - 1].Position.X.Offset).to.equal(step)
			expect(drawn[i].ZIndex > drawn[i - 1].ZIndex).to.equal(true)
			expect(drawn[i].Size).to.equal(drawn[1].Size)
			expect(drawn[i].Rotation).to.equal(0)
		end
	end)

	it("piles a count up, the bottom row in front", function()
		local stack = IconStack.new({
			app = app,
			Parent = gui,
			icon = "test:heart",
			count = 3,
			arrange = "pile",
			size = 40,
		})
		local drawn = icons(stack)
		expect(#drawn).to.equal(3)
		table.sort(drawn, function(a, b)
			return a.Position.Y.Offset < b.Position.Y.Offset
		end)
		local top = drawn[1]
		expect(top.Position.Y.Offset < drawn[2].Position.Y.Offset).to.equal(true)
		expect(drawn[2].Position.Y.Offset).to.equal(drawn[3].Position.Y.Offset)
		expect(top.ZIndex < drawn[2].ZIndex and top.ZIndex < drawn[3].ZIndex).to.equal(true)
	end)

	it("places layers where it is told, in icons from the middle, with their own icon and colour", function()
		local stack = IconStack.new({
			app = app,
			Parent = gui,
			icon = "test:heart",
			size = 40,
			layers = {
				{ size = 1 },
				{ icon = "test:star", x = 0.5, y = -0.5, size = 0.5, rotation = 20, variant = "primary" },
			},
		})
		local drawn = icons(stack)
		expect(#drawn).to.equal(2)
		local heart, star = drawn[1], drawn[2]
		expect(heart.Size).to.equal(UDim2.fromOffset(40, 40))
		expect(star.Size).to.equal(UDim2.fromOffset(20, 20))
		expect(star.ImageRectOffset).to.equal(Vector2.new(48, 0))
		expect(star.Rotation).to.equal(20)
		expect(star:HasTag("ui-icon-variant-primary")).to.equal(true)
		expect(heart:HasTag("ui-icon-variant-default")).to.equal(true)
		expect(star.Position.X.Offset - heart.Position.X.Offset).to.equal(20)
		expect(star.Position.Y.Offset - heart.Position.Y.Offset).to.equal(-20)
		-- A later layer sits on top unless it says otherwise
		expect(star.ZIndex > heart.ZIndex).to.equal(true)
	end)

	it("follows its count and arrangement as they change", function()
		local count = Reactive.ref(2)
		local stack = IconStack.new({ app = app, Parent = gui, icon = "test:heart", count = count })
		expect(#icons(stack)).to.equal(2)
		count(5)
		expect(#icons(stack)).to.equal(5)
		stack:set("arrange", "row")
		expect(icons(stack)[1].Rotation).to.equal(0)
	end)

	it("cuts each icon out of the ones behind it with a ring in the colour under it", function()
		local stack =
			IconStack.new({ app = app, Parent = gui, icon = "test:heart", count = 2, cutout = true })
		local rings = cutouts(stack)
		expect(#rings).to.equal(2)
		for _, ring in rings do
			expect(ring.Image).to.equal("rbxassetid://111")
		end
		local drawn = icons(stack)
		local behind = math.min(drawn[1].ZIndex, drawn[2].ZIndex)
		local front = math.max(drawn[1].ZIndex, drawn[2].ZIndex)
		-- The front icon's ring is above the icon behind it and under the front icon
		local frontRing = 0
		for _, ring in rings do
			frontRing = math.max(frontRing, ring.ZIndex)
			expect(ring.Size.X.Offset > drawn[1].Size.X.Offset - 1).to.equal(true)
		end
		expect(frontRing > behind and frontRing < front).to.equal(true)
		Harness.flush()
		expect(Harness.colorEq(Harness.styled(rings[1], "ImageColor3"), app.theme:resolve("Card"))).to.equal(
			true
		)
		stack:set("cutout", false)
		expect(#cutouts(stack)).to.equal(0)
	end)

	it("grows on TV, the whole stack together", function()
		local stack = IconStack.new({ app = app, Parent = gui, icon = "test:heart", count = 3, size = "md" })
		local before = stack.Instance.Size.X.Offset
		app.input:setCaps(Harness.caps.console)
		expect(stack.Instance.Size.X.Offset > before).to.equal(true)
		expect(icons(stack)[2].Size.X.Offset > Icon.sizes.md).to.equal(true)
	end)

	it("refuses an arrangement it does not know", function()
		expect(function()
			IconStack.new({ app = app, Parent = gui, icon = "test:heart", arrange = "spiral" })
		end).to.throw()
	end)
end
