return function()
	local NumberField = require(script.Parent.NumberField)
	local Composables = require(script.Parent.Parent.Composables)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Reactive = require(script.Parent.Parent.Core.Reactive)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	describe("snap", function()
		it("steps from min when there is one, from zero when not", function()
			expect(NumberField.snap(7, 2, 20, 4)).to.equal(6)
			expect(NumberField.snap(7, -math.huge, math.huge, 5)).to.equal(5)
			expect(NumberField.snap(-8, -math.huge, math.huge, 5)).to.equal(-10)
			expect(NumberField.snap(0.35, -math.huge, math.huge, 0.1)).to.equal(0.4)
			expect(NumberField.snap(140, 0, 100, 1)).to.equal(100)
		end)

		it("leaves the value alone with no step", function()
			expect(NumberField.snap(1.234, 0, 10, 0)).to.equal(1.234)
		end)
	end)

	it("shows the value in the field between a minus and a plus", function()
		local count = Reactive.ref(3)
		local field = NumberField.new({ app = app, Parent = gui, value = count })
		expect(field.field.Instance.Text).to.equal("3")
		local Icon = require(script.Parent.Icon)
		local minusIcon = field.minus:FindFirstChild("MinusIcon") :: ImageLabel
		local plusIcon = field.plus:FindFirstChild("PlusIcon") :: ImageLabel
		expect(minusIcon.Image).to.equal((Icon.resolve("lucy:minus") :: any).image)
		expect(plusIcon.Image).to.equal((Icon.resolve("lucy:plus") :: any).image)
		expect(minusIcon.ImageRectOffset).never.to.equal(plusIcon.ImageRectOffset)
		expect(field.minus.LayoutOrder < field.field.Instance.LayoutOrder).to.equal(true)
		expect(field.field.Instance.LayoutOrder < field.plus.LayoutOrder).to.equal(true)
		count(12)
		expect(field.field.Instance.Text).to.equal("12")
	end)

	it("shows the value through format", function()
		local field = NumberField.new({
			app = app,
			Parent = gui,
			value = 0.5,
			step = 0.25,
			format = function(value)
				return string.format("%.2f", value)
			end,
		})
		expect(field.field.Instance.Text).to.equal("0.50")
	end)

	it("steps with the buttons, commits once per press, and stops at the ends", function()
		local commits, sounds = {}, {}
		local scope = Reactive.effectScope(true)
		local field = scope:run(function()
			Composables.useUiSound(app, {
				select = function(_, value)
					table.insert(sounds, value)
				end,
			})
			return NumberField.new({
				app = app,
				Parent = gui,
				value = 8,
				max = 10,
				step = 2,
				onValueCommit = function(value)
					table.insert(commits, value)
				end,
			})
		end)
		field:_press(1)
		field:_release()
		expect(field:get("value")).to.equal(10)
		expect(#commits).to.equal(1)
		expect(commits[1]).to.equal(10)
		expect(sounds[1]).to.equal(10)
		expect(field.plus.Interactable).to.equal(false)
		expect(field.plus:HasTag("ui-disabled")).to.equal(true)
		field:_press(1)
		field:_release()
		expect(field:get("value")).to.equal(10)
		expect(#commits).to.equal(1)
		field:_press(-1)
		field:_release()
		expect(field:get("value")).to.equal(8)
		expect(field.plus.Interactable).to.equal(true)
		scope:stop()
	end)

	it("takes typed text when the player leaves the field", function()
		local commits = {}
		local field = NumberField.new({
			app = app,
			Parent = gui,
			value = 5,
			min = 0,
			max = 100,
			onValueCommit = function(value)
				table.insert(commits, value)
			end,
		})
		local box = field.field.Instance
		box.Text = "42"
		task.wait()
		expect(field:get("value")).to.equal(5)
		field:_commitText()
		expect(field:get("value")).to.equal(42)
		expect(commits[1]).to.equal(42)
		box.Text = "500"
		task.wait()
		field:_commitText()
		expect(field:get("value")).to.equal(100)
		expect(box.Text).to.equal("100")
	end)

	it("puts the value back when the typed text is not a number", function()
		local field = NumberField.new({ app = app, Parent = gui, value = 7 })
		local box = field.field.Instance
		box.Text = "-"
		task.wait()
		field:_commitText()
		expect(field:get("value")).to.equal(7)
		expect(box.Text).to.equal("7")
		box.Text = ""
		task.wait()
		field:_commitText()
		expect(box.Text).to.equal("7")
	end)

	it("only lets numbers be typed", function()
		local field = NumberField.new({ app = app, Parent = gui, value = 0 })
		local box = field.field.Instance
		box.Text = "1a2"
		task.wait()
		task.wait()
		expect(box.Text).to.equal("12")
	end)

	it("steps with left and right through the focus, like a slider", function()
		local commits = {}
		local field = NumberField.new({
			app = app,
			Parent = gui,
			value = 1,
			onValueCommit = function(value)
				table.insert(commits, value)
			end,
		})
		app.input:focus(field.field.Instance)
		expect(app.input:nudge(1, 0)).to.equal(true)
		expect(app.input:nudge(1, 0)).to.equal(true)
		expect(field:get("value")).to.equal(3)
		expect(app.input:nudge(0, 1)).to.equal(false)
		app.input:release()
		expect(#commits).to.equal(1)
		expect(commits[1]).to.equal(3)
	end)

	it("is one stop for the gamepad: the field, not the buttons", function()
		local field = NumberField.new({ app = app, Parent = gui })
		expect(field.field.Instance.Selectable).to.equal(true)
		expect(field.minus.Selectable).to.equal(false)
		expect(field.plus.Selectable).to.equal(false)
		expect(field.Instance.Selectable).to.equal(false)
	end)

	it("ignores everything while disabled", function()
		local field = NumberField.new({ app = app, Parent = gui, value = 4, disabled = true })
		field:_press(1)
		field:_release()
		expect(field:nudge(1, 0, 1)).to.equal(false)
		expect(field:get("value")).to.equal(4)
		expect(field.minus.Interactable).to.equal(false)
		expect(field.field.Instance.TextEditable).to.equal(false)
	end)

	it("speeds up while a button is held", function()
		local field = NumberField.new({ app = app, Parent = gui, value = 0, min = 0, max = 1000 })
		field:nudge(1, 0, 1)
		expect(field:get("value")).to.equal(1)
		field:nudge(1, 0, 30)
		expect(field:get("value") > 2).to.equal(true)
	end)
end
