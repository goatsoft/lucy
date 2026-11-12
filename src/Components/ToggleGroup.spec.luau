return function()
	local ToggleGroup = require(script.Parent.ToggleGroup)
	local Composables = require(script.Parent.Parent.Composables)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local GENRES = { "House", "Techno", { value = "hiphop", text = "Hip hop" } }

	it("makes one item per entry, in order, with their text", function()
		local group = ToggleGroup.new({ app = app, Parent = gui, items = GENRES })
		expect(#group.items).to.equal(3)
		expect(group.items[1].Text).to.equal("House")
		expect(group.items[3].Text).to.equal("Hip hop")
		expect(group.items[1].LayoutOrder < group.items[2].LayoutOrder).to.equal(true)
		expect(group.items[1].Parent).to.equal(group.Instance)
		expect(group.items[1]:HasTag("ui-toggle")).to.equal(true)
	end)

	describe("single", function()
		it("selects one value at a time", function()
			local group = ToggleGroup.new({ app = app, Parent = gui, items = GENRES })
			expect(group:get("value")).to.equal(false)
			group:select("Techno")
			expect(group:get("value")).to.equal("Techno")
			expect(group.items[2]:HasTag("ui-selected")).to.equal(true)
			group:select("hiphop")
			expect(group.items[2]:HasTag("ui-selected")).to.equal(false)
			expect(group.items[3]:HasTag("ui-selected")).to.equal(true)
		end)

		it("clears when the picked item is picked again, unless required", function()
			local group = ToggleGroup.new({ app = app, Parent = gui, items = GENRES, value = "House" })
			group:select("House")
			expect(group:get("value")).to.equal(false)
			local required =
				ToggleGroup.new({ app = app, Parent = gui, items = GENRES, value = "House", required = true })
			required:select("House")
			expect(required:get("value")).to.equal("House")
		end)

		it("keeps value in step with a ref, both ways", function()
			local genre = Reactive.ref("House")
			local group = ToggleGroup.new({ app = app, Parent = gui, items = GENRES, value = genre })
			expect(group.items[1]:HasTag("ui-selected")).to.equal(true)
			group:select("Techno")
			expect(genre()).to.equal("Techno")
			genre("hiphop")
			expect(group.items[3]:HasTag("ui-selected")).to.equal(true)
		end)

		it("takes number values", function()
			local group = ToggleGroup.new({ app = app, Parent = gui, items = { 1, 2, 3, 4, 5 } })
			expect(group.items[4].Text).to.equal("4")
			group:select(4)
			expect(group:get("value")).to.equal(4)
		end)
	end)

	describe("multiple", function()
		it("adds and removes values", function()
			local group = ToggleGroup.new({ app = app, Parent = gui, items = GENRES, type = "multiple" })
			expect(#group:get("value")).to.equal(0)
			group:select("House")
			group:select("hiphop")
			expect(table.concat(group:get("value"), ",")).to.equal("House,hiphop")
			expect(group.items[1]:HasTag("ui-selected")).to.equal(true)
			expect(group.items[3]:HasTag("ui-selected")).to.equal(true)
			group:select("House")
			expect(table.concat(group:get("value"), ",")).to.equal("hiphop")
			expect(group.items[1]:HasTag("ui-selected")).to.equal(false)
		end)

		it("reports each change through onValueChange", function()
			local seen = {}
			local group = ToggleGroup.new({
				app = app,
				Parent = gui,
				items = GENRES,
				type = "multiple",
				onValueChange = function(value)
					table.insert(seen, table.concat(value, "+"))
				end,
			})
			group:select("House")
			group:select("Techno")
			group:select("House")
			expect(table.concat(seen, ",")).to.equal("House,House+Techno,Techno")
		end)

		it("starts from a given list", function()
			local group = ToggleGroup.new({
				app = app,
				Parent = gui,
				items = GENRES,
				type = "multiple",
				value = { "Techno" },
			})
			expect(group.items[2]:HasTag("ui-selected")).to.equal(true)
		end)
	end)

	it("reports changes through onValueChange", function()
		local seen = {}
		local group = ToggleGroup.new({
			app = app,
			Parent = gui,
			items = GENRES,
			onValueChange = function(value)
				table.insert(seen, tostring(value))
			end,
		})
		group:select("House")
		group:select("Techno")
		expect(table.concat(seen, ",")).to.equal("House,Techno")
	end)

	it("emits select with the value from the player path only", function()
		local calls = {}
		local scope = Reactive.effectScope(true)
		local group = scope:run(function()
			Composables.useUiSound(app, {
				select = function(_, value)
					table.insert(calls, tostring(value))
				end,
			})
			return ToggleGroup.new({ app = app, Parent = gui, items = GENRES })
		end)
		group:select("Techno")
		group:set("value", "House")
		expect(table.concat(calls, ",")).to.equal("Techno")
		scope:stop()
	end)

	it("ignores the player while the group or an item is disabled", function()
		local group = ToggleGroup.new({
			app = app,
			Parent = gui,
			items = { "A", { value = "B", disabled = true } },
		})
		group:select("B")
		expect(group:get("value")).to.equal(false)
		expect(group.items[2].Interactable).to.equal(false)
		group:set("disabled", true)
		group:select("A")
		expect(group:get("value")).to.equal(false)
		expect(group.items[1].Interactable).to.equal(false)
	end)

	it("shows an item only while its visible is true, and the player can't pick it hidden", function()
		local tipped = Reactive.ref(false)
		local group = ToggleGroup.new({
			app = app,
			Parent = gui,
			items = { "Score", { value = "tips", text = "Supporters", visible = tipped } },
			value = "Score",
		})
		local item = group.items[2]
		expect(#group.items).to.equal(2)
		expect(item.Visible).to.equal(false)
		expect(item.Selectable).to.equal(false)
		group:select("tips")
		expect(group:get("value")).to.equal("Score")
		tipped(true)
		expect(group.items[2]).to.equal(item) -- the same button: the group is not made again
		expect(item.Visible).to.equal(true)
		expect(item.Selectable).to.equal(true)
		group:select("tips")
		expect(group:get("value")).to.equal("tips")
	end)

	it("lays out as a row by default, or a column", function()
		local row = ToggleGroup.new({ app = app, Parent = gui, items = GENRES })
		expect(row.Instance:FindFirstChildOfClass("UIListLayout").FillDirection).to.equal(
			Enum.FillDirection.Horizontal
		)
		local column = ToggleGroup.new({ app = app, Parent = gui, items = GENRES, orientation = "vertical" })
		expect(column.Instance:FindFirstChildOfClass("UIListLayout").FillDirection).to.equal(
			Enum.FillDirection.Vertical
		)
	end)

	it("sizes its items with size and still fits them", function()
		local group = ToggleGroup.new({ app = app, Parent = gui, items = GENRES, size = "sm" })
		expect(group.items[1]:HasTag("ui-toggle-size-sm")).to.equal(true)
		expect(group.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
		expect(group.Instance.Size).to.equal(UDim2.fromOffset(0, 0))
	end)

	it("puts an item's children in its slot, with no text of its own", function()
		local star = Instance.new("ImageLabel")
		local group =
			ToggleGroup.new({ app = app, Parent = gui, items = { { value = 1, children = { star } } } })
		local slot = group.items[1]:FindFirstChild("Slot")
		expect(group.items[1].Text).to.equal("")
		expect(star.Parent).to.equal(slot)
		expect((slot :: any).Label.Visible).to.equal(false)
	end)

	it("gives an item's icon and text its colours when picked", function()
		local group = ToggleGroup.new({
			app = app,
			Parent = gui,
			variant = "line",
			items = { { value = "a", text = "A", icon = "lucy:close" }, "b" },
			value = "b",
		})
		Harness.flush()
		local slot = group.items[1]:FindFirstChild("Slot") :: any
		local muted = app.theme:resolve("MutedForeground")
		expect(Harness.colorEq(Harness.styled(slot.Label, "TextColor3"), muted)).to.equal(true)
		expect(Harness.colorEq(Harness.styled(slot.Icon, "ImageColor3"), muted)).to.equal(true)
		group:select("a")
		Harness.flush()
		local on = app.theme:resolve("Foreground")
		expect(Harness.colorEq(Harness.styled(slot.Label, "TextColor3"), on)).to.equal(true)
		expect(Harness.colorEq(Harness.styled(slot.Icon, "ImageColor3"), on)).to.equal(true)
	end)

	describe("scroll", function()
		local LONG =
			{ "House", "Techno", "Dubstep", "Anthem", "Pop", "Hip hop", "Rave", "Disco", "Funk", "Garage" }

		local function narrow(): Frame
			local box = Instance.new("Frame")
			box.Size = UDim2.fromOffset(240, 200)
			box.Parent = gui
			return box
		end

		it("scrolls sideways in a row too long for its room, with its items in the scroller", function()
			if not Harness.laysOutLive() then
				return -- its height follows its items: live layout only
			end
			local group = ToggleGroup.new({ app = app, Parent = narrow(), items = LONG, scroll = true })
			Harness.flush()
			expect(group.scroller).to.be.ok()
			local frame = group.scroller.frame :: ScrollingFrame
			expect(frame.ScrollingDirection).to.equal(Enum.ScrollingDirection.X)
			expect(group.items[1]:IsDescendantOf(frame)).to.equal(true)
			-- As wide as its room; the whole row, its bottom edge included, inside the window
			expect(group.Instance.AbsoluteSize.X <= 241).to.equal(true)
			local item = group.items[1]
			local windowBottom = frame.AbsolutePosition.Y + frame.AbsoluteWindowSize.Y
			expect(item.AbsolutePosition.Y + item.AbsoluteSize.Y <= windowBottom + 1).to.equal(true)
		end)

		it("brings the picked item into view", function()
			if not Harness.laysOutLive() then
				return -- scrolling follows layout: live layout only
			end
			local value = Reactive.ref("House")
			local group = ToggleGroup.new({
				app = app,
				Parent = narrow(),
				items = LONG,
				value = value,
				scroll = true,
				required = true,
			})
			Harness.flush()
			local frame = group.scroller.frame :: ScrollingFrame
			value("Garage")
			Harness.flush()
			local last = group.items[#group.items]
			local left = last.AbsolutePosition.X
			local right = left + last.AbsoluteSize.X
			local viewLeft = frame.AbsolutePosition.X
			expect(frame.CanvasPosition.X > 0).to.equal(true)
			expect(left >= viewLeft - 1 and right <= viewLeft + frame.AbsoluteWindowSize.X + 1).to.equal(true)
		end)

		it("shows the picked item once it is laid out, when it was made off screen", function()
			if not Harness.laysOutLive() then
				return -- scrolling follows layout: live layout only
			end
			-- Made with no parent, as in a dialog that is not open yet
			local group = ToggleGroup.new({
				app = app,
				items = LONG,
				value = "Garage",
				scroll = true,
				required = true,
			})
			Harness.flush()
			group.Instance.Parent = narrow()
			Harness.flush()
			local frame = group.scroller.frame :: ScrollingFrame
			local last = group.items[#group.items]
			local left = last.AbsolutePosition.X
			local right = left + last.AbsoluteSize.X
			local viewLeft = frame.AbsolutePosition.X
			expect(left >= viewLeft - 1 and right <= viewLeft + frame.AbsoluteWindowSize.X + 1).to.equal(true)
		end)

		it("scrolls its own row, never a scroll area it sits in", function()
			if not Harness.laysOutLive() then
				return -- scrolling follows layout: live layout only
			end
			local page = Instance.new("ScrollingFrame")
			page.Size = UDim2.fromOffset(240, 120)
			page.CanvasSize = UDim2.fromOffset(0, 1200)
			page.Parent = gui
			local value = Reactive.ref("House")
			local group = ToggleGroup.new({
				app = app,
				Parent = page,
				items = LONG,
				value = value,
				scroll = true,
				required = true,
			})
			Harness.flush()
			-- The page is scrolled past the row; picking an item scrolls the row alone
			page.CanvasPosition = Vector2.new(0, 400)
			value("Garage")
			Harness.flush()
			expect((group.scroller.frame :: ScrollingFrame).CanvasPosition.X > 0).to.equal(true)
			expect(page.CanvasPosition.Y).to.equal(400)
		end)

		it("leaves a column, or a group without scroll, as it was", function()
			local column = ToggleGroup.new({
				app = app,
				Parent = gui,
				items = LONG,
				scroll = true,
				orientation = "vertical",
			})
			expect(column.scroller).to.equal(nil)
			local plain = ToggleGroup.new({ app = app, Parent = gui, items = LONG })
			expect(plain.scroller).to.equal(nil)
		end)
	end)

	describe("segmented", function()
		local Button = require(script.Parent.Button)
		local Component = require(script.Parent.Parent.Core.Component)

		it("draws the pill itself, as tall as a control of its size", function()
			for _, size in { "sm", "md", "lg", "xl" } do
				local group = ToggleGroup.new({
					app = app,
					Parent = gui,
					items = GENRES,
					variant = "segmented",
					size = size,
				})
				Harness.flush()
				local token = "Control" .. string.upper(string.sub(size, 1, 1)) .. string.sub(size, 2)
				expect(group.Instance:HasTag("ui-toggle-group-segmented")).to.equal(true)
				expect(group.Instance.Size.Y.Offset).to.equal(Component.metric(app, token))
				expect(group.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.X)
				expect(Harness.styled(group.Instance, "BackgroundTransparency")).to.equal(0)
			end
		end)

		it("lines up with a Button of the same size, its items filling the pill", function()
			if not Harness.laysOutLive() then
				return
			end
			local group = ToggleGroup.new({
				app = app,
				Parent = gui,
				items = GENRES,
				variant = "segmented",
				size = "lg",
			})
			local button = Button.new({ app = app, Parent = gui, text = "ACCEPT", size = "lg" })
			Harness.flush()
			expect(math.abs(group.Instance.AbsoluteSize.Y - button.Instance.AbsoluteSize.Y) < 1).to.equal(
				true
			)
			-- The items fill the pill inside its Space1 padding (in the gui's own scale)
			local control = Component.metric(app, "ControlLg")
			local scale = group.Instance.AbsoluteSize.Y / control
			local pad = (app.theme:resolve("Space1") :: UDim).Offset
			local item = group.items[1]
			expect(math.abs(item.AbsoluteSize.Y - (control - pad * 2) * scale) < 1).to.equal(true)
		end)

		it("raises the picked item on the background, the rest muted", function()
			local group = ToggleGroup.new({
				app = app,
				Parent = gui,
				items = GENRES,
				variant = "segmented",
				value = "House",
			})
			Harness.flush()
			local picked, other = group.items[1], group.items[2]
			expect(picked:HasTag("ui-toggle-variant-default")).to.equal(true)
			expect(Harness.styled(picked, "BackgroundTransparency")).to.equal(0)
			expect(
				Harness.colorEq(Harness.styled(picked, "BackgroundColor3"), app.theme:resolve("Background"))
			).to.equal(true)
			expect(Harness.colorEq(Harness.styled(other, "TextColor3"), app.theme:resolve("MutedForeground"))).to.equal(
				true
			)
		end)

		it("goes back to a plain row when the variant changes", function()
			local group = ToggleGroup.new({ app = app, Parent = gui, items = GENRES, variant = "segmented" })
			group:set("variant", "outline")
			Harness.flush()
			expect(group.Instance:HasTag("ui-toggle-group-segmented")).to.equal(false)
			expect(group.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
			expect(group.Instance.Size).to.equal(UDim2.fromOffset(0, 0))
			expect(Harness.styled(group.Instance, "BackgroundTransparency")).to.equal(1)
			expect(group.items[1]:HasTag("ui-toggle-variant-outline")).to.equal(true)
		end)

		it("keeps its pill height in a row that scrolls", function()
			local group = ToggleGroup.new({
				app = app,
				Parent = gui,
				items = GENRES,
				variant = "segmented",
				size = "lg",
				scroll = true,
			})
			local row = group.items[1].Parent :: Frame
			expect(row.Size.Y.Offset).to.equal(Component.metric(app, "ControlLg"))
		end)

		it("rejects an unknown variant", function()
			expect(function()
				ToggleGroup.new({ app = app, Parent = gui, items = GENRES, variant = "shiny" })
			end).to.throw()
		end)
	end)

	it("rejects an unknown type", function()
		expect(function()
			ToggleGroup.new({ app = app, Parent = gui, items = GENRES, type = "some" })
		end).to.throw()
	end)
end
