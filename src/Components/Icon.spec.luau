return function()
	local Icon = require(script.Parent.Icon)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui, unregister
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
		unregister = Icon.register({
			["test:heart"] = { image = 111, rect = { 0, 0, 48, 48 } },
			["test:star"] = { image = "rbxassetid://111", rect = { 48, 0, 48, 48 } },
			["test:logo"] = { image = 222, tint = false },
		})
	end)
	afterEach(function()
		unregister()
		cleanup()
	end)

	it("resolves registered names, asset ids and urls", function()
		local heart = Icon.resolve("test:heart")
		expect(heart.image).to.equal("rbxassetid://111")
		expect(heart.offset).to.equal(Vector2.new(0, 0))
		expect(heart.size).to.equal(Vector2.new(48, 48))
		expect(heart.tint).to.equal(true)
		local id = Icon.resolve(333)
		expect(id.image).to.equal("rbxassetid://333")
		expect(id.size).to.equal(Vector2.zero)
		expect((Icon.resolve("rbxassetid://9") :: any).image).to.equal("rbxassetid://9")
		expect((Icon.resolve("test:logo") :: any).tint).to.equal(false)
		expect(Icon.resolve("test:nope")).to.equal(nil)
		expect(Icon.has("test:star")).to.equal(true)
		expect(Icon.has("test:nope")).to.equal(false)
	end)

	it("has Lucy's slots without registering anything", function()
		for _, slot in
			{
				"lucy:close",
				"lucy:check",
				"lucy:chevron-down",
				"lucy:chevron-up",
				"lucy:chevron-left",
				"lucy:chevron-right",
				"lucy:minus",
				"lucy:plus",
			}
		do
			expect(Icon.has(slot)).to.equal(true)
			local resolved: any = Icon.resolve(slot)
			expect(string.sub(resolved.image, 1, 13)).to.equal("rbxassetid://")
			expect(resolved.size).to.equal(Vector2.new(64, 64))
		end
	end)

	it("takes its slots from Lucy's own sheet, which lucy-icons builds", function()
		local IconSheet = require(script.Parent.Parent.Core.IconSheet) :: any
		local names = {}
		for name in IconSheet do
			table.insert(names, name)
		end
		table.sort(names)
		expect(#Icon.slots).to.equal(8)
		expect(table.concat(Icon.slots, " ")).to.equal(table.concat(names, " "))
	end)

	it("lets a game replace a slot, and puts Lucy's back when it unregisters", function()
		local default = Icon.resolve("lucy:close")
		local undo = Icon.register({ ["lucy:close"] = { image = 333 } })
		local replaced: any = Icon.resolve("lucy:close")
		expect(replaced.image).to.equal("rbxassetid://333")
		local icon = Icon.new({ app = app, icon = "lucy:close", Parent = gui })
		expect(icon.Instance.Image).to.equal("rbxassetid://333")
		undo()
		expect(Icon.resolve("lucy:close")).to.equal(default)
	end)

	it("forgets names when unregistered", function()
		local remove = Icon.register({ ["test:temp"] = { image = 5 } })
		expect(Icon.has("test:temp")).to.equal(true)
		remove()
		expect(Icon.has("test:temp")).to.equal(false)
		expect(Icon.has("test:heart")).to.equal(true)
	end)

	it("draws a cell of a sprite sheet and follows changes", function()
		local name = Reactive.ref("test:heart")
		local icon = Icon.new({ app = app, Parent = gui, icon = name })
		local root = icon.Instance
		expect(root:IsA("ImageLabel")).to.equal(true)
		expect(root.Image).to.equal("rbxassetid://111")
		expect(root.ImageRectOffset).to.equal(Vector2.new(0, 0))
		expect(root.ImageRectSize).to.equal(Vector2.new(48, 48))
		name("test:star")
		expect(root.ImageRectOffset).to.equal(Vector2.new(48, 0))
		name(444)
		expect(root.Image).to.equal("rbxassetid://444")
		expect(root.ImageRectSize).to.equal(Vector2.zero)
	end)

	it("draws nothing for an unknown name and warns once per name", function()
		local warnings = {}
		local hooks: any = Icon
		local previous = hooks._warn
		hooks._warn = function(message: string)
			table.insert(warnings, message)
		end
		local ok, err = pcall(function()
			local first = Icon.new({ app = app, Parent = gui, icon = "test:nope" })
			expect(first.Instance.Image).to.equal("")
			Icon.new({ app = app, Parent = gui, icon = "test:nope" })
			local name = Reactive.ref("test:heart")
			local later = Icon.new({ app = app, Parent = gui, icon = name })
			name("test:gone")
			expect(later.Instance.Image).to.equal("")
		end)
		hooks._warn = previous
		assert(ok, err)
		expect(#warnings).to.equal(2)
		expect(string.find(warnings[1], "test:nope", 1, true) ~= nil).to.equal(true)
		expect(string.find(warnings[1], "lucy-icons build", 1, true) ~= nil).to.equal(true)
		expect(string.find(warnings[2], "test:gone", 1, true) ~= nil).to.equal(true)
	end)

	it("comes in three sizes or a number of pixels", function()
		local size = Reactive.ref("sm")
		local icon = Icon.new({ app = app, Parent = gui, icon = "test:heart", size = size })
		expect(icon.Instance.Size).to.equal(UDim2.fromOffset(Icon.sizes.sm, Icon.sizes.sm))
		size("lg")
		expect(icon.Instance.Size).to.equal(UDim2.fromOffset(Icon.sizes.lg, Icon.sizes.lg))
		size(40)
		expect(icon.Instance.Size).to.equal(UDim2.fromOffset(40, 40))
		expect(function()
			Icon.new({ app = app, Parent = gui, icon = "test:heart", size = "xl" })
		end).to.throw()
	end)

	it("grows on TV", function()
		local icon = Icon.new({ app = app, Parent = gui, icon = "test:heart", size = "md" })
		app.input:setCaps(Harness.caps.console)
		expect(icon.Instance.Size.X.Offset > Icon.sizes.md).to.equal(true)
	end)

	it("tags its colour, and leaves colour icons untinted", function()
		local icon = Icon.new({ app = app, Parent = gui, icon = "test:heart", variant = "muted" })
		expect(icon.Instance:HasTag("ui-icon-variant-muted")).to.equal(true)
		expect(icon.Instance:HasTag("ui-icon-untinted")).to.equal(false)
		icon:set("icon", "test:logo")
		expect(icon.Instance:HasTag("ui-icon-untinted")).to.equal(true)
		expect(function()
			Icon.new({ app = app, Parent = gui, icon = "test:heart", variant = "neon" })
		end).to.throw()
	end)

	it("takes the foreground colour by default", function()
		local icon = Icon.new({ app = app, Parent = gui, icon = "test:heart" })
		Harness.flush()
		expect(Harness.colorEq(Harness.styled(icon.Instance, "ImageColor3"), app.theme:resolve("Foreground"))).to.equal(
			true
		)
	end)
end
