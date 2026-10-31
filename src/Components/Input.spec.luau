return function()
	local Input = require(script.Parent.Input)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("keeps value in step with a ref, both ways", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local name = Reactive.ref("JB")
		local field = Input.new({
			app = app,
			Parent = gui,
			value = name,
			placeholder = function()
				return if name() == "" then "Your name" else ""
			end,
		})
		expect(field.Instance.Text).to.equal("JB")
		field.Instance.Text = "Lucy"
		task.wait()
		expect(name()).to.equal("Lucy")
		name("")
		task.wait()
		expect(field.Instance.Text).to.equal("")
		expect(field.Instance.PlaceholderText).to.equal("Your name")
	end)

	it("renders a TextBox that keeps text on focus", function()
		local field = Input.new({ app = app, Parent = gui, placeholder = "Name" })
		expect(field.Instance:IsA("TextBox")).to.equal(true)
		expect(field.Instance.PlaceholderText).to.equal("Name")
		expect(field.Instance.ClearTextOnFocus).to.equal(false)
	end)

	it("writes typed text to state and calls onChange", function()
		local seen
		local field = Input.new({
			app = app,
			id = "name",
			Parent = gui,
			onChange = function(value)
				seen = value
			end,
		})
		field.Instance.Text = "JB"
		task.wait()
		expect(app.state:get("ui.name.value")).to.equal("JB")
		expect(seen).to.equal("JB")
	end)

	it("shows values written to state without echoing onChange", function()
		local calls = 0
		local field = Input.new({
			app = app,
			id = "name",
			Parent = gui,
			onChange = function()
				calls += 1
			end,
		})
		app.state:set("ui.name.value", "Lucy")
		task.wait()
		expect(field.Instance.Text).to.equal("Lucy")
		expect(calls).to.equal(0)
	end)

	it("locks when disabled", function()
		local field = Input.new({ app = app, Parent = gui, disabled = true })
		expect(field.Instance.TextEditable).to.equal(false)
		expect(field.Instance:HasTag("ui-disabled")).to.equal(true)
	end)

	it("takes its height from the density", function()
		local field = Input.new({ app = app, Parent = gui })
		expect(field.Instance.Size.Y.Offset).to.equal(36)
		app.input:setCaps(Harness.caps.mobile)
		expect(field.Instance.Size.Y.Offset).to.equal(44)
		app.input:setCaps(Harness.caps.console)
		expect(field.Instance.Size.Y.Offset).to.equal(52)
	end)

	describe("filterNumber", function()
		it("keeps digits, one leading minus and one point", function()
			expect(Input.filterNumber("12a3")).to.equal("123")
			expect(Input.filterNumber("-1.5.2")).to.equal("-1.52")
			expect(Input.filterNumber("1-2")).to.equal("12")
			expect(Input.filterNumber("--4")).to.equal("-4")
			expect(Input.filterNumber(" 3 000 ")).to.equal("3000")
			expect(Input.filterNumber("")).to.equal("")
		end)
	end)

	it("cuts typed text to maxLength, counting characters", function()
		local seen = {}
		local field = Input.new({
			app = app,
			id = "code",
			Parent = gui,
			maxLength = 5,
			onChange = function(value)
				table.insert(seen, value)
			end,
		})
		field.Instance.Text = "abcdefgh"
		task.wait()
		task.wait()
		expect(field.Instance.Text).to.equal("abcde")
		expect(app.state:get("ui.code.value")).to.equal("abcde")
		expect(seen[#seen]).to.equal("abcde")
		expect(table.find(seen, "abcdefgh")).to.equal(nil)
		field.Instance.Text = "h\u{e9}llo world"
		task.wait()
		task.wait()
		expect(field.Instance.Text).to.equal("h\u{e9}llo")
	end)

	it("keeps only a number when numeric", function()
		local field = Input.new({ app = app, id = "amount", Parent = gui, numeric = true })
		field.Instance.Text = "-12a.5x"
		task.wait()
		task.wait()
		expect(field.Instance.Text).to.equal("-12.5")
		expect(app.state:get("ui.amount.value")).to.equal("-12.5")
	end)

	it("wraps over several rows when multiline", function()
		local single = Input.new({ app = app, Parent = gui })
		local three = Input.new({ app = app, Parent = gui, multiline = true })
		local five = Input.new({ app = app, Parent = gui, multiline = true, rows = 5 })
		expect(three.Instance.MultiLine).to.equal(true)
		expect(three.Instance.TextWrapped).to.equal(true)
		expect(three.Instance.TextYAlignment).to.equal(Enum.TextYAlignment.Top)
		expect(three.Instance:HasTag("ui-input-multiline")).to.equal(true)
		expect(single.Instance.MultiLine).to.equal(false)
		expect(three.Instance.Size.Y.Offset > single.Instance.Size.Y.Offset).to.equal(true)
		expect(five.Instance.Size.Y.Offset > three.Instance.Size.Y.Offset).to.equal(true)
		local before = five.Instance.Size.Y.Offset
		app.input:setCaps(Harness.caps.console)
		expect(five.Instance.Size.Y.Offset > before).to.equal(true)
	end)

	it("filters only what the player types, not values written to state", function()
		local field = Input.new({ app = app, id = "weight", Parent = gui, numeric = true, maxLength = 3 })
		app.state:set("ui.weight.value", "12.5 kg")
		task.wait()
		task.wait()
		expect(field.Instance.Text).to.equal("12.5 kg")
		expect(app.state:get("ui.weight.value")).to.equal("12.5 kg")
	end)

	it("draws its border and focus ring inside its edge, so focus never grows it", function()
		local found = 0
		for _, rule in Input.rules do
			if
				rule.selector == ".ui-input::UIStroke"
				or rule.selector == ".ui-input.ui-focused::UIStroke"
			then
				found += 1
			end
			if rule.selector == ".ui-input::UIStroke" then
				expect(rule.properties.BorderStrokePosition).to.equal(Enum.BorderStrokePosition.Inner)
			end
		end
		expect(found).to.equal(2)
	end)
end
