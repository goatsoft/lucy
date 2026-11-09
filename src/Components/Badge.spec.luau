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
end
