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
end
