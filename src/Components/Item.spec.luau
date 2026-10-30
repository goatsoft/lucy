return function()
	local Item = require(script.Parent.Item)
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
		local item =
			Item.new({ app = app, Parent = gui, title = "Moonwalk", description = "Unlocked at level 5" })
		expect(item.title.Text).to.equal("Moonwalk")
		expect(item.description.Text).to.equal("Unlocked at level 5")
		expect(item.description.Visible).to.equal(true)
		item:set("description", "")
		expect(item.description.Visible).to.equal(false)
		item:set("title", "Robot")
		expect(item.title.Text).to.equal("Robot")
	end)

	it("hides the description when there is none", function()
		local item = Item.new({ app = app, Parent = gui, title = "Moonwalk" })
		expect(item.description.Visible).to.equal(false)
	end)

	it("puts media before the text and actions after it", function()
		local icon, button = Instance.new("ImageLabel"), Instance.new("TextButton")
		local item = Item.new({ app = app, Parent = gui, title = "Song", media = icon, actions = { button } })
		expect(icon.Parent).to.equal(item.media)
		expect(button.Parent).to.equal(item.actions)
		expect(item.media.LayoutOrder < item.content.LayoutOrder).to.equal(true)
		expect(item.content.LayoutOrder < item.actions.LayoutOrder).to.equal(true)
		expect(item.media.Visible).to.equal(true)
		expect(item.actions.Visible).to.equal(true)
	end)

	it("leaves out empty media and actions", function()
		local item = Item.new({ app = app, Parent = gui, title = "Song" })
		expect(item.media.Visible).to.equal(false)
		expect(item.actions.Visible).to.equal(false)
	end)

	it("gives the text the width between media and actions", function()
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(400, 200)
		frame.Parent = gui
		local icon = Instance.new("Frame")
		icon.Size = UDim2.fromOffset(40, 40)
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(60, 30)
		local item =
			Item.new({ app = app, Parent = frame, title = "Song", media = icon, actions = { button } })
		Harness.flush()
		local content = item.content
		expect(math.abs(item.Instance.AbsoluteSize.X - frame.AbsoluteSize.X) < 1).to.equal(true)
		expect(content.AbsoluteSize.X > frame.AbsoluteSize.X / 2).to.equal(true)
		expect(content.AbsolutePosition.X >= icon.AbsolutePosition.X + icon.AbsoluteSize.X).to.equal(true)
		expect(content.AbsolutePosition.X + content.AbsoluteSize.X <= button.AbsolutePosition.X + 1).to.equal(
			true
		)
	end)

	it("is a plain row without onClick", function()
		local item = Item.new({ app = app, Parent = gui, title = "Song" })
		expect(item.Instance:IsA("Frame")).to.equal(true)
		expect(item.click).to.equal(nil)
	end)

	it("can be clicked as a whole with onClick", function()
		local clicks = 0
		local disabled = Reactive.ref(false)
		local item = Item.new({
			app = app,
			Parent = gui,
			title = "Song",
			disabled = disabled,
			onClick = function()
				clicks += 1
			end,
		})
		local root = item.Instance
		expect(root:IsA("TextButton")).to.equal(true)
		expect(root.Selectable).to.equal(true)
		expect(root:HasTag("ui-item-clickable")).to.equal(true)
		item:click()
		expect(clicks).to.equal(1)
		disabled(true)
		expect(root.Selectable).to.equal(false)
		expect(root:HasTag("ui-disabled")).to.equal(true)
		expect(item.title:HasTag("ui-disabled")).to.equal(true)
		item:click()
		expect(clicks).to.equal(1)
	end)

	it("tags its variant, size and selection", function()
		local selected = Reactive.ref(false)
		local item = Item.new({
			app = app,
			Parent = gui,
			title = "Song",
			variant = "outline",
			size = "sm",
			selected = selected,
		})
		local root = item.Instance
		expect(root:HasTag("ui-item-variant-outline")).to.equal(true)
		expect(root:HasTag("ui-item-size-sm")).to.equal(true)
		expect(root:HasTag("ui-selected")).to.equal(false)
		selected(true)
		expect(root:HasTag("ui-selected")).to.equal(true)
		item:set("variant", "muted")
		expect(root:HasTag("ui-item-variant-outline")).to.equal(false)
		expect(root:HasTag("ui-item-variant-muted")).to.equal(true)
	end)

	it("rejects an unknown variant or size", function()
		expect(function()
			Item.new({ app = app, Parent = gui, variant = "neon" })
		end).to.throw()
		expect(function()
			Item.new({ app = app, Parent = gui, size = "xl" })
		end).to.throw()
	end)

	it("uses the muted colour for the muted variant", function()
		local item = Item.new({ app = app, Parent = gui, title = "Song", variant = "muted" })
		Harness.flush()
		expect(Harness.colorEq(Harness.styled(item.Instance, "BackgroundColor3"), app.theme:resolve("Muted"))).to.equal(
			true
		)
	end)
end
