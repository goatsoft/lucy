return function()
	local Tokens = require(script.Parent.Tokens)
	local Oklab = require(script.Parent.Oklab)

	local function keys(t)
		local out = {}
		for key in t do
			table.insert(out, key)
		end
		table.sort(out)
		return table.concat(out, ",")
	end

	describe("palette", function()
		it("exposes every Tailwind colour as a primitive", function()
			expect(Tokens.primitives.Zinc950:ToHex()).to.equal("09090b")
			expect(Tokens.primitives.Red500:ToHex()).to.equal("fb2c36")
			expect(Tokens.primitives.Blue500:ToHex()).to.equal("2b7fff")
			expect(Tokens.primitives.Taupe500).to.be.ok()
		end)

		it("only uses attribute-safe value types", function()
			local allowed = { number = true, Color3 = true, UDim = true, UDim2 = true, Font = true }
			for _, value in Tokens.primitives do
				expect(allowed[typeof(value)]).to.equal(true)
			end
			for _, set in Tokens.densities do
				for _, value in set do
					expect(allowed[typeof(value)]).to.equal(true)
				end
			end
		end)
	end)

	describe("themes", function()
		it("gives every theme of every base the same keys", function()
			local reference = keys(Tokens.themes.light)
			for _, base in Tokens.bases do
				for _, values in Tokens.themesFor(base) do
					expect(keys(values)).to.equal(reference)
				end
			end
		end)

		it("resolves every theme without dangling aliases", function()
			for _, base in Tokens.bases do
				for _, values in Tokens.themesFor(base, { primary = "blue" }) do
					expect(function()
						Tokens.resolveTheme(values, Tokens.primitives)
					end).never.to.throw()
				end
			end
		end)

		it("tints primary with another hue", function()
			local themes = Tokens.themesFor("slate", { primary = "violet" })
			expect(themes.light.Primary).to.equal("$Violet600")
			expect(themes.dark.Primary).to.equal("$Violet500")
		end)

		it("rejects unknown bases and hues", function()
			expect(function()
				Tokens.themesFor("plaid")
			end).to.throw()
			expect(function()
				Tokens.themesFor("zinc", { primary = "plaid" })
			end).to.throw()
		end)
	end)

	describe("derived tokens", function()
		it("composites over like CSS alpha (shadcn dark border is white/10%)", function()
			local resolved = Tokens.resolveTheme(Tokens.themes.dark, Tokens.primitives)
			expect(resolved.Border:ToHex()).to.equal("222224")
		end)

		it("mixes in Oklab", function()
			local mixed = Tokens.resolveTheme({ M = Tokens.mix("$Black", "$White", 0.5) }, Tokens.primitives).M
			local L = Oklab.toOklch(mixed)
			expect(math.abs(L - 0.5) < 0.01).to.equal(true)
		end)

		it("reports unknown aliases and loops", function()
			expect(function()
				Tokens.resolveTheme({ A = "$Nope" }, Tokens.primitives)
			end).to.throw()
			expect(function()
				Tokens.resolveTheme({ A = Tokens.mix("$A", "$White", 0.5) }, Tokens.primitives)
			end).to.throw()
		end)
	end)

	describe("densities", function()
		it("share one key set", function()
			local reference = keys(Tokens.densities.default)
			for _, set in Tokens.densities do
				expect(keys(set)).to.equal(reference)
			end
		end)

		it("gives touch at least 44px main controls", function()
			expect(Tokens.densities.touch.ControlMd.Y.Offset >= 44).to.equal(true)
			expect(Tokens.densities.touch.ControlIcon.X.Offset >= 44).to.equal(true)
		end)
	end)
end
