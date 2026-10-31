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

	it("fits its tab bar to the tabs", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items, size = "sm" })
		expect(tabs.list.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
		expect(tabs.list.items[1]:HasTag("ui-toggle-size-sm")).to.equal(true)
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

		it("can be turned off", function()
			local tabs = withButtons({ shoulderButtons = false })
			app.input:markFocus(tabs.list.items[1])
			expect(app.input:shoulder(1)).to.equal(false)
			expect(tabs:get("value")).to.equal("a")
		end)
	end)

	it("destroys its tab bar with it", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items })
		local list = tabs.list
		tabs:destroy()
		expect(list.destroyed).to.equal(true)
	end)
end
