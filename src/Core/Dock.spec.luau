return function()
	local Dock = require(script.Parent.Dock)
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

	it("selects the newest sheet when a gamepad is picked up after it opened", function()
		-- A title menu, opened before the player touches the pad
		app.input:setMode("mouse")
		local start = button("Start")
		local menu = Sheet.new({ app = app, id = "menu", dock = "menu", width = 300, children = { start } })
		menu:open()
		expect(Harness.waitFor(function()
			return settled(menu)
		end)).to.equal(true)
		expect(app.input:focused()).to.equal(nil)
		app.input:setMode("gamepad")
		expect(Harness.waitFor(function()
			return app.input:focused() == start
		end, 1)).to.equal(true)
	end)

	it("leaves the focus alone when a gamepad is picked up with something already selected", function()
		app.input:setMode("keyboard")
		local start, quit = button("Start"), button("Quit")
		local menu =
			Sheet.new({ app = app, id = "menu", dock = "menu", width = 300, children = { start, quit } })
		menu:open()
		expect(Harness.waitFor(function()
			return settled(menu) and app.input:focused() == start
		end, 1)).to.equal(true)
		task.wait(Dock.slideTime + 0.05) -- the opening's own selection is done
		app.input:focus(quit)
		app.input:setMode("gamepad")
		task.wait(0.4)
		expect(app.input:focused()).to.equal(quit)
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

	it("opens one dock at a time: opening a sheet closes the other docks", function()
		local a = Sheet.new({ app = app, dock = "one", width = 300 })
		local b = Sheet.new({ app = app, dock = "two", width = 300 })
		a:open()
		expect(Harness.waitFor(function()
			return settled(a)
		end)).to.equal(true)
		b:open()
		expect(a:get("open")).to.equal(false)
		expect(b:get("open")).to.equal(true)
	end)

	it("holds a pinned sheet at its edge and opens later ones beside it, without sliding", function()
		local menu = Sheet.new({
			app = app,
			id = "menu",
			dock = "left-nav",
			side = "left",
			dockPin = true,
			width = 240,
			children = { button("Items") },
		})
		local detail = Sheet.new({
			app = app,
			id = "detail",
			dock = "left-nav",
			side = "left",
			width = 320,
			dockSlide = false,
			children = { button("Equip") },
		})
		menu:open()
		expect(Harness.waitFor(function()
			return settled(menu)
		end, 1)).to.equal(true)
		local root = menu.frame:FindFirstAncestorWhichIsA("LayerCollector") :: ScreenGui
		local screenLeft = root.AbsolutePosition.X
		detail:open()
		expect(Harness.waitFor(function()
			return settled(detail)
				and math.abs(menu.frame.AbsolutePosition.X - screenLeft) <= 2
				and math.abs(rightEdge(menu.frame) - detail.frame.AbsolutePosition.X) <= 2
		end, 1)).to.equal(true)
		detail:close()
		expect(detail:get("open")).to.equal(false)
		expect(menu:get("open")).to.equal(true)
	end)

	it("docks each sheet to its own side, one backdrop for both edges", function()
		local crate = Sheet.new({
			app = app,
			id = "crate",
			dock = "loot",
			side = "left",
			width = 300,
			children = { button("Take") },
		})
		local bag = Sheet.new({
			app = app,
			id = "bag",
			dock = "loot",
			side = "right",
			width = 300,
			children = { button("Drop") },
		})
		crate:open()
		bag:open()
		expect(Harness.waitFor(function()
			return settled(crate) and settled(bag)
		end, 1)).to.equal(true)
		local root = bag.frame:FindFirstAncestorWhichIsA("LayerCollector") :: ScreenGui
		expect(Harness.waitFor(function()
			return math.abs(crate.frame.AbsolutePosition.X - root.AbsolutePosition.X) <= 2
				and math.abs(rightEdge(bag.frame) - (root.AbsolutePosition.X + root.AbsoluteSize.X)) <= 2
		end, 1)).to.equal(true)
		local scope = app.input:topScope()
		expect(crate.frame:IsDescendantOf(scope.root)).to.equal(true)
		expect(bag.frame:IsDescendantOf(scope.root)).to.equal(true)
	end)

	it("drops the dimmed backdrop when every open sheet sets scrim = false", function()
		local menu = Sheet.new({
			app = app,
			id = "menu",
			dock = "menu",
			side = "left",
			width = 240,
			scrim = false,
			children = { button("Play") },
		})
		local modalSub = Sheet.new({
			app = app,
			id = "modal-sub",
			dock = "menu",
			side = "left",
			width = 300,
			children = { button("OK") },
		})
		menu:open()
		expect(Harness.waitFor(function()
			return settled(menu)
		end, 1)).to.equal(true)
		local dock = (app :: any)._lucyDocks.menu
		expect(dock.overlay.scrim:HasTag("ui-overlay-scrim")).to.equal(false)
		expect(dock.overlay.scrim:HasTag("ui-overlay-clear")).to.equal(true)

		modalSub:open()
		expect(Harness.waitFor(function()
			return settled(modalSub)
		end, 1)).to.equal(true)
		expect(dock.overlay.scrim:HasTag("ui-overlay-scrim")).to.equal(true)

		modalSub:close()
		expect(Harness.waitFor(function()
			return not dock.overlay.scrim:HasTag("ui-overlay-scrim")
		end, 1)).to.equal(true)
		expect(dock.overlay.scrim:HasTag("ui-overlay-clear")).to.equal(true)
	end)

	it("gives a sheet with scroll = false a fixed body, and a filling child the rest of it", function()
		local top = Instance.new("Frame")
		top.Name = "Top"
		top.Size = UDim2.new(1, 0, 0, 100)
		local rest = Instance.new("Frame")
		rest.Name = "Rest"
		rest.Size = UDim2.fromScale(1, 0)
		local grow = Instance.new("UIFlexItem")
		grow.FlexMode = Enum.UIFlexMode.Fill
		grow.Parent = rest
		local sheet = Sheet.new({
			app = app,
			dock = "fixed",
			width = 300,
			scroll = false,
			children = { top, rest },
		})
		sheet:open()
		expect(Harness.waitFor(function()
			return settled(sheet) and rest.AbsoluteSize.Y > 0
		end, 1)).to.equal(true)
		expect(top:FindFirstAncestorWhichIsA("ScrollingFrame")).to.equal(nil)
		local body = top.Parent :: Frame
		expect(body.Name).to.equal("Body")
		local bottom = rest.AbsolutePosition.Y + rest.AbsoluteSize.Y
		expect(math.abs(bottom - (body.AbsolutePosition.Y + body.AbsoluteSize.Y)) <= 2).to.equal(true)
	end)

	it("follows a width given as a ref", function()
		local Reactive = require(script.Parent.Reactive)
		local wide = Reactive.ref(300)
		local sheet = Sheet.new({ app = app, dock = "grow", width = wide, children = { button("A") } })
		sheet:open()
		expect(Harness.waitFor(function()
			return settled(sheet)
		end, 1)).to.equal(true)
		local before = sheet.frame.AbsoluteSize.X
		wide(400)
		expect(Harness.waitFor(function()
			return math.abs(sheet.frame.AbsoluteSize.X - before * 4 / 3) <= 2
		end, 1)).to.equal(true)
	end)

	describe("fit", function()
		local function item(width: number, minWidth: number, pin: boolean, order: number)
			return { width = width, minWidth = minWidth, pin = pin, order = order }
		end

		it("leaves widths alone when they fit", function()
			local w = Dock.fit({ item(300, 200, false, 1), item(400, 300, false, 2) }, 800)
			expect(w[1]).to.equal(300)
			expect(w[2]).to.equal(400)
		end)

		it("squeezes the oldest unpinned sheet first, down to its minWidth", function()
			local w = Dock.fit({ item(414, 300, false, 1), item(528, 420, false, 2) }, 760)
			expect(w[1]).to.equal(300)
			expect(w[2]).to.equal(460)
		end)

		it("squeezes unpinned sheets before pinned ones", function()
			local w = Dock.fit({ item(300, 200, true, 1), item(400, 300, false, 2) }, 650)
			expect(w[1]).to.equal(300)
			expect(w[2]).to.equal(350)
		end)

		it("never squeezes a sheet that has no minWidth below its width", function()
			local w = Dock.fit({ item(300, 300, false, 1), item(400, 200, false, 2) }, 600)
			expect(w[1]).to.equal(300)
			expect(w[2]).to.equal(300)
		end)

		it("shares the room by minWidth when even those do not fit", function()
			local w = Dock.fit({ item(400, 300, false, 1), item(400, 100, false, 2) }, 200)
			expect(w[1]).to.equal(150)
			expect(w[2]).to.equal(50)
		end)
	end)
end
