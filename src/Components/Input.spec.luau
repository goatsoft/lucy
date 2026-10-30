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
end
