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

	describe("reserve", function()
		it("holds the widest the text's digits can be", function()
			-- a font where 1 is thin and 8 is wide
			local function width(text: string): number
				local total = 0
				for _, char in string.split(text, "") do
					total += if char == "1" then 4 elseif char == "8" then 12 elseif char == ":" then 3 else 10
				end
				return total
			end
			expect(Text.widestDigits("1:11", width)).to.equal(39)
			expect(Text.widestDigits("GO", width)).to.equal(20)
		end)

		it("keeps its width as the text changes", function()
			if not Harness.laysOutLive() then
				return
			end
			local text = Text.new({ app = app, text = "1", reserve = "00", variant = "h1" })
			text.Instance.Parent = gui
			task.wait(0.3)
			local held = text.Instance.AbsoluteSize.X
			expect(held > 0).to.equal(true)
			text:set("text", "88")
			task.wait(0.1)
			expect(text.Instance.AbsoluteSize.X).to.equal(held)
		end)
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

	describe("count", function()
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

		it("shows a value with thousands separators", function()
			local text = Text.new({ app = app, Parent = gui, value = 4200 })
			expect(text.Instance.Text).to.equal("4,200")
			expect(text:get("counting")).to.equal(false)
		end)

		it("counts up from zero over count seconds", function()
			local text = Text.new({ app = app, Parent = gui, value = 1000, count = 1 })
			expect(text.Instance.Text).to.equal("0")
			expect(text:get("counting")).to.equal(true)
			run(0.5)
			local mid = tonumber((text.Instance.Text:gsub(",", "")))
			expect(mid > 0 and mid < 1000).to.equal(true)
			run(0.6)
			expect(text.Instance.Text).to.equal("1,000")
			expect(text:get("counting")).to.equal(false)
		end)

		it("fires Counted once it lands", function()
			local text = Text.new({ app = app, Parent = gui, value = 50, count = 0.5 })
			local fired = 0
			text.Counted:Connect(function()
				fired += 1
			end)
			run(1)
			expect(fired).to.equal(1)
		end)

		it("counts on from where it is when the value changes", function()
			local value = Reactive.ref(100)
			local text = Text.new({ app = app, Parent = gui, value = value, count = 1 })
			run(1.2)
			expect(text.Instance.Text).to.equal("100")
			value(300)
			expect(text.Instance.Text).to.equal("100")
			run(0.5)
			local mid = tonumber(text.Instance.Text)
			expect(mid > 100 and mid < 300).to.equal(true)
			run(0.6)
			expect(text.Instance.Text).to.equal("300")
		end)

		it("counts from `from`, through the game's format", function()
			local text = Text.new({
				app = app,
				Parent = gui,
				value = 250,
				from = 200,
				count = 1,
				format = function(n: number): string
					return `+{n} XP`
				end,
			})
			expect(text.Instance.Text).to.equal("+200 XP")
			run(1.2)
			expect(text.Instance.Text).to.equal("+250 XP")
		end)

		it("lands at once on skipCount", function()
			local text = Text.new({ app = app, Parent = gui, value = 900, count = 2 })
			local fired = 0
			text.Counted:Connect(function()
				fired += 1
			end)
			run(0.3)
			text:skipCount()
			expect(text.Instance.Text).to.equal("900")
			expect(text:get("counting")).to.equal(false)
			expect(fired).to.equal(1)
		end)

		it("takes count = true as the default time", function()
			local text = Text.new({ app = app, Parent = gui, value = 10, count = true })
			run(Text.COUNT_SECONDS + 0.1)
			expect(text.Instance.Text).to.equal("10")
		end)
	end)
end
