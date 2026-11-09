return function()
	local Menu = require(script.Parent.Menu)
	local Composables = require(script.Parent.Parent.Composables)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local function near(a: Vector2, b: Vector2): boolean
		return (a - b).Magnitude < 0.5
	end

	describe("geometry", function()
		it("puts a ring's items around a circle, the first at the top, clockwise", function()
			local points = Menu.ring(4, 100)
			expect(#points).to.equal(4)
			expect(near(points[1], Vector2.new(0, -100))).to.equal(true)
			expect(near(points[2], Vector2.new(100, 0))).to.equal(true)
			expect(near(points[3], Vector2.new(0, 100))).to.equal(true)
			expect(near(points[4], Vector2.new(-100, 0))).to.equal(true)
		end)

		it("stacks a fan's items along a gentle curve, a step apart, tilting more as it goes", function()
			-- rising and bending right, like a dock's stack
			local points, tilts = Menu.fan(3, 50, 60, 1000, -1, 1)
			expect(#points).to.equal(3)
			expect(points[1].Y).to.be.near(-50, 0.1)
			for i = 2, 3 do
				expect(points[i].Y < points[i - 1].Y).to.equal(true)
				expect(points[i].X > points[i - 1].X).to.equal(true)
				expect(tilts[i] > tilts[i - 1]).to.equal(true)
				expect((points[i] - points[i - 1]).Magnitude).to.be.near(60, 0.5)
			end
			expect(tilts[1] > 0).to.equal(true)

			-- dropping and bending left mirrors it
			local down = Menu.fan(3, 50, 60, 1000, 1, -1)
			expect(near(down[3], Vector2.new(-points[3].X, -points[3].Y))).to.equal(true)
		end)

		it("finds the direction toward the middle of the screen", function()
			local view = Vector2.new(800, 600)
			local corner = Menu.toward(Vector2.new(760, 560), view)
			expect(corner > -180 and corner < -90).to.equal(true)
			expect(math.abs(Menu.toward(Vector2.new(400, 20), view) - 90) < 1).to.equal(true)
			expect(math.abs(Menu.toward(Vector2.new(20, 300), view)) < 1).to.equal(true)
		end)

		it("moves a ring's centre in until the whole ring is on screen", function()
			local view = Vector2.new(800, 600)
			expect(Menu.fit(Vector2.new(20, 300), 100, view, 8)).to.equal(Vector2.new(108, 300))
			expect(Menu.fit(Vector2.new(790, 590), 100, view, 8)).to.equal(Vector2.new(692, 492))
			expect(Menu.fit(Vector2.new(400, 300), 100, view, 8)).to.equal(Vector2.new(400, 300))
		end)

		it("nudges points that spill off the screen back on, and leaves the rest", function()
			local view = Vector2.new(800, 600)
			local points = { Vector2.new(-50, 0), Vector2.new(50, 40) }
			-- a label of 100 to the left of each point
			local pad = { left = 110, right = 10, top = 10, bottom = 10 }
			expect(Menu.nudge(Vector2.new(400, 300), points, pad, view, 8)).to.equal(Vector2.zero)
			-- the lower point would end at 550 + 40 + 10 = 600
			expect(Menu.nudge(Vector2.new(400, 550), points, pad, view, 8)).to.equal(
				Vector2.new(0, 592 - 600)
			)
			-- the left point's label would start at 150 - 50 - 110 = -10
			expect(Menu.nudge(Vector2.new(150, 300), points, pad, view, 8)).to.equal(Vector2.new(18, 0))
		end)

		it("opens a ring around an anchor that has room, and clear of one by the edge", function()
			local view = Vector2.new(800, 600)
			local size = Vector2.new(100, 40)
			expect(Menu.around(Vector2.new(400, 300), size, 100, view, 8)).to.equal(Vector2.new(400, 300))

			local button = Vector2.new(400, 570)
			local center = Menu.around(button, size, 100, view, 8)
			expect(center.X).to.be.near(400, 0.01)
			-- the whole ring sits above the button's top edge
			expect(center.Y + 100 <= button.Y - size.Y / 2).to.equal(true)
		end)

		it("bounds a ring button and its label, beside it or under it, with room around", function()
			-- A 56 button, a 60x20 label beside it (10 away) or under it (4 away), 6 of room, and
			-- twice that past the label's far end, so the ring never runs into the label's text
			local at, size = Menu.itemBounds("right", 56, Vector2.new(60, 20), 6)
			expect(at).to.equal(Vector2.new(-6, -6))
			expect(size).to.equal(Vector2.new(56 + 10 + 60 + 18, 56 + 12))

			at, size = Menu.itemBounds("left", 56, Vector2.new(60, 20), 6)
			expect(at).to.equal(Vector2.new(-10 - 60 - 12, -6))
			expect(size).to.equal(Vector2.new(60 + 10 + 56 + 18, 56 + 12))

			-- Under it: a wide label sets the width, centred on the button
			at, size = Menu.itemBounds("below", 56, Vector2.new(80, 20), 6)
			expect(at).to.equal(Vector2.new(-12 - 6, -6))
			expect(size).to.equal(Vector2.new(80 + 12, 56 + 4 + 20 + 18))

			-- A label taller than the button sets the height beside it
			at, size = Menu.itemBounds("right", 56, Vector2.new(60, 80), 0)
			expect(at).to.equal(Vector2.new(0, -12))
			expect(size).to.equal(Vector2.new(126, 80))
		end)

		it("picks the item a stick points at, and nothing for a small push", function()
			local angles = Menu.angles(Menu.ring(4, 100))
			-- screen directions: x right, y down
			expect(Menu.pick(Vector2.new(0, -1), angles)).to.equal(1)
			expect(Menu.pick(Vector2.new(0.9, 0.2), angles)).to.equal(2)
			expect(Menu.pick(Vector2.new(-1, 0.1), angles)).to.equal(4)
			expect(Menu.pick(Vector2.new(0.2, 0.1), angles)).to.equal(nil)
		end)
	end)

	describe("component", function()
		local app, cleanup, gui
		beforeEach(function()
			app, cleanup = Harness.app({ theme = "light" })
			gui = Harness.mount(app)
		end)
		afterEach(function()
			cleanup()
		end)

		local ITEMS = {
			{ value = "dj", label = "DJ request" },
			{ value = "lab", label = "The Lab" },
			{ value = "items", label = "Items", disabled = true },
			{ value = "exit", label = "Exit" },
		}

		local function make(props: { [string]: any }?)
			local p = table.clone(props or {})
			p.app = app
			p.items = p.items or ITEMS
			p.Parent = gui
			return Menu.new(p)
		end

		it("keeps open in state, opens into the modal layer and closes on back", function()
			local menu = make({ id = "club" })
			expect(app.state:get("ui.club.open")).to.equal(false)
			menu:open()
			expect(app.state:get("ui.club.open")).to.equal(true)
			expect(menu.content:IsDescendantOf(app:portal("modal"))).to.equal(true)
			expect(app.input:back()).to.equal(true)
			expect(menu:get("open")).to.equal(false)
		end)

		it("gives focus back to its anchor on close, or to nothing with returnFocus false", function()
			local trigger = Instance.new("TextButton")
			trigger.Position = UDim2.fromOffset(0, 400)
			trigger.Parent = gui
			app.input:setMode("gamepad")
			app.input:focus(trigger)
			local menu = make({ id = "back", anchor = trigger })
			menu:open()
			expect(app.input:focused()).never.to.equal(trigger)
			menu:close()
			expect(app.input:focused()).to.equal(trigger)

			local hud = make({ id = "hud", anchor = trigger, returnFocus = false })
			hud:open()
			expect(app.input:focused()).never.to.equal(trigger)
			hud:close()
			expect(app.input:focused()).to.equal(nil)
		end)

		it("picks an item: reports it, emits select and closes", function()
			local picked, events = {}, {}
			local function on(name: string)
				return function(_, value)
					table.insert(events, if value == nil then name else `{name}:{tostring(value)}`)
				end
			end
			local scope = Reactive.effectScope(true)
			local menu = scope:run(function()
				Composables.useUiSound(app, { open = on("open"), close = on("close"), select = on("select") })
				return make({
					onSelect = function(value)
						table.insert(picked, value)
					end,
				})
			end)
			menu:open()
			menu:select("lab")
			expect(picked[1]).to.equal("lab")
			expect(menu:get("open")).to.equal(false)
			expect(table.concat(events, " ")).to.equal("open select:lab close")
			scope:stop()
		end)

		it("ignores a disabled item and an unknown value", function()
			local picked = {}
			local menu = make({
				onSelect = function(value)
					table.insert(picked, value)
				end,
			})
			menu:open()
			menu:select("items")
			menu:select("nope")
			expect(#picked).to.equal(0)
			expect(menu:get("open")).to.equal(true)
		end)

		it("is a list popup with mouse and a drawer on touch", function()
			local menu = make()
			menu:open()
			expect(menu.presentation()).to.equal("popup")
			menu:close()
			app.input:setMode("touch")
			menu:open()
			expect(menu.presentation()).to.equal("drawer")
		end)

		it("never turns a ring or an arc into a drawer", function()
			app.input:setMode("touch")
			local ring = make({ variant = "radial" })
			ring:open()
			expect(ring.presentation()).to.equal("popup")
			local fan = make({ variant = "arc" })
			fan:open()
			expect(fan.presentation()).to.equal("popup")
		end)

		it("shows the rows for a list and the slices for a ring or arc", function()
			local menu = make({ variant = "radial" })
			menu:open()
			expect(#menu.slices).to.equal(4)
			expect(menu.slices[1].Visible).to.equal(true)
			expect(menu.items[1].Visible).to.equal(false)
			expect(menu.slices[3].Selectable).to.equal(false) -- disabled
		end)

		it("rings a whole ring or arc item, its button and its label, when it has focus", function()
			local menu = make({ variant = "arc", shape = "squircle" })
			menu:open()
			local slice = menu.slices[1]
			-- The button's own ring hides (ui-ring-host) and the item's shows
			expect(slice:HasTag("ui-ring-host")).to.equal(true)
			local ring = slice:FindFirstChild("ItemRing") :: Frame
			expect(ring).to.be.ok()
			expect(ring:HasTag("ui-part-ring")).to.equal(true)
			expect(ring:HasTag("ui-menu-item-ring")).to.equal(true)
			expect(ring:HasTag("ui-menu-squircle")).to.equal(true)
			expect(ring.Selectable).to.equal(false)
			-- It reaches past the button, toward its label
			expect(ring.Size.X.Offset > Menu.sliceSize).to.equal(true)
		end)

		it("follows a responsive variant as the input changes", function()
			local menu = make({ variant = { gamepad = "radial", touch = "arc", default = "list" } })
			expect(menu.variant()).to.equal("list")
			app.input:setMode("gamepad")
			expect(menu.variant()).to.equal("radial")
			app.input:setMode("touch")
			expect(menu.variant()).to.equal("arc")
		end)

		it("rejects an unknown variant", function()
			expect(function()
				make({ variant = "spiral" })
			end).to.throw()
		end)

		it("shapes the round buttons, round unless told, and follows a responsive shape", function()
			local round = make({ variant = "radial" })
			expect(round.shape()).to.equal("round")
			expect(round.slices[1]:HasTag("ui-menu-squircle")).to.equal(false)
			expect(round.slices[1]:HasTag("ui-menu-square")).to.equal(false)

			local shaped = make({ variant = "radial", shape = { gamepad = "squircle", default = "square" } })
			expect(shaped.slices[1]:HasTag("ui-menu-square")).to.equal(true)
			app.input:setMode("gamepad")
			expect(shaped.shape()).to.equal("squircle")
			expect(shaped.slices[1]:HasTag("ui-menu-squircle")).to.equal(true)
			expect(shaped.slices[1]:HasTag("ui-menu-square")).to.equal(false)
		end)

		it("sizes its items like a button: md unless told, lg taller rows and bigger ring buttons", function()
			local md = make({ variant = "radial" })
			expect(md.size()).to.equal("md")
			expect(md.slices[1].Size.X.Offset).to.equal(Menu.sliceSizes.md)
			expect(md.items[1].Size.Y.Offset).to.equal(app.theme:resolve("ControlMd").Y.Offset)
			expect(md.items[1]:HasTag("ui-menu-lg")).to.equal(false)

			local lg = make({ variant = "radial", size = { gamepad = "lg", default = "md" } })
			expect(lg.size()).to.equal("md")
			app.input:setMode("gamepad")
			expect(lg.size()).to.equal("lg")
			expect(lg.slices[1].Size.X.Offset).to.equal(Menu.sliceSizes.lg)
			expect(lg.items[1].Size.Y.Offset).to.equal(app.theme:resolve("ControlLg").Y.Offset)
			expect(lg.items[1]:HasTag("ui-menu-lg")).to.equal(true)
			expect(lg.slices[1]:HasTag("ui-menu-lg")).to.equal(true)
			expect(Menu.sliceSizes.lg > Menu.sliceSizes.md).to.equal(true)
		end)

		it("grows a list to fit its widest label, so no label ends in an ellipsis", function()
			if not Harness.laysOutLive() then
				return -- TextFits and the placed width are measured: live layout only (Harness.laysOutLive)
			end
			local menu = make({
				id = "wide",
				items = {
					{ value = "long", label = "A menu label far too long for the usual width" },
					{ value = "short", label = "Exit" },
				},
			})
			menu:open()
			local label = menu.items[1]:FindFirstChild("Label") :: TextLabel
			for _ = 1, 60 do
				if label.TextFits and menu.content.AbsoluteSize.X > 220 then
					break
				end
				task.wait()
			end
			expect(label.TextFits).to.equal(true)
			menu:close()
		end)

		it("rejects an unknown size", function()
			expect(function()
				make({ size = "xl" })
			end).to.throw()
		end)

		it("rejects an unknown shape", function()
			expect(function()
				make({ shape = "star" })
			end).to.throw()
		end)
	end)
end
