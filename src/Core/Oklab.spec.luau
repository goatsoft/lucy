return function()
	local Oklab = require(script.Parent.Oklab)

	local function hex(color: Color3)
		return color:ToHex()
	end

	describe("fromOklch", function()
		it("matches the reference sRGB values", function()
			expect(hex(Oklab.palette("red", 500))).to.equal("fb2c36")
			expect(hex(Oklab.palette("blue", 500))).to.equal("2b7fff")
			expect(hex(Oklab.palette("amber", 500))).to.equal("fe9a00")
			expect(hex(Oklab.palette("zinc", 900))).to.equal("18181b")
			expect(hex(Oklab.palette("zinc", 50))).to.equal("fafafa")
		end)

		it("clamps extreme lightness to black and white", function()
			expect(hex(Oklab.fromOklch(1, 0, 0))).to.equal("ffffff")
			expect(hex(Oklab.fromOklch(0, 0, 0))).to.equal("000000")
		end)

		it("can gamut map by reducing chroma instead of clipping", function()
			local previous = Oklab.gamut
			Oklab.gamut = "chroma"
			local mapped = Oklab.palette("blue", 500)
			Oklab.gamut = previous
			local _, _, H = Oklab.toOklch(mapped)
			expect(math.abs(H - 259.8) < 2).to.equal(true)
		end)
	end)

	describe("round trips", function()
		it("returns the same sRGB colour", function()
			local color = Color3.fromRGB(51, 128, 204)
			local L, a, b = Oklab.toOklab(color)
			expect(Oklab.distance(Oklab.fromOklab(L, a, b), color) < 1e-4).to.equal(true)
		end)

		it("reports chroma 0 for greys", function()
			local _, C = Oklab.toOklch(Color3.fromRGB(128, 128, 128))
			expect(C < 1e-3).to.equal(true)
		end)
	end)

	describe("mix and adjust", function()
		it("mixes perceptually", function()
			local mid = Oklab.mix(Color3.new(0, 0, 0), Color3.new(1, 1, 1), 0.5)
			local L = Oklab.toOklch(mid)
			expect(math.abs(L - 0.5) < 0.01).to.equal(true)
		end)

		it("returns the ends at t = 0 and 1", function()
			local a, b = Oklab.palette("rose", 500), Oklab.palette("sky", 300)
			expect(Oklab.distance(Oklab.mix(a, b, 0), a) < 1e-3).to.equal(true)
			expect(Oklab.distance(Oklab.mix(a, b, 1), b) < 1e-3).to.equal(true)
		end)

		it("shifts lightness", function()
			local base = Oklab.palette("zinc", 500)
			local L0 = Oklab.toOklch(base)
			local L1 = Oklab.toOklch(Oklab.adjust(base, { l = 0.1 }))
			expect(math.abs(L1 - L0 - 0.1) < 0.01).to.equal(true)
		end)

		it("errors on unknown palette colours", function()
			expect(function()
				Oklab.palette("plaid", 500)
			end).to.throw()
		end)
	end)
	describe("contrast", function()
		local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

		it("gives WCAG relative luminance and contrast ratios", function()
			expect(Oklab.luminance(white)).to.be.near(1, 1e-6)
			expect(Oklab.luminance(black)).to.be.near(0, 1e-6)
			expect(Oklab.contrast(white, black)).to.be.near(21, 1e-6)
			expect(Oklab.contrast(black, white)).to.be.near(21, 1e-6)
			expect(Oklab.contrast(white, white)).to.be.near(1, 1e-6)
			-- #767676 on white is the classic 4.54:1
			expect(Oklab.contrast(Color3.fromRGB(118, 118, 118), white)).to.be.near(4.54, 0.01)
		end)

		it("picks the more readable of two text colours", function()
			local navy = Color3.fromRGB(20, 30, 80)
			local light, dark = Color3.fromRGB(250, 250, 250), Color3.fromRGB(10, 10, 10)
			expect(Oklab.readable(navy, light, dark)).to.equal(light)
			expect(Oklab.readable(Color3.fromRGB(250, 220, 90), light, dark)).to.equal(dark)
		end)

		it("moves the better one in lightness until it reads, when neither does", function()
			local grey = Color3.fromRGB(128, 128, 128)
			local light, dark = Color3.fromRGB(180, 180, 180), Color3.fromRGB(90, 90, 90)
			local text = Oklab.readable(grey, light, dark)
			expect(Oklab.contrast(text, grey) >= 4.5).to.equal(true)
		end)

		it("takes another target ratio", function()
			local grey = Color3.fromRGB(128, 128, 128)
			local text = Oklab.readable(grey, Color3.fromRGB(150, 150, 150), Color3.fromRGB(110, 110, 110), 3)
			expect(Oklab.contrast(text, grey) >= 3).to.equal(true)
		end)
	end)
end
