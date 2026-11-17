return function()
	local Tabs = require(script.Parent.Tabs)
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

	local function panels()
		local songs, moves = Instance.new("Frame"), Instance.new("Frame")
		return songs,
			moves,
			{
				{ value = "songs", text = "Songs", content = songs },
				{ value = "moves", text = "Moves", content = moves },
			}
	end

	it("shows the first tab by default", function()
		local songs, moves, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items })
		expect(tabs:get("value")).to.equal("songs")
		expect(tabs.panels.songs.Visible).to.equal(true)
		expect(tabs.panels.moves.Visible).to.equal(false)
		expect(songs.Parent).to.equal(tabs.panels.songs)
		expect(moves.Parent).to.equal(tabs.panels.moves)
	end)

	it("has a tab bar with a trigger per tab", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items })
		expect(#tabs.list.items).to.equal(2)
		expect(tabs.list.items[2].Text).to.equal("Moves")
		expect(tabs.list.items[1]:HasTag("ui-selected")).to.equal(true)
	end)

	it("lines a line tab's first words up with the content's edge, the tabs a gap apart", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, variant = "line" })
		Harness.flush()
		task.wait()
		local first, second = tabs.list.items[1], tabs.list.items[2]
		local row = tabs.list.Instance :: GuiObject
		-- no side padding: the tab is as wide as its words and starts at the row's edge
		expect(math.abs(first.AbsolutePosition.X - row.AbsolutePosition.X) < 1).to.equal(true)
		expect(math.abs(first.AbsoluteSize.X - first.TextBounds.X) < 1).to.equal(true)
		local gap = second.AbsolutePosition.X - (first.AbsolutePosition.X + first.AbsoluteSize.X)
		expect(gap >= 16).to.equal(true)
	end)

	it("draws a line tab's underline bold, a little under the tab", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, variant = "line" })
		Harness.flush()
		task.wait()
		local first = tabs.list.items[1]
		local line = first:FindFirstChild("Indicator") :: Frame
		expect(line.Size.Y.Offset).to.equal(4)
		local itemBottom = first.AbsolutePosition.Y + first.AbsoluteSize.Y
		expect(line.AbsolutePosition.Y + line.AbsoluteSize.Y > itemBottom).to.equal(true)
	end)

	it("underlines the picked tab with the line variant", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, variant = "line" })
		local first, second = tabs.list.items[1], tabs.list.items[2]
		local firstLine = first:FindFirstChild("Indicator") :: Frame
		local secondLine = second:FindFirstChild("Indicator") :: Frame
		expect(firstLine.Visible).to.equal(true)
		expect(secondLine.Visible).to.equal(false)
		Harness.flush()
		-- no button look: no fill, muted text until picked, and the line in the primary colour
		expect(Harness.styled(first, "BackgroundTransparency")).to.equal(1)
		expect(Harness.colorEq(Harness.styled(first, "TextColor3"), app.theme:resolve("Foreground"))).to.equal(
			true
		)
		expect(Harness.colorEq(Harness.styled(second, "TextColor3"), app.theme:resolve("MutedForeground"))).to.equal(
			true
		)
		expect(Harness.colorEq(Harness.styled(firstLine, "BackgroundColor3"), app.theme:resolve("Primary"))).to.equal(
			true
		)
		tabs:select("moves")
		expect(firstLine.Visible).to.equal(false)
		expect(secondLine.Visible).to.equal(true)
	end)

	it("shows no underline with the other variants", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items })
		expect((tabs.list.items[1]:FindFirstChild("Indicator") :: Frame).Visible).to.equal(false)
	end)

	it("fits its row of tabs to the tabs, in a bar that scrolls past its room", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, size = "sm" })
		expect(tabs.list.scroller).to.be.ok()
		local row = tabs.list.items[1].Parent :: Frame
		expect(row.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
		expect(tabs.list.items[1]:HasTag("ui-toggle-size-sm")).to.equal(true)
	end)

	it("fits its tab bar to the tabs with scroll = false", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, scroll = false })
		expect(tabs.list.scroller).to.equal(nil)
		expect(tabs.list.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
	end)

	it("switches panels when a tab is picked, and never clears", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items })
		tabs:select("moves")
		expect(tabs:get("value")).to.equal("moves")
		expect(tabs.panels.songs.Visible).to.equal(false)
		expect(tabs.panels.moves.Visible).to.equal(true)
		tabs.list:select("moves")
		expect(tabs:get("value")).to.equal("moves")
		tabs.list:select("songs")
		expect(tabs:get("value")).to.equal("songs")
	end)

	it("keeps value in step with a ref, both ways", function()
		local _, _, items = panels()
		local current = Reactive.ref("moves")
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, value = current })
		expect(tabs.panels.moves.Visible).to.equal(true)
		tabs:select("songs")
		expect(current()).to.equal("songs")
		current("moves")
		expect(tabs.list.items[2]:HasTag("ui-selected")).to.equal(true)
	end)

	it("starts an empty bound value on the first tab", function()
		local _, _, items = panels()
		local section = app.state:ref("shop.section")
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, value = section })
		expect(section()).to.equal("songs")
		expect(tabs.panels.songs.Visible).to.equal(true)
	end)

	it("is just the tab bar when no tab has content, with no room under it", function()
		local tabs = Tabs.new({
			app = app,
			Parent = gui,
			items = { { value = "combo", text = "Best combo" }, { value = "hype", text = "Hype" } },
		})
		local holder = tabs.Instance:FindFirstChild("Panels") :: Frame
		expect(holder.Visible).to.equal(false)
		local _, _, items = panels()
		local withContent = Tabs.new({ app = app, Parent = gui, items = items })
		expect((withContent.Instance:FindFirstChild("Panels") :: Frame).Visible).to.equal(true)
	end)

	it("builds a panel from a function", function()
		local tabs = Tabs.new({
			app = app,
			Parent = gui,
			items = {
				{
					value = "a",
					text = "A",
					content = function()
						local label = Instance.new("TextLabel")
						label.Name = "Built"
						return label
					end,
				},
			},
		})
		expect(tabs.panels.a:FindFirstChild("Built")).to.be.ok()
	end)

	describe("building panels", function()
		local Button = require(script.Parent.Button)
		local Devtools = require(script.Parent.Parent.Core.Devtools)

		-- Three tabs built by functions. Returns the items, how often each built, the buttons made.
		local function built()
			local counts: { [string]: number } = { songs = 0, moves = 0, drinks = 0 }
			local buttons: { [string]: any } = {}
			local items = {}
			for _, name in { "songs", "moves", "drinks" } do
				table.insert(items, {
					value = name,
					content = function()
						counts[name] += 1
						buttons[name] = Button.new({ app = app, text = name })
						return buttons[name]
					end,
				})
			end
			return items, counts, buttons
		end

		it("builds only the tab that shows, and each other tab the first time it shows", function()
			local items, counts, buttons = built()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items })
			expect(counts.songs).to.equal(1)
			expect(counts.moves).to.equal(0)
			expect(buttons.songs.Instance.Parent).to.equal(tabs.panels.songs)
			-- the panel frames are there from the start, empty
			expect(#tabs.panels.moves:GetChildren()).to.equal(0)
			tabs:select("moves")
			expect(counts.moves).to.equal(1)
			expect(buttons.moves.Instance.Parent).to.equal(tabs.panels.moves)
			tabs:select("songs")
			tabs:select("moves")
			expect(counts.songs).to.equal(1)
			expect(counts.moves).to.equal(1)
			expect(counts.drinks).to.equal(0)
		end)

		it("builds a tab shown by a state write or a bound ref", function()
			local items, counts = built()
			local tabs = Tabs.new({ app = app, Parent = gui, id = "shop", items = items })
			app.state:set("ui.shop.value", "drinks")
			expect(counts.drinks).to.equal(1)
			tabs:destroy()
			local more, moreCounts = built()
			local section = Reactive.ref("songs")
			Tabs.new({ app = app, Parent = gui, items = more, value = section })
			section("moves")
			expect(moreCounts.moves).to.equal(1)
		end)

		it("builds the first tab of an empty bound value", function()
			local items, counts = built()
			local section = app.state:ref("shop.section")
			Tabs.new({ app = app, Parent = gui, items = items, value = section })
			expect(counts.songs).to.equal(1)
			expect(counts.moves).to.equal(0)
		end)

		it("hands a builder its panel, and keeps what the builder parents there", function()
			local got
			local tabs = Tabs.new({
				app = app,
				Parent = gui,
				items = {
					{
						value = "a",
						content = function(panel)
							got = panel
							local label = Instance.new("TextLabel")
							label.Name = "Made"
							label.Parent = panel
						end,
					},
				},
			})
			expect(got).to.equal(tabs.panels.a)
			expect(tabs.panels.a:FindFirstChild("Made")).to.be.ok()
		end)

		it("builds every tab at once with mount = now", function()
			local items, counts, buttons = built()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items, mount = "now" })
			expect(counts.songs).to.equal(1)
			expect(counts.moves).to.equal(1)
			expect(counts.drinks).to.equal(1)
			expect(buttons.drinks.Instance.Parent).to.equal(tabs.panels.drinks)
			tabs:select("moves")
			expect(counts.moves).to.equal(1)
		end)

		it("builds a tab ahead with build", function()
			local items, counts = built()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items })
			tabs:build("drinks")
			expect(counts.drinks).to.equal(1)
			expect(tabs:get("value")).to.equal("songs")
			tabs:build()
			tabs:build("drinks")
			expect(counts.songs).to.equal(1)
			expect(counts.drinks).to.equal(1)
		end)

		it("removes the tab left with keep = false, and builds it again on the way back", function()
			local items, counts, buttons = built()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items, keep = false })
			local first = buttons.songs
			tabs:select("moves")
			expect(first.destroyed).to.equal(true)
			expect(#tabs.panels.songs:GetChildren()).to.equal(0)
			tabs:select("songs")
			expect(counts.songs).to.equal(2)
			expect(buttons.songs.Instance.Parent).to.equal(tabs.panels.songs)
			expect(buttons.moves.destroyed).to.equal(true)
		end)

		it("keeps content made ahead of time, whatever keep says", function()
			local songs, _, items = panels()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items, keep = false })
			tabs:select("moves")
			expect(songs.Parent).to.equal(tabs.panels.songs)
		end)

		it("refuses keep with mount = now", function()
			local items = built()
			expect(function()
				Tabs.new({ app = app, Parent = gui, items = items, mount = "now", keep = false })
			end).to.throw("keep")
		end)

		it("builds the next tab before LB / RB move focus into it", function()
			local items, counts, buttons = built()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items })
			app.input:setMode("gamepad")
			app.input:markFocus(buttons.songs.Instance)
			expect(app.input:shoulder(1)).to.equal(true)
			expect(tabs:get("value")).to.equal("moves")
			expect(app.input:focused()).to.equal(buttons.moves.Instance)
			-- built by the press itself, so a batch holding the value's watcher back cannot delay it
			Reactive.batch(function()
				app.input:shoulder(1)
				expect(counts.drinks).to.equal(1)
			end)
		end)

		it("tells Devtools which tabs are not built yet", function()
			local items = built()
			local tabs = Tabs.new({ app = app, Parent = gui, id = "shop", items = items })
			local node = Devtools.tree({ app = app, root = "shop" })[1]
			expect(table.concat(node.unbuilt, ",")).to.equal("moves,drinks")
			tabs:select("drinks")
			node = Devtools.tree({ app = app, root = "shop" })[1]
			expect(table.concat(node.unbuilt, ",")).to.equal("moves")
			tabs:select("moves")
			node = Devtools.tree({ app = app, root = "shop" })[1]
			expect(node.unbuilt).to.equal(nil)
		end)
	end)

	it("reports changes and emits select once per pick", function()
		local _, _, items = panels()
		local seen, calls = {}, {}
		local scope = Reactive.effectScope(true)
		local tabs = scope:run(function()
			Composables.useUiSound(app, {
				select = function(_, value)
					table.insert(calls, value)
				end,
			})
			return Tabs.new({
				app = app,
				Parent = gui,
				items = items,
				onValueChange = function(value)
					table.insert(seen, value)
				end,
			})
		end)
		tabs:select("moves")
		expect(table.concat(seen, ",")).to.equal("moves")
		expect(table.concat(calls, ",")).to.equal("moves")
		scope:stop()
	end)

	describe("shoulder buttons", function()
		local Button = require(script.Parent.Button)

		local function withButtons(extra: { [string]: any }?)
			local first, second =
				Button.new({ app = app, text = "One" }), Button.new({ app = app, text = "Two" })
			local items = {
				{ value = "a", text = "A", content = first },
				{ value = "b", text = "B", content = second },
				{ value = "c", text = "C" },
			}
			local props = { app = app, Parent = gui, items = items }
			local more: { [string]: any } = extra or {}
			for key, value in more do
				props[key] = value
			end
			return Tabs.new(props), first, second
		end

		beforeEach(function()
			app.input:setMode("gamepad")
		end)

		it("moves to the next and previous tab, wrapping, when focus is on the tab bar", function()
			local tabs = withButtons()
			app.input:markFocus(tabs.list.items[1])
			expect(app.input:shoulder(1)).to.equal(true)
			expect(tabs:get("value")).to.equal("b")
			expect(app.input:focused()).to.equal(tabs.list.items[2])
			app.input:shoulder(-1)
			app.input:shoulder(-1)
			expect(tabs:get("value")).to.equal("c")
			app.input:shoulder(1)
			expect(tabs:get("value")).to.equal("a")
		end)

		it("moves focus into the new panel when focus was in the old one", function()
			local tabs, first, second = withButtons()
			app.input:markFocus(first.Instance)
			app.input:shoulder(1)
			expect(tabs:get("value")).to.equal("b")
			expect(app.input:focused()).to.equal(second.Instance)
			app.input:shoulder(1)
			expect(app.input:focused()).to.equal(tabs.list.items[3])
		end)

		it("skips disabled tabs", function()
			local tabs = Tabs.new({
				app = app,
				Parent = gui,
				items = { "a", { value = "b", disabled = true }, "c" },
			})
			app.input:markFocus(tabs.list.items[1])
			app.input:shoulder(1)
			expect(tabs:get("value")).to.equal("c")
		end)

		it("skips hidden tabs, as they come and go", function()
			local shown = Reactive.ref(false)
			local tabs = Tabs.new({
				app = app,
				Parent = gui,
				items = { "a", "b", { value = "c", visible = shown } },
			})
			app.input:markFocus(tabs.list.items[2])
			tabs:select("b")
			app.input:shoulder(1)
			expect(tabs:get("value")).to.equal("a")
			shown(true)
			app.input:shoulder(-1)
			expect(tabs:get("value")).to.equal("c")
		end)

		it("ignores them when focus is outside, or the tabs are disabled", function()
			local tabs = withButtons()
			local outside = Button.new({ app = app, Parent = gui })
			app.input:markFocus(outside.Instance)
			expect(app.input:shoulder(1)).to.equal(false)
			expect(tabs:get("value")).to.equal("a")
			app.input:markFocus(tabs.list.items[1])
			tabs:set("disabled", true)
			app.input:shoulder(1)
			expect(tabs:get("value")).to.equal("a")
		end)

		it("switches only the innermost tabs around the focus", function()
			local inner = Tabs.new({ app = app, items = { "x", "y" } })
			local outer = Tabs.new({
				app = app,
				Parent = gui,
				items = { { value = "a", content = inner }, "b" },
			})
			app.input:markFocus(inner.list.items[1])
			app.input:shoulder(1)
			expect(inner:get("value")).to.equal("y")
			expect(outer:get("value")).to.equal("a")
		end)

		it("works with focus on the tab bar placed apart from the tabs (a Sheet's header)", function()
			local tabs = withButtons()
			local header = Instance.new("Frame")
			header.Parent = gui
			tabs.bar.Parent = header
			app.input:markFocus(tabs.list.items[1])
			expect(app.input:shoulder(1)).to.equal(true)
			expect(tabs:get("value")).to.equal("b")
			expect(app.input:focused()).to.equal(tabs.list.items[2])
			local plain = withButtons({ hints = false })
			plain.bar.Parent = header
			app.input:markFocus(plain.list.items[1])
			expect(app.input:shoulder(-1)).to.equal(true)
			expect(plain:get("value")).to.equal("c")
		end)

		it("can be turned off", function()
			local tabs = withButtons({ shoulderButtons = false })
			app.input:markFocus(tabs.list.items[1])
			expect(app.input:shoulder(1)).to.equal(false)
			expect(tabs:get("value")).to.equal("a")
		end)
	end)

	describe("shoulder hints", function()
		it("shows LB and RB either side of the bar on a controller only", function()
			local _, _, items = panels()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items })
			expect(tabs.hints).to.be.ok()
			local back, forward = tabs.hints.back, tabs.hints.forward
			expect(back:get("gamepad")).to.equal(Enum.KeyCode.ButtonL1)
			expect(forward:get("gamepad")).to.equal(Enum.KeyCode.ButtonR1)
			local bar = tabs.list.Instance.Parent :: Frame
			-- each in a holder in the bar (the room under the tabs, so they centre on them)
			local backHolder, forwardHolder = back.Instance.Parent :: Frame, forward.Instance.Parent :: Frame
			expect(backHolder.Parent).to.equal(bar)
			expect(forwardHolder.Parent).to.equal(bar)
			expect(backHolder.LayoutOrder < tabs.list.Instance.LayoutOrder).to.equal(true)
			expect(forwardHolder.LayoutOrder > tabs.list.Instance.LayoutOrder).to.equal(true)
			app.input:setMode("mouse")
			expect(back.Instance.Visible).to.equal(false)
			expect(backHolder.Visible).to.equal(false)
			app.input:setMode("gamepad")
			expect(back.Instance.Visible).to.equal(true)
			expect(forward.Instance.Visible).to.equal(true)
			expect(backHolder.Visible).to.equal(true)
		end)

		it("centres the hints on the tabs: the same room under them as the bar keeps", function()
			local _, _, items = panels()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items, variant = "line" })
			local below = tabs.list.below()
			expect(below > 0).to.equal(true)
			for _, hint in { tabs.hints.back, tabs.hints.forward } do
				local holder = hint.Instance.Parent :: Frame
				local padding = holder:FindFirstChildOfClass("UIPadding") :: UIPadding
				expect(padding.PaddingBottom).to.equal(UDim.new(0, below))
			end
		end)

		it("puts RB right after line tabs (the bar hugs them), and fills the row otherwise", function()
			local _, _, items = panels()
			local tabs = Tabs.new({ app = app, Parent = gui, items = items, variant = "line" })
			local flex = tabs.list.Instance:FindFirstChildOfClass("UIFlexItem") :: UIFlexItem
			expect(flex.FlexMode).to.equal(Enum.UIFlexMode.Shrink)
			expect(tabs.list.Instance.Size.X.Scale).to.equal(0)
			tabs:set("variant", "default")
			expect(flex.FlexMode).to.equal(Enum.UIFlexMode.Fill)
			expect(tabs.list.Instance.Size.X.Scale).to.equal(1)
		end)

		it("shows none with hints = false or without shoulder buttons", function()
			local _, _, items = panels()
			expect(Tabs.new({ app = app, Parent = gui, items = items, hints = false }).hints).to.equal(nil)
			local _, _, more = panels()
			expect(Tabs.new({ app = app, Parent = gui, items = more, shoulderButtons = false }).hints).to.equal(
				nil
			)
		end)

		it("can keep the hints while the game handles LB and RB itself", function()
			local _, _, items = panels()
			local tabs =
				Tabs.new({ app = app, Parent = gui, items = items, shoulderButtons = false, hints = true })
			expect(tabs.hints).to.be.ok()
		end)
	end)

	it("passes the segmented look to its tab bar", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, variant = "segmented", size = "lg" })
		local row = tabs.list.items[1].Parent :: Frame
		expect(row:HasTag("ui-toggle-group-segmented")).to.equal(true)
		tabs:set("size", "xl")
		expect(tabs.list.items[1]:HasTag("ui-toggle-size-xl")).to.equal(true)
	end)

	it("fits itself to the tab bar when it is just a bar that does not scroll", function()
		local tabs = Tabs.new({ app = app, Parent = gui, items = { "basic", "advanced" }, scroll = false })
		expect(tabs.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
		expect(tabs.Instance.Size).to.equal(UDim2.fromOffset(0, 0))
		local _, _, items = panels()
		local full = Tabs.new({ app = app, Parent = gui, items = items, scroll = false })
		expect(full.Instance.Size).to.equal(UDim2.fromScale(1, 0))
	end)

	it("destroys its tab bar with it", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items })
		local list = tabs.list
		tabs:destroy()
		expect(list.destroyed).to.equal(true)
	end)
end
