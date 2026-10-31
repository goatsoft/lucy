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

	it("makes a close button that draws the lucy:close icon", function()
		local clicked = 0
		local close = Button.close({
			app = app,
			onClick = function()
				clicked += 1
			end,
		})
		close.Instance.Parent = gui
		expect(close.Instance.Name).to.equal("Close")
		expect(close.Instance:HasTag("ui-button-close")).to.equal(true)
		close:click()
		expect(clicked).to.equal(1)
		expect(close.Instance.Text).to.equal("")
		local slot: any = require(script.Parent.Icon).resolve("lucy:close")
		expect(close.icon.Instance.Image).to.equal(slot.image)
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

	describe("hint", function()
		it("shows a key cap after the text", function()
			app.input:setMode("keyboard")
			local button = Button.new({
				app = app,
				Parent = gui,
				text = "Join",
				hint = { keyboard = Enum.KeyCode.E, gamepad = Enum.KeyCode.DPadUp },
			})
			local root = button.Instance
			expect(root.Text).to.equal("")
			expect(button.label.Parent).to.equal(root)
			expect(button.label.Text).to.equal("Join")
			expect(button.hint.Instance.Parent).to.equal(root)
			expect(button.label.LayoutOrder < button.hint.Instance.LayoutOrder).to.equal(true)
			expect(button.hint.text.Text).to.equal("E")
			button:set("text", "Leave")
			expect(button.label.Text).to.equal("Leave")
			app.input:setMode("touch")
			expect(button.hint.Instance.Visible).to.equal(false)
			button:destroy()
			expect(button.hint.destroyed).to.equal(true)
		end)

		it("draws an icon before its text", function()
			local button = Button.new({ app = app, Parent = gui, text = "Settings", icon = "lucy:check" })
			local root = button.Instance
			expect(root.Text).to.equal("")
			expect(button.label.Text).to.equal("Settings")
			expect(button.icon.Instance.Parent).to.equal(root)
			expect(button.icon.Instance.LayoutOrder < button.label.LayoutOrder).to.equal(true)
			expect(button.icon:get("icon")).to.equal("lucy:check")
			button:set("icon", "lucy:close")
			expect(button.icon:get("icon")).to.equal("lucy:close")
			button:destroy()
			expect(button.icon.destroyed).to.equal(true)
		end)

		it("shows only the icon with no text", function()
			local button = Button.new({ app = app, Parent = gui, size = "icon", icon = "lucy:check" })
			expect(button:get("text")).to.equal("")
			expect(button.label.Visible).to.equal(false)
			expect(button.icon.Instance.Visible).to.equal(true)
		end)

		it("colours its icon like the button's text", function()
			local button =
				Button.new({ app = app, Parent = gui, icon = "lucy:check", variant = "destructive" })
			Harness.flush()
			expect(
				Harness.colorEq(
					Harness.styled(button.icon.Instance, "ImageColor3"),
					app.theme:resolve("DestructiveForeground")
				)
			).to.equal(true)
		end)

		it("keeps its text on the button without one", function()
			local button = Button.new({ app = app, Parent = gui, text = "Play" })
			expect(button.Instance.Text).to.equal("Play")
			expect(button.label).to.equal(nil)
			expect(button.hint).to.equal(nil)
		end)

		it("colours the label like the button's own text", function()
			local button = Button.new({
				app = app,
				Parent = gui,
				variant = "destructive",
				hint = { keyboard = Enum.KeyCode.E },
			})
			Harness.flush()
			expect(
				Harness.colorEq(
					Harness.styled(button.label, "TextColor3"),
					app.theme:resolve("DestructiveForeground")
				)
			).to.equal(true)
			expect(Harness.styled(button.label, "TextSize")).to.equal(app.theme:resolve("TextSm"))
		end)

		it("colours a mono controller picture like the button's text", function()
			app.input:setMode("gamepad")
			local button = Button.new({
				app = app,
				Parent = gui,
				hint = { gamepad = Enum.KeyCode.ButtonA, variant = "mono" },
			})
			Harness.flush()
			expect(button.hint.glyph.Visible).to.equal(true)
			expect(
				Harness.colorEq(
					Harness.styled(button.hint.glyph, "ImageColor3"),
					app.theme:resolve("PrimaryForeground")
				)
			).to.equal(true)
		end)

		it("fades the label when disabled", function()
			local button =
				Button.new({ app = app, Parent = gui, disabled = true, hint = { keyboard = Enum.KeyCode.E } })
			Harness.flush()
			expect(Harness.styled(button.label, "TextTransparency")).to.equal(0.5)
		end)
	end)
end
