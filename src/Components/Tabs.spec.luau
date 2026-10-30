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

	it("destroys its tab bar with it", function()
		local _, _, items = panels()
		local tabs = Tabs.new({ app = app, Parent = gui, items = items })
		local list = tabs.list
		tabs:destroy()
		expect(list.destroyed).to.equal(true)
	end)
end
