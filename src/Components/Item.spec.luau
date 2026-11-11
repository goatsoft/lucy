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

	describe("focus = tile", function()
		-- Two tiles stacked, each with a button on the right and two swatches under its text
		local function tiles()
			local list = Instance.new("Frame")
			list.Size = UDim2.fromOffset(400, 400)
			list.BackgroundTransparency = 1
			local layout = Instance.new("UIListLayout")
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = list
			list.Parent = gui
			local function tile(order: number)
				local wear, red, blue =
					Instance.new("TextButton"), Instance.new("TextButton"), Instance.new("TextButton")
				for _, button in { wear, red, blue } do
					button.Size = UDim2.fromOffset(60, 30)
				end
				local swatches = Instance.new("Frame")
				swatches.Size = UDim2.fromOffset(140, 30)
				swatches.BackgroundTransparency = 1
				local row = Instance.new("UIListLayout")
				row.FillDirection = Enum.FillDirection.Horizontal
				row.Parent = swatches
				red.Parent, blue.Parent = swatches, swatches
				local item = Item.new({
					app = app,
					Parent = list,
					LayoutOrder = order,
					title = `Tee {order}`,
					focus = "tile",
					actions = { wear },
					children = { swatches },
				})
				return item, wear, red, blue
			end
			local first, wear, red, blue = tile(1)
			local second, wear2 = tile(2)
			Harness.flush()
			app.input:setMode("gamepad")
			return first, wear, red, blue, second, wear2
		end

		it("is one stop, with its content under the text", function()
			local first, _, red = tiles()
			local root = first.Instance
			expect(root:IsA("GuiButton")).to.equal(true)
			expect(root.Selectable).to.equal(true)
			expect(root:HasTag("ui-tile")).to.equal(true)
			expect(red:IsDescendantOf(first.content)).to.equal(true)
			expect(first:get("entered")).to.equal(false)
			-- Keys and the gamepad's default focus see the tile, not what is in it
			local stops = app.input:selectables(gui)
			expect(table.find(stops, root) ~= nil).to.equal(true)
			expect(table.find(stops, red)).to.equal(nil)
		end)

		it("takes the focus that lands inside it while closed", function()
			local first, wear = tiles()
			app.input:focus(wear)
			expect(app.input:focused()).to.equal(first.Instance)
			expect(first:get("entered")).to.equal(false)
		end)

		it("steps in with enter, A or Enter, onto its first control", function()
			local first, wear, red = tiles()
			app.input:focus(first.Instance)
			app.input:activate()
			expect(first:get("entered")).to.equal(true)
			expect(app.input:focused()).to.equal(wear)
			local root = first.Instance
			expect(root.SelectionGroup).to.equal(true)
			expect(root.SelectionBehaviorDown).to.equal(Enum.SelectionBehavior.Stop)
			expect(root.Selectable).to.equal(false)
			-- Inside, keys walk only its own controls
			local stops = app.input:selectables(app.input:topScope().root)
			expect(table.find(stops, red) ~= nil).to.equal(true)
			app.input:focus(red)
			expect(app.input:focused()).to.equal(red)
		end)

		it("steps in when the D-pad moves from the tile onto a control in it", function()
			local first, wear = tiles()
			app.input:focus(first.Instance)
			app.input:focus(wear)
			expect(first:get("entered")).to.equal(true)
			expect(app.input:focused()).to.equal(wear)
		end)

		it("points left and right into it, up and down at the tiles around it", function()
			local first, wear, _, _, second = tiles()
			app.input:focus(first.Instance)
			expect(first.Instance.NextSelectionRight).to.equal(wear)
			expect(first.Instance.NextSelectionLeft).to.equal(wear)
			expect(first.Instance.NextSelectionDown).to.equal(second.Instance)
			app.input:focus(second.Instance)
			expect(second.Instance.NextSelectionUp).to.equal(first.Instance)
		end)

		it("steps back out onto the tile with back (B)", function()
			local first, wear = tiles()
			first:enter()
			expect(app.input:focused()).to.equal(wear)
			expect(app.input:back()).to.equal(true)
			expect(first:get("entered")).to.equal(false)
			expect(first.Instance.Selectable).to.equal(true)
			expect(first.Instance.SelectionGroup).to.equal(false)
			expect(app.input:focused()).to.equal(first.Instance)
		end)

		it("closes when focus goes elsewhere", function()
			local first, _, _, _, second = tiles()
			first:enter()
			app.input:focus(second.Instance)
			expect(first:get("entered")).to.equal(false)
			expect(app.input:topScope()).to.equal(nil)
		end)

		it("leaves the mouse alone: a click inside still reaches the control", function()
			local first, wear = tiles()
			app.input:setMode("mouse")
			app.input:focus(wear)
			expect(app.input:focused()).to.equal(wear)
			expect(first:get("entered")).to.equal(false)
		end)

		it("calls onClick on a click, steps in on A", function()
			local clicks = 0
			local wear = Instance.new("TextButton")
			local item = Item.new({
				app = app,
				Parent = gui,
				title = "Tee",
				focus = "tile",
				actions = { wear },
				onClick = function()
					clicks += 1
				end,
			})
			Harness.flush()
			app.input:setMode("mouse")
			item:click()
			expect(clicks).to.equal(1)
			app.input:setMode("gamepad")
			app.input:focus(item.Instance)
			item:click()
			expect(clicks).to.equal(1)
			expect(item:get("entered")).to.equal(true)
		end)

		it("rejects an unknown focus", function()
			expect(function()
				Item.new({ app = app, Parent = gui, focus = "grid" })
			end).to.throw()
		end)
	end)

	it("puts children under the text", function()
		local extra = Instance.new("Frame")
		local item = Item.new({ app = app, Parent = gui, title = "Song", children = { extra } })
		expect(extra:IsDescendantOf(item.content)).to.equal(true)
		expect(extra.LayoutOrder > item.description.LayoutOrder).to.equal(true)
	end)

	it("uses the muted colour for the muted variant", function()
		local item = Item.new({ app = app, Parent = gui, title = "Song", variant = "muted" })
		Harness.flush()
		expect(Harness.colorEq(Harness.styled(item.Instance, "BackgroundColor3"), app.theme:resolve("Muted"))).to.equal(
			true
		)
	end)
end
