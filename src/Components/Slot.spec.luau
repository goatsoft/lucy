return function()
	local Slot = require(script.Parent.Slot)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app()
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	it("fills a slot with words, handles, instances and builders, in order", function()
		local frame = Instance.new("Frame")
		frame.Parent = gui
		local plain = Instance.new("Frame")
		local built: Frame? = nil
		local last = Slot.fill(frame, {
			"HELLO",
			plain,
			function(parent)
				local f = Instance.new("Frame")
				f.Name = "Built"
				f.Parent = parent
				built = f
			end,
			42,
		}, { app = app })
		local words = {}
		for _, child in frame:GetChildren() do
			if child:HasTag(Slot.TEXT_TAG) then
				words[child.LayoutOrder] = (child :: TextLabel).Text
			end
		end
		expect(words[1]).to.equal("HELLO")
		expect(plain.LayoutOrder).to.equal(2)
		expect(built).to.be.ok()
		expect(words[3]).to.equal("42")
		expect(last).to.equal(3)
	end)

	it("twins a rule's text properties for the slot, any text and any icon below", function()
		local rules = Slot.flow({
			{
				selector = ".x",
				priority = 20,
				properties = { TextColor3 = "$Red", TextSize = "$TextLg", BackgroundColor3 = "$Blue" },
			},
			{ selector = ".x::UICorner", priority = 0, properties = { CornerRadius = UDim.new(0, 4) } },
			{ selector = ".x > .y", priority = 0, properties = { TextColor3 = "$Red" } },
			{ selector = ".z", priority = 0, properties = { BackgroundColor3 = "$Blue" } },
		})
		local found = {}
		for _, rule in rules do
			found[rule.selector] = rule
		end
		expect(#rules).to.equal(3)
		local own = found[".x > .ui-slot-text"]
		expect(own.priority).to.equal(31)
		expect(own.properties.TextColor3).to.equal("$Red")
		expect(own.properties.TextSize).to.equal("$TextLg")
		expect(own.properties.BackgroundColor3).to.equal(nil)
		expect(found[".x >> .ui-text"].properties.TextSize).to.equal(nil)
		expect(found[".x >> .ui-icon"].properties.ImageColor3).to.equal("$Red")
	end)

	it("gives a game's colour to a component and what is in it", function()
		local rules = Slot.foreground(".ui-badge.gold", "$Yellow400", 41)
		expect(rules[1].selector).to.equal(".ui-badge.gold")
		expect(rules[1].priority).to.equal(41)
		local icon
		for _, rule in rules do
			if rule.selector == ".ui-badge.gold >> .ui-icon" then
				icon = rule
			end
		end
		expect(icon.properties.ImageColor3).to.equal("$Yellow400")
		expect(icon.priority).to.equal(52)
	end)
end
