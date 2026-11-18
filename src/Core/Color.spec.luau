return function()
	local Color = require(script.Parent.Color)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Reactive = require(script.Parent.Reactive)

	local made: { Instance } = {}
	afterEach(function()
		for _, instance in made do
			instance:Destroy()
		end
		table.clear(made)
	end)

	local function frame(tag: string?, parent: Instance?): Frame
		local f = Instance.new("Frame")
		if tag then
			f:AddTag(tag)
		end
		f.Parent = parent
		if not parent then
			table.insert(made, f)
		end
		return f
	end

	describe("a coloured container", function()
		it("tags itself and the tagged elements in it with its colour, not the untagged ones", function()
			local panel = frame("probe-panel")
			local button = frame("probe-button", panel)
			local bare = frame(nil, panel)
			local stop = Color.scope(panel, "hype")
			expect(panel:HasTag("ui-color-hype")).to.equal(true)
			expect(button:HasTag("ui-color-hype")).to.equal(true)
			expect(bare:HasTag("ui-color-hype")).to.equal(false)
			stop()
		end)

		it("tags what is added to it later", function()
			local panel = frame("probe-panel")
			local stop = Color.scope(panel, "hype")
			local holder = frame(nil)
			local button = frame("probe-button", holder)
			holder.Parent = panel
			expect(button:HasTag("ui-color-hype")).to.equal(true)
			stop()
		end)

		it("lets the nearest coloured container win, whichever was coloured first", function()
			local panel = frame("probe-panel")
			local card = frame("probe-card", panel)
			local inCard = frame("probe-button", card)
			local inPanel = frame("probe-button", panel)
			local stopCard = Color.scope(card, "premium")
			local stopPanel = Color.scope(panel, "hype")
			expect(inCard:HasTag("ui-color-premium")).to.equal(true)
			expect(inCard:HasTag("ui-color-hype")).to.equal(false)
			expect(inPanel:HasTag("ui-color-hype")).to.equal(true)
			-- Added later, under the card: still the card's
			local late = frame("probe-button", card)
			expect(late:HasTag("ui-color-premium")).to.equal(true)
			expect(late:HasTag("ui-color-hype")).to.equal(false)
			stopCard()
			stopPanel()
		end)

		it("follows a getter: a new colour retags, nil takes it off", function()
			local panel = frame("probe-panel")
			local button = frame("probe-button", panel)
			local colour = Reactive.ref("hype" :: string?)
			local scope = Reactive.effectScope()
			scope:run(function()
				Color.scope(panel, colour)
			end)
			expect(button:HasTag("ui-color-hype")).to.equal(true)
			colour("premium")
			expect(Harness.waitFor(function()
				return button:HasTag("ui-color-premium") and not button:HasTag("ui-color-hype")
			end)).to.equal(true)
			colour(nil)
			expect(Harness.waitFor(function()
				return not button:HasTag("ui-color-premium")
			end)).to.equal(true)
			-- Stopping the owner stops the container
			colour("hype")
			scope:stop()
			task.wait()
			expect(button:HasTag("ui-color-hype")).to.equal(false)
		end)

		it("takes its colour off what it tagged when it stops", function()
			local panel = frame("probe-panel")
			local button = frame("probe-button", panel)
			local stop = Color.scope(panel, "hype")
			stop()
			expect(panel:HasTag("ui-color-hype")).to.equal(false)
			expect(button:HasTag("ui-color-hype")).to.equal(false)
		end)

		it("takes the colour off an element moved out of it", function()
			local panel = frame("probe-panel")
			local button = frame("probe-button", panel)
			local elsewhere = frame(nil)
			local stop = Color.scope(panel, "hype")
			button.Parent = elsewhere
			expect(Harness.waitFor(function()
				return not button:HasTag("ui-color-hype")
			end)).to.equal(true)
			stop()
		end)
	end)

	describe("with the theme", function()
		local Lucy = require(script.Parent.Parent)
		local app, cleanup
		beforeEach(function()
			app, cleanup = Harness.app({ colors = { hype = "$Green500" } })
		end)
		afterEach(function()
			cleanup()
		end)

		local function fill(instance: Instance): Color3
			return Harness.styled(instance, "BackgroundColor3")
		end

		it("colours Lucy's components in a coloured container, and Primary outside one", function()
			local gui = Harness.mount(app)
			local panel = Lucy.new("Frame")({ Parent = gui })
			Lucy.color(panel, "hype")
			local inside = Lucy.Button.new({ app = app, text = "In", Parent = panel })
			local outside = Lucy.Button.new({ app = app, text = "Out", Parent = gui })
			Harness.flush()
			expect(Harness.colorEq(fill(inside.Instance), app.theme:resolve("Hype"))).to.equal(true)
			expect(Harness.colorEq(fill(outside.Instance), app.theme:resolve("Primary"))).to.equal(true)
		end)

		it("takes a colour from a component's color prop", function()
			local gui = Harness.mount(app)
			local button = Lucy.Button.new({ app = app, text = "Go", color = "hype", Parent = gui })
			Harness.flush()
			expect(Harness.colorEq(fill(button.Instance), app.theme:resolve("Hype"))).to.equal(true)
		end)
	end)
end
