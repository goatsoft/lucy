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

	describe("reveal", function()
		local Animate = require(script.Parent.Parent.Core.Animate)
		local Reactive = require(script.Parent.Parent.Core.Reactive)

		beforeEach(function()
			Animate.manual = true
		end)
		afterEach(function()
			Animate.manual = false
		end)

		local function run(seconds: number)
			for _ = 1, math.round(seconds * 60) do
				Animate.step(1 / 60)
			end
		end

		it("shows all of the text without reveal", function()
			local text = Text.new({ app = app, Parent = gui, text = "Hello" })
			expect(text.Instance.MaxVisibleGraphemes).to.equal(-1)
			expect(text:get("revealing")).to.equal(false)
		end)

		it("types the text out at reveal characters a second", function()
			local text = Text.new({ app = app, Parent = gui, text = "Hello there", reveal = 10 })
			expect(text.Instance.Text).to.equal("Hello there") -- laid out whole from the start
			expect(text.Instance.MaxVisibleGraphemes).to.equal(0)
			expect(text:get("revealing")).to.equal(true)
			run(0.5)
			expect(text.Instance.MaxVisibleGraphemes).to.equal(5)
			run(0.7)
			expect(text.Instance.MaxVisibleGraphemes).to.equal(-1)
			expect(text:get("revealing")).to.equal(false)
		end)

		it("fires Revealed once the text is all out", function()
			local text = Text.new({ app = app, Parent = gui, text = "Hi", reveal = 10 })
			local fired = 0
			text.Revealed:Connect(function()
				fired += 1
			end)
			run(0.1)
			expect(fired).to.equal(0)
			run(0.5)
			expect(fired).to.equal(1)
		end)

		it("starts again when the text changes", function()
			local line = Reactive.ref("First line")
			local text = Text.new({ app = app, Parent = gui, text = line, reveal = 10 })
			run(2)
			expect(text.Instance.MaxVisibleGraphemes).to.equal(-1)
			line("Second line")
			expect(text.Instance.MaxVisibleGraphemes).to.equal(0)
			run(0.3)
			expect(text.Instance.MaxVisibleGraphemes).to.equal(3)
		end)

		it("shows the rest at once on skipReveal", function()
			local text = Text.new({ app = app, Parent = gui, text = "A long line to read", reveal = 10 })
			local fired = 0
			text.Revealed:Connect(function()
				fired += 1
			end)
			run(0.2)
			text:skipReveal()
			expect(text.Instance.MaxVisibleGraphemes).to.equal(-1)
			expect(text:get("revealing")).to.equal(false)
			expect(fired).to.equal(1)
			run(3)
			expect(fired).to.equal(1)
		end)

		it("counts characters, not rich text tags", function()
			local text =
				Text.new({ app = app, Parent = gui, text = "<b>Hey</b> you", richText = true, reveal = 10 })
			run(0.6)
			expect(text.Instance.MaxVisibleGraphemes).to.equal(6)
			run(0.2)
			expect(text.Instance.MaxVisibleGraphemes).to.equal(-1)
		end)

		it("takes reveal = true as the default speed", function()
			local text = Text.new({ app = app, Parent = gui, text = string.rep("a", 100), reveal = true })
			run(1)
			expect(text.Instance.MaxVisibleGraphemes).to.equal(Text.REVEAL_RATE)
		end)
	end)
end
