return function()
	local Responsive = require(script.Parent.Responsive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local phone = { device = "mobile", mode = "touch", breakpoint = "Compact", orientation = "portrait" }
	local pc = { device = "desktop", mode = "mouse", breakpoint = "Wide", orientation = "landscape" }

	describe("pick", function()
		it("passes plain values through", function()
			expect(Responsive.pick(phone, "x")).to.equal("x")
			expect(Responsive.pick(phone, 4)).to.equal(4)
			local list = { "a", "b" }
			expect(Responsive.pick(phone, list)).to.equal(list)
		end)

		it("prefers device, then mode, then breakpoint, then orientation", function()
			local value = { mobile = 1, touch = 2, compact = 3, portrait = 4, default = 5 }
			expect(Responsive.pick(phone, value)).to.equal(1)
			value.mobile = nil
			expect(Responsive.pick(phone, value)).to.equal(2)
			value.touch = nil
			expect(Responsive.pick(phone, value)).to.equal(3)
			value.compact = nil
			expect(Responsive.pick(phone, value)).to.equal(4)
			expect(Responsive.pick(pc, value)).to.equal(5)
		end)

		it("does not treat ordinary tables as responsive", function()
			expect(Responsive.isResponsive({ text = "hi" })).to.equal(false)
			expect(Responsive.isResponsive({ mobile = 1 })).to.equal(true)
		end)
	end)

	describe("with an app", function()
		local app, cleanup
		beforeEach(function()
			app, cleanup = Harness.app()
		end)
		afterEach(function()
			cleanup()
		end)

		it("watches input changes and reports only real changes", function()
			local seen = {}
			local stop = Responsive.watch(app, { mobile = "vertical", default = "horizontal" }, function(v)
				table.insert(seen, v)
			end)
			expect(seen[1]).to.equal("horizontal")
			app.input:setMode("keyboard")
			expect(#seen).to.equal(1)
			app.input:setCaps({ touch = true, viewport = Vector2.new(390, 844) })
			expect(seen[2]).to.equal("vertical")
			stop()
		end)

		it("answers is() for any key", function()
			expect(Responsive.is(app, "desktop")).to.equal(true)
			expect(Responsive.is(app, "console")).to.equal(false)
		end)
	end)
end
