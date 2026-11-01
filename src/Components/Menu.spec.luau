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

		it("fans an arc's items around a direction, a fixed angle apart", function()
			-- straight up, three items 30 degrees apart
			local points = Menu.arc(3, 100, -90, 30)
			expect(near(points[2], Vector2.new(0, -100))).to.equal(true)
			expect(near(points[1], Vector2.new(-50, -86.6))).to.equal(true)
			expect(near(points[3], Vector2.new(50, -86.6))).to.equal(true)
		end)

		it("points an arc from its anchor toward the middle of the screen", function()
			local view = Vector2.new(800, 600)
			-- a button in the bottom right corner fans up and to the left
			local corner = Menu.toward(Vector2.new(760, 560), view)
			expect(corner > -180 and corner < -90).to.equal(true)
			-- a button at the top middle fans straight down
			expect(math.abs(Menu.toward(Vector2.new(400, 20), view) - 90) < 1).to.equal(true)
			-- one at the left middle fans right
			expect(math.abs(Menu.toward(Vector2.new(20, 300), view)) < 1).to.equal(true)
		end)

		it("moves a ring's centre in until the whole ring is on screen", function()
			local view = Vector2.new(800, 600)
			expect(Menu.fit(Vector2.new(20, 300), 100, view, 8)).to.equal(Vector2.new(108, 300))
			expect(Menu.fit(Vector2.new(790, 590), 100, view, 8)).to.equal(Vector2.new(692, 492))
			expect(Menu.fit(Vector2.new(400, 300), 100, view, 8)).to.equal(Vector2.new(400, 300))
		end)

		it("spreads a long arc no wider than arcSpread", function()
			expect(Menu.arcStep(3)).to.equal(Menu.arcSpacing)
			expect(Menu.arcStep(7)).to.be.near(Menu.arcSpread / 6, 0.001)
			expect(Menu.arcStep(1)).to.equal(Menu.arcSpacing)
		end)

		it("nudges points that spill off the screen back on, and leaves the rest", function()
			local view = Vector2.new(800, 600)
			local points = { Vector2.new(-50, 0), Vector2.new(50, 40) }
			expect(Menu.nudge(Vector2.new(400, 300), points, 20, 10, view, 8)).to.equal(Vector2.zero)
			-- the lower point's label would end at 590 + 10 + 10 = 610
			local moved = Menu.nudge(Vector2.new(400, 550), points, 20, 10, view, 8)
			expect(moved).to.equal(Vector2.new(0, 592 - 610))
			local left = Menu.nudge(Vector2.new(20, 300), points, 20, 10, view, 8)
			expect(left).to.equal(Vector2.new(8 - (20 - 50 - 10), 0))
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

		it("rejects an unknown shape", function()
			expect(function()
				make({ shape = "star" })
			end).to.throw()
		end)
	end)
end
