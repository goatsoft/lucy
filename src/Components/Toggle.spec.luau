return function()
	local Toggle = require(script.Parent.Toggle)
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

	it("is a tagged button with its text, off by default", function()
		local toggle = Toggle.new({ app = app, Parent = gui, text = "Bold" })
		expect(toggle.Instance:IsA("TextButton")).to.equal(true)
		expect(toggle.Instance.Text).to.equal("Bold")
		expect(toggle.Instance:HasTag("ui-toggle")).to.equal(true)
		expect(toggle.Instance:HasTag("ui-selected")).to.equal(false)
		expect(toggle:get("pressed")).to.equal(false)
	end)

	it("flips pressed when clicked and reports it", function()
		local seen = {}
		local toggle = Toggle.new({
			app = app,
			Parent = gui,
			onPressedChange = function(pressed)
				table.insert(seen, tostring(pressed))
			end,
		})
		toggle:toggle()
		expect(toggle:get("pressed")).to.equal(true)
		expect(toggle.Instance:HasTag("ui-selected")).to.equal(true)
		toggle:set("pressed", false)
		expect(table.concat(seen, ",")).to.equal("true,false")
	end)

	it("keeps pressed in step with a ref, both ways", function()
		local on = Reactive.ref(true)
		local toggle = Toggle.new({ app = app, Parent = gui, pressed = on })
		expect(toggle.Instance:HasTag("ui-selected")).to.equal(true)
		toggle:toggle()
		expect(on()).to.equal(false)
		on(true)
		expect(toggle:get("pressed")).to.equal(true)
	end)

	it("ignores the player while disabled", function()
		local toggle = Toggle.new({ app = app, Parent = gui, disabled = true })
		toggle:toggle()
		expect(toggle:get("pressed")).to.equal(false)
		expect(toggle.Instance.Interactable).to.equal(false)
		expect(toggle.Instance:HasTag("ui-disabled")).to.equal(true)
	end)

	it("tags its variant and size, and rejects unknown ones", function()
		local toggle = Toggle.new({ app = app, Parent = gui, variant = "outline", size = "sm" })
		expect(toggle.Instance:HasTag("ui-toggle-variant-outline")).to.equal(true)
		expect(toggle.Instance:HasTag("ui-toggle-size-sm")).to.equal(true)
		expect(function()
			Toggle.new({ app = app, Parent = gui, variant = "shiny" })
		end).to.throw()
	end)

	it("is as tall as a Button of the same size, sm to xl, with the same text size", function()
		local Button = require(script.Parent.Button)
		for _, size in { "sm", "md", "lg", "xl" } do
			local toggle = Toggle.new({ app = app, Parent = gui, text = "On", size = size })
			local button = Button.new({ app = app, Parent = gui, text = "Go", size = size })
			Harness.flush()
			expect(Harness.styled(toggle.Instance, "Size").Y.Offset).to.equal(
				Harness.styled(button.Instance, "Size").Y.Offset
			)
			expect(Harness.styled(toggle.Instance, "TextSize")).to.equal(
				Harness.styled(button.Instance, "TextSize")
			)
		end
	end)

	it("emits toggle from the player path only", function()
		local calls = {}
		local scope = Reactive.effectScope(true)
		local toggle = scope:run(function()
			Composables.useUiSound(app, {
				toggle = function(_, value)
					table.insert(calls, tostring(value))
				end,
			})
			return Toggle.new({ app = app, Parent = gui })
		end)
		toggle:toggle()
		toggle:set("pressed", false)
		toggle:toggle()
		expect(table.concat(calls, ",")).to.equal("true,true")
		scope:stop()
	end)

	it("uses the accent colour when pressed", function()
		local toggle = Toggle.new({ app = app, Parent = gui, pressed = true })
		Harness.flush()
		expect(
			Harness.colorEq(Harness.styled(toggle.Instance, "BackgroundColor3"), app.theme:resolve("Accent"))
		).to.equal(true)
	end)

	describe("slot", function()
		it("puts the text then the children in a row, the indicator outside it", function()
			local Icon = require(script.Parent.Icon)
			local mark = Icon.new({ app = app, icon = "lucy:close" })
			local toggle =
				Toggle.new({ app = app, Parent = gui, text = "Mute", variant = "line", children = { mark } })
			expect(toggle.Instance.Text).to.equal("")
			expect(toggle.label.Text).to.equal("Mute")
			expect(toggle.label.Parent).to.equal(toggle.slot)
			expect(mark.Instance.Parent).to.equal(toggle.slot)
			expect(toggle.label.LayoutOrder < mark.Instance.LayoutOrder).to.equal(true)
			expect(toggle.Instance:FindFirstChild("Indicator")).to.be.ok()
			expect(toggle.slot:FindFirstChild("Indicator")).never.to.be.ok()
		end)

		it("hides the label with no text", function()
			local toggle = Toggle.new({ app = app, Parent = gui, children = { "B" } })
			expect(toggle.label.Visible).to.equal(false)
		end)

		it("gives what is in it the toggle's colours, on and off", function()
			local Icon = require(script.Parent.Icon)
			local mark = Icon.new({ app = app, icon = "lucy:close" })
			local toggle =
				Toggle.new({ app = app, Parent = gui, text = "Mute", variant = "line", children = { mark } })
			Harness.flush()
			local muted = app.theme:resolve("MutedForeground")
			expect(Harness.colorEq(Harness.styled(toggle.label, "TextColor3"), muted)).to.equal(true)
			expect(Harness.colorEq(Harness.styled(mark.Instance, "ImageColor3"), muted)).to.equal(true)
			toggle:set("pressed", true)
			Harness.flush()
			local on = app.theme:resolve("Foreground")
			expect(Harness.colorEq(Harness.styled(toggle.label, "TextColor3"), on)).to.equal(true)
			expect(Harness.colorEq(Harness.styled(mark.Instance, "ImageColor3"), on)).to.equal(true)
		end)
	end)
end
