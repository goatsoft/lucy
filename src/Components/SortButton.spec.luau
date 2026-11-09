return function()
	local SortButton = require(script.Parent.SortButton)
	local Icon = require(script.Parent.Icon)
	local Composables = require(script.Parent.Parent.Composables)
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

	local COLUMNS = {
		{ key = "name", header = "Name" },
		{ key = "genre", header = "Genre" },
		{ key = "rarity", header = "Rarity", descFirst = true },
	}
	local function model(options: { [string]: any }?)
		local opts = table.clone(options or {})
		opts.columns = COLUMNS
		opts.data = opts.data or {}
		local m
		Reactive.effectScope(true):run(function()
			m = Composables.useSort(opts)
		end)
		return m
	end
	-- A press, then a pause past the 50 ms guard against a double click.
	local function press(button)
		button:click()
		task.wait(0.06)
	end
	local function make(sort, column: string, props: { [string]: any }?)
		local p = table.clone(props or {})
		p.app = app
		p.Parent = gui
		p.sort = sort
		p.column = column
		return SortButton.new(p)
	end

	it("is a button labelled with the column's header", function()
		local button = make(model(), "name")
		expect(button.Instance:IsA("TextButton")).to.equal(true)
		expect(button.label.Text).to.equal("Name")
		local named = make(model(), "genre", { text = "STYLE" })
		expect(named.label.Text).to.equal("STYLE")
	end)

	it("pads its sides when sized to its words, not as a table's header", function()
		expect(make(model(), "name").Instance:HasTag("ui-sort-hug")).to.equal(true)
		local header = make(model(), "name", { size = UDim2.fromOffset(120, 28) })
		expect(header.Instance:HasTag("ui-sort-hug")).to.equal(false)
	end)

	it("sorts its column when pressed, and shows which way", function()
		local sort = model()
		local button = make(sort, "rarity")
		expect(button.icon.Instance.Visible).to.equal(false)
		expect(button.Instance:HasTag("ui-sorted")).to.equal(false)
		press(button)
		expect(sort.sortedBy("rarity")).to.equal("desc")
		local down: any = Icon.resolve("lucy:chevron-down")
		expect(button.icon.Instance.Visible).to.equal(true)
		expect(button.icon.Instance.Image).to.equal(down.image)
		expect(button.Instance:HasTag("ui-sorted")).to.equal(true)
		press(button)
		local up: any = Icon.resolve("lucy:chevron-up")
		expect(button.icon.Instance.Image).to.equal(up.image)
	end)

	it("numbers its place only while more than one column sorts", function()
		local sort = model({ multi = true })
		local rarity = make(sort, "rarity")
		local name = make(sort, "name")
		press(rarity)
		expect(rarity.priority.Visible).to.equal(false)
		press(name)
		expect(rarity.priority.Visible).to.equal(true)
		expect(rarity.priority.Text).to.equal("1")
		expect(name.priority.Text).to.equal("2")
		press(rarity)
		press(rarity)
		expect(rarity.priority.Visible).to.equal(false)
		expect(name.priority.Visible).to.equal(false)
	end)

	it("is not pressable for a column that does not sort", function()
		local sort = model()
		local button = make(sort, "name", { disabled = true })
		press(button)
		expect(sort.sortedBy("name")).to.equal(false)
		expect(button.Instance.Selectable).to.equal(false)
	end)

	it("sorts on Enter when focused", function()
		local sort = model()
		local button = make(sort, "genre")
		app.input:setMode("keyboard")
		app.input:focus(button.Instance)
		app.input:activate()
		expect(sort.sortedBy("genre")).to.equal("asc")
	end)

	it("fires Activated and calls onClick after sorting", function()
		local sort = model()
		local seen
		local button = make(sort, "name", {
			onClick = function()
				seen = sort.sortedBy("name")
			end,
		})
		local fired = 0
		button.Activated:Connect(function()
			fired += 1
		end)
		press(button)
		expect(seen).to.equal("asc")
		expect(fired).to.equal(1)
	end)

	describe("slot", function()
		it("holds children after the label and before the chevron", function()
			local mark = Icon.new({ app = app, icon = "lucy:close" })
			local button = make(model(), "name", { children = { mark } })
			expect(button.label.Visible).to.equal(false)
			expect(mark.Instance.Parent).to.equal(button.Instance)
			expect(button.label.LayoutOrder < mark.Instance.LayoutOrder).to.equal(true)
			expect(mark.Instance.LayoutOrder < button.icon.Instance.LayoutOrder).to.equal(true)
		end)

		it("brightens its children with the label when it sorts, the chevron stays muted", function()
			local mark = Icon.new({ app = app, icon = "lucy:close" })
			local button = make(model(), "name", { children = { mark } })
			Harness.flush()
			local muted = app.theme:resolve("MutedForeground")
			expect(Harness.colorEq(Harness.styled(mark.Instance, "ImageColor3"), muted)).to.equal(true)
			press(button)
			Harness.flush()
			local bright = app.theme:resolve("Foreground")
			expect(Harness.colorEq(Harness.styled(button.label, "TextColor3"), bright)).to.equal(true)
			expect(Harness.colorEq(Harness.styled(mark.Instance, "ImageColor3"), bright)).to.equal(true)
			expect(Harness.colorEq(Harness.styled(button.icon.Instance, "ImageColor3"), muted)).to.equal(true)
		end)
	end)
end
