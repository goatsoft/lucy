return function()
	local Badge = require(script.Parent.Badge)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("follows reactive text and variant", function()
		local Reactive = require(script.Parent.Parent.Core.Reactive)
		local kills = Reactive.ref(0)
		local badge = Badge.new({
			app = app,
			Parent = gui,
			text = Reactive.computed(function()
				return tostring(kills())
			end),
			variant = function()
				return if kills() >= 10 then "destructive" else "default"
			end,
		})
		expect(badge.Instance.Text).to.equal("0")
		kills(12)
		expect(badge.Instance.Text).to.equal("12")
		expect(badge.Instance:HasTag("ui-badge-variant-destructive")).to.equal(true)
	end)

	it("renders an auto-sized, tagged label", function()
		local badge = Badge.new({ app = app, Parent = gui, text = "New" })
		expect(badge.Instance:IsA("TextLabel")).to.equal(true)
		expect(badge.Instance.Text).to.equal("New")
		expect(badge.Instance.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
		expect(badge.Instance:HasTag("ui-badge-variant-default")).to.equal(true)
	end)

	it("updates text and variant from state", function()
		local badge = Badge.new({ app = app, id = "kills", Parent = gui })
		app.state:merge("ui.kills", { text = "12", variant = "destructive" })
		expect(badge.Instance.Text).to.equal("12")
		expect(badge.Instance:HasTag("ui-badge-variant-destructive")).to.equal(true)
	end)

	it("styles the destructive variant", function()
		local badge = Badge.new({ app = app, Parent = gui, variant = "destructive" })
		Harness.flush()
		expect(
			Harness.colorEq(
				Harness.styled(badge.Instance, "BackgroundColor3"),
				app.theme:resolve("Destructive")
			)
		).to.equal(true)
	end)

	it("styles the overlay variant: a see-through fill from the theme, over a picture", function()
		local badge = Badge.new({ app = app, Parent = gui, text = "3", variant = "overlay" })
		Harness.flush()
		expect(badge.Instance:HasTag("ui-badge-variant-overlay")).to.equal(true)
		expect(
			Harness.colorEq(
				Harness.styled(badge.Instance, "BackgroundColor3"),
				app.theme:resolve("OverlayFill")
			)
		).to.equal(true)
		local see = Harness.styled(badge.Instance, "BackgroundTransparency")
		expect(see > 0 and see < 1).to.equal(true)
		local found = {}
		for _, rule in Badge.rules do
			found[rule.selector] = rule
		end
		local own = found[".ui-badge-variant-overlay > .ui-slot-text"]
		expect(own and own.properties.TextColor3).to.equal("$OverlayFillForeground")
	end)

	it("has an overlay fill in both themes: light words on dark, dark words on light", function()
		local Tokens = require(script.Parent.Parent.Core.Tokens)
		local themes = Tokens.themesFor("zinc")
		local light, dark = themes.light, themes.dark
		for _, theme in { light, dark } do
			expect(theme.OverlayFill).to.be.ok()
			expect(theme.OverlayFillForeground).to.be.ok()
			expect(theme.OverlayFillTransparency).to.be.ok()
		end
		expect(dark.OverlayFill).to.equal("$Black")
		expect(light.OverlayFill).to.equal("$White")
	end)

	it("is rounded by default and only slightly rounded when square", function()
		local round = Badge.new({ app = app, Parent = gui, text = "NEW" })
		local square = Badge.new({ app = app, Parent = gui, text = "RARE", shape = "square" })
		expect(round.Instance:HasTag("ui-badge-shape-square")).to.equal(false)
		expect(square.Instance:HasTag("ui-badge-shape-square")).to.equal(true)
		local radius
		for _, rule in Badge.rules do
			if rule.selector == ".ui-badge-shape-square::UICorner" then
				radius = rule.properties.CornerRadius
			end
		end
		expect(radius).to.equal("$RadiusXs")
		square:set("shape", "rounded")
		expect(square.Instance:HasTag("ui-badge-shape-square")).to.equal(false)
	end)

	it("rejects unknown shapes", function()
		expect(function()
			Badge.new({ app = app, shape = "star" })
		end).to.throw()
	end)

	it("holds an icon, its text and children in a row (a slot)", function()
		local Slot = require(script.Parent.Slot)
		local extra = Instance.new("Frame")
		local badge = Badge.new({
			app = app,
			Parent = gui,
			icon = "lucy:close",
			text = "LV 12",
			children = { "PRO", extra },
		})
		local root = badge.Instance :: TextLabel
		expect(root.Text).to.equal("")
		expect(root:FindFirstChildOfClass("UIListLayout")).to.be.ok()
		expect(badge.icon.Instance.Parent).to.equal(root)
		expect(badge.label.Instance.Text).to.equal("LV 12")
		expect(badge.label.Instance:HasTag(Slot.TEXT_TAG)).to.equal(true)
		local words = {}
		for _, child in root:GetChildren() do
			if child:IsA("TextLabel") and child:HasTag(Slot.TEXT_TAG) then
				words[child.LayoutOrder] = child.Text
			end
		end
		expect(words[2]).to.equal("LV 12")
		expect(words[3]).to.equal("PRO")
		expect(extra.Parent).to.equal(root)
		expect(extra.LayoutOrder).to.equal(4)
		-- The text follows its state, and goes when it is empty
		badge:set("text", "LV 13")
		expect(badge.label.Instance.Text).to.equal("LV 13")
		badge:set("text", "")
		expect(badge.label.Instance.Visible).to.equal(false)
	end)

	it("shows an icon alone, with no default text", function()
		local badge = Badge.new({ app = app, Parent = gui, icon = "lucy:close" })
		expect(badge.label.Instance.Visible).to.equal(false)
		expect(badge.icon.Instance.Visible).to.equal(true)
	end)

	it("passes its colours down to what is in it", function()
		local found = {}
		for _, rule in Badge.rules do
			found[rule.selector] = rule
		end
		local own = found[".ui-badge-variant-outline > .ui-slot-text"]
		local text = found[".ui-badge-variant-outline >> .ui-text"]
		local icon = found[".ui-badge-variant-outline >> .ui-icon"]
		expect(own and own.properties.TextColor3).to.equal("$Foreground")
		expect(text and text.properties.TextColor3).to.equal("$Foreground")
		expect(icon and icon.properties.ImageColor3).to.equal("$Foreground")
		-- Over Text's and Icon's own variants
		expect(icon.priority > 10).to.equal(true)
		-- The badge's size reaches its own words, not a Text put in it
		local base = found[".ui-badge > .ui-slot-text"]
		expect(base and base.properties.TextSize).to.equal("$TextXs")
		expect(found[".ui-badge >> .ui-text"].properties.TextSize).to.equal(nil)
	end)

	it("rejects unknown variants", function()
		expect(function()
			Badge.new({ app = app, variant = "gold" })
		end).to.throw()
	end)
	describe("size", function()
		-- A badge's words at each size are a Button's at that size, so a badge sits right beside one
		local TEXT = { sm = "TextXs", md = "TextSm", lg = "TextBase", xl = "TextLg" }

		it("is sm by default and follows state", function()
			local badge = Badge.new({ app = app, id = "tag", Parent = gui, text = "HOUSE" })
			expect(badge.Instance:HasTag("ui-badge-size-sm")).to.equal(true)
			app.state:set("ui.tag.size", "lg")
			expect(badge.Instance:HasTag("ui-badge-size-lg")).to.equal(true)
			expect(badge.Instance:HasTag("ui-badge-size-sm")).to.equal(false)
		end)

		it("sizes its words as a Button of the same size", function()
			for size, token in TEXT do
				local badge = Badge.new({ app = app, Parent = gui, text = "LV 12", size = size })
				Harness.flush()
				expect(Harness.styled(badge.Instance, "TextSize")).to.equal(app.theme:resolve(token))
			end
		end)

		it("grows its icon and the words in its slot with it", function()
			local small = Badge.new({ app = app, Parent = gui, text = "VIP", icon = "lucy:close" })
			local big = Badge.new({ app = app, Parent = gui, text = "VIP", icon = "lucy:close", size = "xl" })
			Harness.flush()
			expect(big.icon.Instance.Size.X.Offset > small.icon.Instance.Size.X.Offset).to.equal(true)
			expect(Harness.styled(big.label.Instance, "TextSize")).to.equal(app.theme:resolve("TextLg"))
		end)

		it("pads a bigger badge more", function()
			local found = {}
			for _, rule in Badge.rules do
				found[rule.selector] = rule
			end
			local function top(selector: string): number
				local value = found[selector].properties.PaddingTop
				return if typeof(value) == "UDim"
					then value.Offset
					else app.theme:resolve(string.sub(value, 2)).Offset
			end
			local sm = top(".ui-badge::UIPadding")
			local md = top(".ui-badge-size-md::UIPadding")
			local lg = top(".ui-badge-size-lg::UIPadding")
			local xl = top(".ui-badge-size-xl::UIPadding")
			expect(sm < md and md < lg and lg < xl).to.equal(true)
		end)

		it("errors on an unknown size", function()
			expect(function()
				Badge.new({ app = app, size = "huge" })
			end).to.throw()
		end)
	end)
end
