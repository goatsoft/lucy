return function()
	local Button = require(script.Parent.Button)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("follows reactive text and disabled", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local count = Reactive.ref(0)
		local busy = Reactive.ref(false)
		local button = Button.new({
			app = app,
			Parent = gui,
			text = function()
				return `Buy ({count()})`
			end,
			disabled = busy,
		})
		expect(button.Instance.Text).to.equal("Buy (0)")
		count(3)
		busy(true)
		expect(button.Instance.Text).to.equal("Buy (3)")
		expect(button.Instance.Interactable).to.equal(false)
		expect(button.Instance:HasTag("ui-disabled")).to.equal(true)
		busy(false)
		expect(button.Instance:HasTag("ui-disabled")).to.equal(false)
	end)

	it("follows a reactive variant", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local danger = Reactive.ref(false)
		local button = Button.new({
			app = app,
			Parent = gui,
			variant = function()
				return if danger() then "destructive" else "default"
			end,
		})
		danger(true)
		expect(button.Instance:HasTag("ui-button-variant-destructive")).to.equal(true)
		expect(button.Instance:HasTag("ui-button-variant-default")).to.equal(false)
	end)

	it("renders a TextButton with base and variant tags", function()
		local button = Button.new({ app = app, Parent = gui, text = "Play" })
		local instance = button.Instance
		expect(instance:IsA("TextButton")).to.equal(true)
		expect(instance.Text).to.equal("Play")
		expect(instance:HasTag("ui-button")).to.equal(true)
		expect(instance:HasTag("ui-button-variant-default")).to.equal(true)
		expect(instance:HasTag("ui-button-size-md")).to.equal(true)
		expect(instance.AutoButtonColor).to.equal(false)
	end)

	it("keeps its props in app state", function()
		local button =
			Button.new({ app = app, id = "play", Parent = gui, text = "Play", variant = "secondary" })
		expect(app.state:get("ui.play.variant")).to.equal("secondary")
		app.state:set("ui.play.text", "Resume")
		expect(button.Instance.Text).to.equal("Resume")
	end)

	it("swaps variant tags when the variant changes", function()
		local button = Button.new({ app = app, Parent = gui })
		button:set({ variant = "destructive", size = "lg" })
		expect(button.Instance:HasTag("ui-button-variant-default")).to.equal(false)
		expect(button.Instance:HasTag("ui-button-variant-destructive")).to.equal(true)
		expect(button.Instance:HasTag("ui-button-size-lg")).to.equal(true)
	end)

	it("rejects unknown variants", function()
		expect(function()
			Button.new({ app = app, variant = "sparkly" })
		end).to.throw()
	end)

	it("calls onClick and fires Activated", function()
		local clicks, fired = 0, 0
		local button = Button.new({
			app = app,
			Parent = gui,
			onClick = function()
				clicks += 1
			end,
		})
		button.Activated:Connect(function()
			fired += 1
		end)
		button:click()
		expect(clicks).to.equal(1)
		expect(fired).to.equal(1)
	end)

	it("ignores clicks while disabled and is not interactable", function()
		local clicks = 0
		local button = Button.new({
			app = app,
			Parent = gui,
			disabled = true,
			onClick = function()
				clicks += 1
			end,
		})
		button:click()
		expect(clicks).to.equal(0)
		expect(button.Instance.Interactable).to.equal(false)
		expect(button.Instance:HasTag("ui-disabled")).to.equal(true)
		button:set({ disabled = false })
		button:click()
		expect(clicks).to.equal(1)
	end)

	it("hides when visible is false", function()
		local button = Button.new({ app = app, Parent = gui, visible = false })
		expect(button.Instance.Visible).to.equal(false)
	end)

	it("sizes to content except for icon buttons", function()
		local button = Button.new({ app = app, Parent = gui })
		expect(button.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.X)
		button:set({ size = "icon" })
		expect(button.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.None)
	end)

	describe("styling", function()
		it("uses the variant colours from the theme", function()
			local primary = Button.new({ app = app, Parent = gui })
			local secondary = Button.new({ app = app, Parent = gui, variant = "secondary" })
			Harness.flush()
			expect(
				Harness.colorEq(
					Harness.styled(primary.Instance, "BackgroundColor3"),
					app.theme:resolve("Primary")
				)
			).to.equal(true)
			expect(
				Harness.colorEq(
					Harness.styled(secondary.Instance, "BackgroundColor3"),
					app.theme:resolve("Secondary")
				)
			).to.equal(true)
			expect(
				Harness.colorEq(
					Harness.styled(secondary.Instance, "TextColor3"),
					app.theme:resolve("SecondaryForeground")
				)
			).to.equal(true)
		end)

		it("restyles when the theme switches", function()
			local button = Button.new({ app = app, Parent = gui })
			app:setTheme("dark")
			Harness.flush()
			expect(
				Harness.colorEq(
					Harness.styled(button.Instance, "BackgroundColor3"),
					app.theme:resolve("Primary")
				)
			).to.equal(true)
		end)

		it("takes its height from the size token", function()
			local button = Button.new({ app = app, Parent = gui, size = "lg" })
			Harness.flush()
			local size = Harness.styled(button.Instance, "Size")
			expect(size.Y.Offset).to.equal(app.theme:resolve("ControlLg").Y.Offset)
		end)
	end)
end
