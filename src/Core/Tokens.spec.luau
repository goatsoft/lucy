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
		it("exposes every palette colour as a primitive", function()
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

		it("keeps text on every fill readable (WCAG AA) for every base, primary and theme", function()
			local Palette = require(script.Parent.Palette)
			local pairs = {
				{ "Primary", "PrimaryForeground" },
				{ "Destructive", "DestructiveForeground" },
				{ "Success", "SuccessForeground" },
				{ "Warning", "WarningForeground" },
				{ "Info", "InfoForeground" },
				{ "DestructiveSubtle", "DestructiveSubtleForeground" },
				{ "SuccessSubtle", "SuccessSubtleForeground" },
				{ "WarningSubtle", "WarningSubtleForeground" },
				{ "InfoSubtle", "InfoSubtleForeground" },
				-- coloured text straight on the page
				{ "Background", "Destructive" },
				{ "Card", "Destructive" },
			}
			local failures = {}
			for _, base in Tokens.bases do
				for hue, shades in Palette do
					if not (shades[50] and shades[300] and shades[600]) then
						continue -- not a hue, such as the white and black shades
					end
					for themeName, values in Tokens.themesFor(base, { primary = hue }) do
						local resolved = Tokens.resolveTheme(values, Tokens.primitives)
						local function colour(value)
							for _ = 1, 16 do
								if typeof(value) == "Color3" then
									return value
								end
								local name = string.sub(value, 2)
								value = if resolved[name] ~= nil
									then resolved[name]
									else Tokens.primitives[name]
							end
							return value
						end
						for _, pair in pairs do
							local ratio = Oklab.contrast(colour(resolved[pair[2]]), colour(resolved[pair[1]]))
							if ratio < 4.5 then
								table.insert(
									failures,
									`{base}/{hue}/{themeName} {pair[2]} {string.format("%.2f", ratio)}`
								)
							end
						end
					end
				end
			end
			expect(table.concat(failures, "; ")).to.equal("")
		end)

		it("tints text on the status fills with their own hue", function()
			local function hueGap(a: number, b: number): number
				local d = math.abs(a - b) % 360
				return math.min(d, 360 - d)
			end
			for themeName, values in Tokens.themesFor("zinc") do
				local resolved = Tokens.resolveTheme(values, Tokens.primitives)
				local function colour(value)
					for _ = 1, 16 do
						if typeof(value) == "Color3" then
							return value
						end
						local name = string.sub(value, 2)
						value = if resolved[name] ~= nil then resolved[name] else Tokens.primitives[name]
					end
					return value
				end
				for _, pair in
					{
						{ "Destructive", "Destructive" },
						{ "Success", "Success" },
						{ "Warning", "Warning" },
						{ "Info", "Info" },
						{ "Destructive", "DestructiveSubtle" },
						{ "Success", "SuccessSubtle" },
						{ "Warning", "WarningSubtle" },
						{ "Info", "InfoSubtle" },
					}
				do
					local name = pair[1]
					local _, fillC, fillH = Oklab.toOklch(colour(resolved[name]))
					local L, C, H = Oklab.toOklch(colour(resolved[pair[2] .. "Foreground"]))
					local _ = fillC
					-- Text on a wash always has room for colour; dark text always carries
					-- the hue; light text on a full fill may need to be near white.
					if L < 0.5 or pair[2] ~= name then
						expect(C > 0.02).to.equal(true)
					end
					if C > 0.01 then
						expect(hueGap(H, fillH) < 25).to.equal(true)
					end
					local __ = themeName
				end
			end
		end)

		it("rings focus in blue unless the game picks a primary, never in the base grey", function()
			local failures = {}
			for _, base in Tokens.bases do
				local themes = Tokens.themesFor(base)
				expect(themes.light.Ring).to.equal("$Blue500")
				expect(themes.dark.Ring).to.equal("$Blue400")
				for themeName, values in themes do
					local resolved = Tokens.resolveTheme(values, Tokens.primitives)
					local function colour(value)
						for _ = 1, 16 do
							if typeof(value) == "Color3" then
								return value
							end
							local name = string.sub(value, 2)
							value = if resolved[name] ~= nil then resolved[name] else Tokens.primitives[name]
						end
						return value
					end
					-- WCAG non-text contrast: a focus ring needs 3:1 against the page.
					local ratio = Oklab.contrast(colour(resolved.Ring), colour(resolved.Background))
					if ratio < 3 then
						table.insert(failures, `{base}/{themeName} {string.format("%.2f", ratio)}`)
					end
				end
			end
			expect(table.concat(failures, "; ")).to.equal("")
			local violet = Tokens.themesFor("slate", { primary = "violet" })
			expect(violet.light.Ring).to.equal("$Violet400")
			expect(violet.dark.Ring).to.equal("$Violet300")
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
		it("composites over like CSS alpha (dark border is white at 10%)", function()
			local resolved = Tokens.resolveTheme(Tokens.themes.dark, Tokens.primitives)
			expect(resolved.Border:ToHex()).to.equal("222224")
		end)

		it("mixes in Oklab", function()
			local mixed =
				Tokens.resolveTheme({ M = Tokens.mix("$Black", "$White", 0.5) }, Tokens.primitives).M
			local L = Oklab.toOklch(mixed)
			expect(math.abs(L - 0.5) < 0.01).to.equal(true)
		end)

		it("works out readable text for a fill", function()
			local values = { Fill = "$Amber400", Text = Tokens.readable("$Fill", "$White", "$Zinc950") }
			local resolved = Tokens.resolveTheme(values, Tokens.primitives)
			expect(typeof(resolved.Text)).to.equal("Color3")
			expect(Oklab.contrast(resolved.Text, Oklab.palette("amber", 400)) >= 4.5).to.equal(true)
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
