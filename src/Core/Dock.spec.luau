return function()
	local Sheet = require(script.Parent.Parent.Components.Sheet)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
	end)
	afterEach(function()
		cleanup()
	end)

	local function button(name: string): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.fromOffset(120, 32)
		return b
	end

	local function rightEdge(object: GuiObject): number
		return object.AbsolutePosition.X + object.AbsoluteSize.X
	end

	local function settled(sheet: any): boolean
		return sheet.frame ~= nil and sheet.frame.AbsoluteSize.X > 0
	end

	-- The boot, then the inventory: the boot is pushed over by the inventory's width
	local function pair()
		local boot =
			Sheet.new({ app = app, id = "boot", dock = "loot", width = 300, children = { button("Take") } })
		local bag =
			Sheet.new({ app = app, id = "bag", dock = "loot", width = 360, children = { button("Drop") } })
		return boot, bag
	end

	it("puts the newest docked sheet at the edge and pushes the others over", function()
		local boot, bag = pair()
		boot:open()
		expect(Harness.waitFor(function()
			return settled(boot)
		end)).to.equal(true)
		local root = boot.frame:FindFirstAncestorWhichIsA("LayerCollector") :: ScreenGui
		local screenRight = root.AbsolutePosition.X + root.AbsoluteSize.X
		expect(Harness.waitFor(function()
			return math.abs(rightEdge(boot.frame) - screenRight) <= 2
		end, 1)).to.equal(true)
		bag:open()
		expect(Harness.waitFor(function()
			return settled(bag)
				and math.abs(rightEdge(bag.frame) - screenRight) <= 2
				and math.abs(rightEdge(boot.frame) - bag.frame.AbsolutePosition.X) <= 2
		end, 1)).to.equal(true)
	end)

	it("slides the others back to the edge when the newest closes", function()
		local boot, bag = pair()
		boot:open()
		bag:open()
		expect(Harness.waitFor(function()
			return settled(bag)
		end)).to.equal(true)
		bag:close()
		local root = boot.frame:FindFirstAncestorWhichIsA("LayerCollector") :: ScreenGui
		local screenRight = root.AbsolutePosition.X + root.AbsoluteSize.X
		expect(Harness.waitFor(function()
			return math.abs(rightEdge(boot.frame) - screenRight) <= 2
		end, 1)).to.equal(true)
		expect(boot:get("open")).to.equal(true)
	end)

	it("shares one backdrop and one focus scope, so either can be used", function()
		local boot, bag = pair()
		boot:open()
		bag:open()
		expect(Harness.waitFor(function()
			return settled(bag) and settled(boot)
		end)).to.equal(true)
		-- both panels sit under the one overlay root, so nothing covers the older one
		local overlayRoot = bag.frame.Parent and bag.frame.Parent.Parent and bag.frame.Parent.Parent.Parent
		expect(overlayRoot).to.be.ok()
		expect(boot.frame:IsDescendantOf(overlayRoot)).to.equal(true)
		local scope = app.input:topScope()
		expect(scope).to.be.ok()
		expect(boot.frame:IsDescendantOf(scope.root)).to.equal(true)
		expect(bag.frame:IsDescendantOf(scope.root)).to.equal(true)
	end)

	it("closes the newest on back, then the next", function()
		local boot, bag = pair()
		boot:open()
		bag:open()
		expect(app.input:back()).to.equal(true)
		expect(bag:get("open")).to.equal(false)
		expect(boot:get("open")).to.equal(true)
		expect(app.input:back()).to.equal(true)
		expect(boot:get("open")).to.equal(false)
	end)

	it("counts as one modal while any of the dock is open", function()
		local boot, bag = pair()
		boot:open()
		bag:open()
		expect(app:modalOpen()).to.equal(true)
		boot:close()
		bag:close()
		expect(Harness.waitFor(function()
			return not app:modalOpen()
		end, 1)).to.equal(true)
	end)

	it("keeps sheets in different docks apart", function()
		local a = Sheet.new({ app = app, dock = "one", width = 300 })
		local b = Sheet.new({ app = app, dock = "two", width = 300 })
		a:open()
		b:open()
		expect(Harness.waitFor(function()
			return settled(a) and settled(b)
		end)).to.equal(true)
		expect(math.abs(rightEdge(a.frame) - rightEdge(b.frame)) <= 2).to.equal(true)
	end)
end
