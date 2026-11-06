return function()
	local Button = require(script.Parent.Button)
	local Scroll = require(script.Parent.Parent.Core.Scroll)
	local Tour = require(script.Parent.Tour)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	local app, cleanup, gui, folder
	beforeEach(function()
		folder = Instance.new("Folder")
		folder.Name = "LucyTourSpec"
		folder.Parent = game:GetService("ServerStorage")
		app, cleanup = Harness.app({
			namePrefix = "TourSpec_",
			actions = {
				parent = folder,
				controls = "new",
				contextActions = { BindActionAtPriority = function() end, UnbindAction = function() end },
			},
		})
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
		folder:Destroy()
	end)

	-- Needs a screen (run on the Client): a target is only shown once it has a size, and a
	-- Button's height comes from its style rules, a few frames after it is made.
	local function frame()
		Harness.flush()
	end

	local function button(id: string, position: UDim2?, props: { [string]: any }?)
		local options: { [string]: any } = {
			app = app,
			id = id,
			text = id,
			Parent = gui,
		}
		for key, value in props or {} do
			options[key] = value
		end
		local handle = Button.new(options)
		handle.Instance.Position = position or UDim2.fromOffset(400, 300)
		return handle
	end

	local function steps(): { any }
		return {
			{ id = "menu", target = "menu", text = "Open the menu" },
			{ id = "join", target = "join", text = "Join the show" },
		}
	end

	describe("running", function()
		it("publishes the running tour and its step", function()
			button("menu")
			local tour = Tour.new(app, { id = "first", steps = steps() })
			tour:start()
			frame()
			local state = app.state:get("tour")
			expect(state.id).to.equal("first")
			expect(state.step).to.equal("menu")
			expect(state.index).to.equal(1)
			expect(state.waiting).to.equal(false)
			expect(tour.running()).to.equal(true)
			tour:stop()
			expect(app.state:get("tour")).to.equal(nil)
			expect(tour.running()).to.equal(false)
		end)

		it("waits, drawing nothing, until the target is shown", function()
			local shown = {}
			local tour = Tour.new(app, {
				id = "first",
				steps = steps(),
				onStep = function(step, index)
					table.insert(shown, { step.id, index })
				end,
			})
			tour:start()
			frame()
			expect(tour.waiting()).to.equal(true)
			expect(tour.root.Visible).to.equal(false)
			expect(#shown).to.equal(0)
			button("menu")
			frame()
			expect(tour.waiting()).to.equal(false)
			expect(tour.root.Visible).to.equal(true)
			expect(#shown).to.equal(1)
			expect(shown[1][1]).to.equal("menu")
			expect(shown[1][2]).to.equal(1)
			tour:stop()
		end)

		it("waits again when the target goes away", function()
			local menu = button("menu")
			local tour = Tour.new(app, { id = "first", steps = steps() })
			tour:start()
			frame()
			menu.Instance.Visible = false
			frame()
			expect(tour.waiting()).to.equal(true)
			expect(tour.root.Visible).to.equal(false)
			tour:stop()
		end)

		it("advances when the target is pressed, a silenced one too", function()
			local menu = button("menu", nil, { sound = false })
			local join = button("join", UDim2.fromOffset(100, 100))
			local done = false
			local tour = Tour.new(app, {
				id = "first",
				steps = steps(),
				onDone = function()
					done = true
				end,
			})
			tour:start()
			frame()
			menu:click()
			expect(tour.index()).to.equal(2)
			join:click()
			expect(done).to.equal(true)
			expect(tour.running()).to.equal(false)
		end)

		it("does not advance when another control is pressed", function()
			button("menu")
			local other = button("other", UDim2.fromOffset(50, 50))
			local tour = Tour.new(app, { id = "first", steps = steps() })
			tour:start()
			frame()
			other:click()
			expect(tour.index()).to.equal(1)
			tour:stop()
		end)

		it("advances on a state test, at once when it already holds", function()
			app.state:set("me.signedUp", false)
			app.state:set("me.clips", { "a" })
			local tour = Tour.new(app, {
				id = "first",
				steps = {
					{ id = "join", text = "Join", waitFor = { state = "me.signedUp", equals = true } },
					{
						id = "fill",
						text = "Fill",
						waitFor = {
							state = "me.clips",
							where = function(clips)
								return #clips > 0
							end,
						},
					},
					{ id = "last", text = "Done?" },
				},
			})
			tour:start()
			expect(tour.index()).to.equal(1)
			app.state:set("me.signedUp", true)
			expect(tour.index()).to.equal(3)
			tour:stop()
		end)

		it("advances on an action or a getter", function()
			app.actions:define("gameplay", { dance = { Enum.KeyCode.G } })
			local Reactive = require(script.Parent.Parent.Core.Reactive)
			local ready = Reactive.ref(false)
			local tour = Tour.new(app, {
				id = "first",
				steps = {
					{ id = "dance", text = "Press G", waitFor = { action = "dance" } },
					{
						id = "ready",
						text = "Ready?",
						waitFor = {
							when = function()
								return ready()
							end,
						},
					},
					{ id = "last", text = "Done?" },
				},
			})
			tour:start()
			app.actions:_press("dance")
			expect(tour.index()).to.equal(2)
			ready(true)
			expect(tour.index()).to.equal(3)
			tour:stop()
		end)

		it("a step with no target waits for NEXT in a centred callout", function()
			local tour = Tour.new(app, {
				id = "first",
				steps = { { id = "hi", text = "Hey, I'm Lucy!" }, { id = "bye", text = "Bye" } },
			})
			tour:start()
			frame()
			expect(tour.waiting()).to.equal(false)
			expect(tour.next.Instance.Visible).to.equal(true)
			expect(tour.text.Text).to.equal("Hey, I'm Lucy!")
			tour.next:click()
			expect(tour.index()).to.equal(2)
			tour:stop()
		end)

		it("hides NEXT on a step that waits for something else", function()
			button("menu")
			local tour = Tour.new(app, { id = "first", steps = steps() })
			tour:start()
			frame()
			expect(tour.next.Instance.Visible).to.equal(false)
			tour:stop()
		end)

		it("runs one tour at a time", function()
			button("menu")
			local first = Tour.new(app, { id = "first", steps = steps() })
			local second = Tour.new(app, { id = "second", steps = steps() })
			first:start()
			second:start()
			expect(first.running()).to.equal(false)
			expect(second.running()).to.equal(true)
			expect(app.state:get("tour").id).to.equal("second")
			second:stop()
		end)

		it("rejects a step with neither text nor title", function()
			expect(function()
				Tour.new(app, { id = "first", steps = { { id = "x" } } })
			end).to.throw()
		end)
	end)

	describe("quiet", function()
		it("is quiet while it runs, allowing the tour channel", function()
			button("menu")
			local tour = Tour.new(app, { id = "first", steps = steps() })
			tour:start()
			expect(app.quiet:active()).to.equal(true)
			expect(app.quiet:allows("tour")).to.equal(true)
			expect(app.quiet:allows("rewards")).to.equal(false)
			tour:stop()
			expect(app.quiet:active()).to.equal(false)
		end)

		it("can run without quiet", function()
			local tour = Tour.new(app, { id = "first", steps = steps(), quiet = false })
			tour:start()
			expect(app.quiet:active()).to.equal(false)
			tour:stop()
		end)
	end)

	describe("the cut-out", function()
		local function rect(object: GuiObject): (Vector2, Vector2)
			return object.AbsolutePosition, object.AbsolutePosition + object.AbsoluteSize
		end

		local function near(a: number, b: number): boolean
			return math.abs(a - b) <= 1
		end

		it("blocks everything but the target, with pad", function()
			local menu = button("menu", UDim2.fromOffset(400, 300))
			local tour = Tour.new(
				app,
				{ id = "first", steps = { { id = "menu", target = "menu", text = "Hi", pad = 8 } } }
			)
			tour:start()
			frame()
			frame()
			local min, max = rect(menu.Instance)
			local pad = 8 * Scroll.scaleOf(tour.root)
			local top, bottom = tour.blockers.top, tour.blockers.bottom
			local left, right = tour.blockers.left, tour.blockers.right
			for _, blocker in { top, bottom, left, right } do
				expect(blocker:IsA("GuiButton")).to.equal(true)
				expect(blocker.Visible).to.equal(true)
			end
			local _, topMax = rect(top)
			local bottomMin = rect(bottom)
			local _, leftMax = rect(left)
			local rightMin = rect(right)
			expect(near(topMax.Y, min.Y - pad)).to.equal(true)
			expect(near(bottomMin.Y, max.Y + pad)).to.equal(true)
			expect(near(leftMax.X, min.X - pad)).to.equal(true)
			expect(near(rightMin.X, max.X + pad)).to.equal(true)
			tour:stop()
		end)

		it("follows the target when it moves", function()
			local menu = button("menu", UDim2.fromOffset(400, 300))
			local tour =
				Tour.new(app, { id = "first", steps = { { id = "menu", target = "menu", text = "Hi" } } })
			tour:start()
			frame()
			menu.Instance.Position = UDim2.fromOffset(200, 150)
			frame()
			frame()
			local min = rect(menu.Instance)
			local _, topMax = rect(tour.blockers.top)
			expect(near(topMax.Y, min.Y - Tour.defaults.pad * Scroll.scaleOf(tour.root))).to.equal(true)
			tour:stop()
		end)

		it("is dimmed, or clear with scrim = false", function()
			button("menu")
			local tour = Tour.new(app, {
				id = "first",
				steps = {
					{ id = "a", target = "menu", text = "Hi", waitFor = "next" },
					{ id = "b", target = "menu", text = "Hi", scrim = false },
				},
			})
			tour:start()
			frame()
			expect(tour.blockers.top:HasTag("ui-tour-scrim")).to.equal(true)
			tour:advance()
			frame()
			expect(tour.blockers.top:HasTag("ui-tour-scrim")).to.equal(false)
			expect(tour.blockers.top.Visible).to.equal(true)
			tour:stop()
		end)

		it("places the callout on the side asked, clear of the target", function()
			local menu = button("menu", UDim2.fromOffset(400, 400))
			local tour = Tour.new(app, {
				id = "first",
				steps = { { id = "menu", target = "menu", text = "Open the menu", side = "top" } },
			})
			tour:start()
			frame()
			frame()
			local min = rect(menu.Instance)
			local _, calloutMax = rect(tour.callout)
			expect(calloutMax.Y <= min.Y).to.equal(true)
			tour:stop()
		end)
	end)

	describe("focus", function()
		it("moves focus to the target and keeps it there", function()
			local menu = button("menu")
			local other = button("other", UDim2.fromOffset(50, 50))
			app.input:setMode("gamepad")
			local tour = Tour.new(app, { id = "first", steps = steps() })
			tour:start()
			frame()
			expect(app.input:focused()).to.equal(menu.Instance)
			app.input:focus(other.Instance)
			frame()
			expect(app.input:focused()).to.equal(menu.Instance)
			tour:stop()
		end)
	end)

	describe("back asks to skip", function()
		it("opens a confirm, hiding the tour layer; keep going carries on", function()
			button("menu")
			local skipped = false
			local tour = Tour.new(app, {
				id = "first",
				steps = steps(),
				onSkip = function()
					skipped = true
				end,
			})
			tour:start()
			frame()
			expect(app.input:back()).to.equal(true)
			expect(tour.confirming()).to.equal(true)
			expect(tour.root.Visible).to.equal(false)
			tour.confirm.actions[1]:click() -- KEEP GOING
			expect(tour.confirming()).to.equal(false)
			expect(tour.running()).to.equal(true)
			expect(skipped).to.equal(false)
			tour:stop()
		end)

		it("skips from the confirm", function()
			button("menu")
			local skipped = false
			local tour = Tour.new(app, {
				id = "first",
				steps = steps(),
				onSkip = function()
					skipped = true
				end,
			})
			tour:start()
			frame()
			app.input:back()
			tour.confirm.actions[2]:click() -- SKIP
			expect(skipped).to.equal(true)
			expect(tour.running()).to.equal(false)
		end)

		it("skips from the callout's SKIP", function()
			button("menu")
			local skipped = false
			local tour = Tour.new(app, {
				id = "first",
				steps = steps(),
				onSkip = function()
					skipped = true
				end,
			})
			tour:start()
			frame()
			tour.skipButton:click()
			expect(skipped).to.equal(true)
		end)

		it("swallows back when it cannot be skipped", function()
			button("menu")
			local tour = Tour.new(app, { id = "first", steps = steps(), skippable = false })
			tour:start()
			frame()
			expect(app.input:back()).to.equal(true)
			expect(tour.confirming()).to.equal(false)
			expect(tour.skipButton.Instance.Visible).to.equal(false)
			tour:stop()
		end)
	end)

	describe("progress", function()
		it("saves the step and how it finished", function()
			local menu = button("menu")
			local join = button("join", UDim2.fromOffset(100, 100))
			local tour = Tour.new(app, { id = "first", steps = steps(), progress = "save.tour" })
			tour:start()
			frame()
			expect(app.state:get("save.tour").step).to.equal(1)
			menu:click()
			expect(app.state:get("save.tour").step).to.equal(2)
			join:click()
			expect(app.state:get("save.tour").finished).to.equal("done")
		end)

		it("resumes at the saved step", function()
			app.state:set("save.tour", { step = 2 })
			local tour = Tour.new(app, { id = "first", steps = steps(), progress = "save.tour" })
			expect(tour:start()).to.equal(true)
			expect(tour.index()).to.equal(2)
			tour:stop()
		end)

		it("does not start a finished tour unless asked to replay", function()
			app.state:set("save.tour", { finished = "skipped" })
			local tour = Tour.new(app, { id = "first", steps = steps(), progress = "save.tour" })
			expect(tour:start()).to.equal(false)
			expect(tour.running()).to.equal(false)
			expect(tour:start(1)).to.equal(true)
			expect(tour.index()).to.equal(1)
			tour:stop()
		end)

		it("records a skip", function()
			local tour = Tour.new(app, { id = "first", steps = steps(), progress = "save.tour" })
			tour:start()
			tour:skip()
			expect(app.state:get("save.tour").finished).to.equal("skipped")
		end)
	end)
end
