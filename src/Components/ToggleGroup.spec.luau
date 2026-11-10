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
			-- As wide as its room, as tall as its items
			expect(group.Instance.AbsoluteSize.X <= 241).to.equal(true)
			expect(math.abs(group.Instance.AbsoluteSize.Y - group.items[1].AbsoluteSize.Y) <= 2).to.equal(
				true
			)
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

	it("rejects an unknown type", function()
		expect(function()
			ToggleGroup.new({ app = app, Parent = gui, items = GENRES, type = "some" })
		end).to.throw()
	end)
end
