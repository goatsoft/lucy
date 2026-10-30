return function()
	local Text = require(script.Parent.Text)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("follows reactive text, variant and align", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local name = Reactive.ref("JB")
		local heading = Reactive.ref(false)
		local text = Text.new({
			app = app,
			Parent = gui,
			text = function()
				return `Hi {name()}`
			end,
			variant = function()
				return if heading() then "h1" else "p"
			end,
			align = Reactive.ref("right"),
		})
		expect(text.Instance.Text).to.equal("Hi JB")
		expect(text.Instance.TextXAlignment).to.equal(Enum.TextXAlignment.Right)
		name("Lucy")
		heading(true)
		expect(text.Instance.Text).to.equal("Hi Lucy")
		expect(text.Instance:HasTag("ui-text-variant-h1")).to.equal(true)
	end)

	it("fills width and wraps by default", function()
		local text = Text.new({ app = app, Parent = gui, text = "Hello" })
		expect(text.Instance.Size).to.equal(UDim2.fromScale(1, 0))
		expect(text.Instance.TextWrapped).to.equal(true)
		expect(text.Instance.TextXAlignment).to.equal(Enum.TextXAlignment.Left)
	end)

	it("sizes to content with autoWidth", function()
		local text = Text.new({ app = app, Parent = gui, autoWidth = true })
		expect(text.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
	end)

	it("applies alignment and variant from state", function()
		local text = Text.new({ app = app, id = "title", Parent = gui, variant = "h1", align = "center" })
		expect(text.Instance.TextXAlignment).to.equal(Enum.TextXAlignment.Center)
		expect(text.Instance:HasTag("ui-text-variant-h1")).to.equal(true)
		app.state:set("ui.title.variant", "muted")
		expect(text.Instance:HasTag("ui-text-variant-muted")).to.equal(true)
	end)

	it("uses the heading size token", function()
		local text = Text.new({ app = app, Parent = gui, variant = "h1" })
		Harness.flush()
		expect(Harness.styled(text.Instance, "TextSize")).to.equal(app.theme:resolve("Text4xl"))
	end)

	it("uses the muted colour for muted text", function()
		local text = Text.new({ app = app, Parent = gui, variant = "muted" })
		Harness.flush()
		expect(
			Harness.colorEq(Harness.styled(text.Instance, "TextColor3"), app.theme:resolve("MutedForeground"))
		).to.equal(true)
	end)
end
