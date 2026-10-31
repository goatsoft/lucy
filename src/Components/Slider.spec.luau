return function()
	local Slider = require(script.Parent.Slider)
	local Composables = require(script.Parent.Parent.Composables)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Reactive = require(script.Parent.Parent.Core.Reactive)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({ theme = "light" })
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	-- A point on the track at `fraction` of its length (from the left, or from the
	-- bottom when vertical), in screen pixels.
	local function at(slider, fraction: number): Vector2
		local track = slider.track
		local pos, size = track.AbsolutePosition, track.AbsoluteSize
		if slider:get("orientation") == "vertical" then
			return Vector2.new(pos.X + size.X / 2, pos.Y + size.Y * (1 - fraction))
		end
		return Vector2.new(pos.X + size.X * fraction, pos.Y + size.Y / 2)
	end

	describe("snap", function()
		it("rounds to the nearest step from min and clamps", function()
			expect(Slider.snap(47, 0, 100, 5)).to.equal(45)
			expect(Slider.snap(48, 0, 100, 5)).to.equal(50)
			expect(Slider.snap(-3, 0, 100, 1)).to.equal(0)
			expect(Slider.snap(140, 0, 100, 1)).to.equal(100)
			expect(Slider.snap(7, 2, 20, 4)).to.equal(6)
		end)

		it("keeps decimal steps exact", function()
			expect(Slider.snap(0.3, 0, 1, 0.1)).to.equal(0.3)
			expect(Slider.snap(0.71, 0, 1, 0.05)).to.equal(0.7)
		end)

		it("stays on a step when max is not one", function()
			expect(Slider.snap(10, 0, 10, 3)).to.equal(9)
		end)
	end)

	it("places the fill and thumb by value, and follows a ref both ways", function()
		local volume = Reactive.ref(25)
		local slider = Slider.new({ app = app, Parent = gui, value = volume })
		expect(slider.fill.Size.X.Scale).to.be.near(0.25, 0.0001)
		expect(slider.thumb.Position.X.Scale).to.be.near(0.25, 0.0001)
		volume(60)
		expect(slider.thumb.Position.X.Scale).to.be.near(0.6, 0.0001)
		slider:setValue(80)
		expect(volume()).to.equal(80)
	end)

	it("sits at min while its bound value is not set yet", function()
		local volume = Reactive.ref(nil)
		local slider = Slider.new({ app = app, Parent = gui, min = 10, value = volume, showValue = true })
		expect(slider.fill.Size.X.Scale).to.be.near(0, 0.0001)
		expect(slider.valueLabel.Text).to.equal("10")
		expect(slider:nudge(1, 0)).to.equal(true)
		expect(volume()).to.equal(11)
		volume(55)
		expect(slider.fill.Size.X.Scale).to.be.near(0.5, 0.0001)
		expect(slider.valueLabel.Text).to.equal("55")
	end)

	it("snaps values written through setValue", function()
		local slider = Slider.new({ app = app, Parent = gui, min = 0, max = 10, step = 2 })
		slider:setValue(5.2)
		expect(slider:get("value")).to.equal(6)
	end)

	it("tags its orientation and size and fails on unknown ones", function()
		local slider = Slider.new({ app = app, Parent = gui, orientation = "vertical", size = "lg" })
		expect(slider.Instance:HasTag("ui-slider-orientation-vertical")).to.equal(true)
		expect(slider.Instance:HasTag("ui-slider-size-lg")).to.equal(true)
		expect(function()
			Slider.new({ app = app, Parent = gui, orientation = "diagonal" })
		end).to.throw()
		expect(function()
			Slider.new({ app = app, Parent = gui, size = "huge" })
		end).to.throw()
	end)

	it("grows the thumb with size and density", function()
		local sm = Slider.new({ app = app, Parent = gui, size = "sm" })
		local lg = Slider.new({ app = app, Parent = gui, size = "lg" })
		expect(sm.thumb.Size.X.Offset < lg.thumb.Size.X.Offset).to.equal(true)
		local before = lg.thumb.Size.X.Offset
		app.input:setCaps(Harness.caps.console)
		expect(lg.thumb.Size.X.Offset > before).to.equal(true)
	end)

	it("fills from the bottom when vertical", function()
		local slider = Slider.new({ app = app, Parent = gui, orientation = "vertical", value = 25 })
		expect(slider.fill.Size.Y.Scale).to.be.near(0.25, 0.0001)
		expect(slider.thumb.Position.Y.Scale).to.be.near(0.75, 0.0001)
	end)

	it("drags with a pointer, reporting each change and one commit", function()
		local changes, commits, sounds = {}, {}, {}
		local scope = Reactive.effectScope(true)
		local slider = scope:run(function()
			Composables.useUiSound(app, {
				select = function(_, value)
					table.insert(sounds, value)
				end,
			})
			return Slider.new({
				app = app,
				Parent = gui,
				onValueChange = function(value)
					table.insert(changes, value)
				end,
				onValueCommit = function(value)
					table.insert(commits, value)
				end,
			})
		end)
		task.wait(0.1)
		slider:pointerDown(at(slider, 0.5))
		expect(slider:get("value")).to.equal(50)
		slider:pointerMove(at(slider, 0.8))
		expect(slider:get("value")).to.equal(80)
		expect(#commits).to.equal(0)
		slider:pointerUp()
		expect(changes[#changes]).to.equal(80)
		expect(#commits).to.equal(1)
		expect(commits[1]).to.equal(80)
		expect(#sounds).to.equal(1)
		expect(sounds[1]).to.equal(80)
		scope:stop()
	end)

	it("does not commit a drag that ends where it started", function()
		local commits = 0
		local slider = Slider.new({
			app = app,
			Parent = gui,
			value = 50,
			onValueCommit = function()
				commits += 1
			end,
		})
		task.wait(0.1)
		slider:pointerDown(at(slider, 0.5))
		slider:pointerUp()
		expect(commits).to.equal(0)
	end)

	it("drags upward for more when vertical", function()
		local slider = Slider.new({ app = app, Parent = gui, orientation = "vertical" })
		task.wait(0.1)
		slider:pointerDown(at(slider, 1))
		expect(slider:get("value")).to.equal(100)
		slider:pointerMove(at(slider, 0.3))
		expect(slider:get("value")).to.equal(30)
		slider:pointerUp()
	end)

	it("steps with the arrows of its own axis through the focus, and commits on release", function()
		local commits = {}
		local slider = Slider.new({
			app = app,
			Parent = gui,
			value = 10,
			step = 5,
			onValueCommit = function(value)
				table.insert(commits, value)
			end,
		})
		app.input:focus(slider.Instance)
		expect(app.input:nudge(1, 0)).to.equal(true)
		expect(app.input:nudge(1, 0)).to.equal(true)
		expect(slider:get("value")).to.equal(20)
		expect(app.input:nudge(0, 1)).to.equal(false)
		expect(slider:get("value")).to.equal(20)
		app.input:release()
		expect(#commits).to.equal(1)
		expect(commits[1]).to.equal(20)
		app.input:nudge(-1, 0)
		expect(slider:get("value")).to.equal(15)
	end)

	it("takes up and down when vertical, up for more", function()
		local slider = Slider.new({ app = app, Parent = gui, orientation = "vertical", value = 10 })
		app.input:focus(slider.Instance)
		expect(app.input:nudge(1, 0)).to.equal(false)
		expect(app.input:nudge(0, -1)).to.equal(true)
		expect(slider:get("value")).to.equal(11)
		app.input:nudge(0, 1)
		expect(slider:get("value")).to.equal(10)
	end)

	it("speeds up while an arrow is held", function()
		local slider = Slider.new({ app = app, Parent = gui, value = 0 })
		slider:nudge(1, 0, 1)
		expect(slider:get("value")).to.equal(1)
		slider:nudge(1, 0, 30)
		expect(slider:get("value") > 2).to.equal(true)
	end)

	it("stops the engine moving selection along its own axis", function()
		local h = Slider.new({ app = app, Parent = gui })
		expect(h.Instance.SelectionBehaviorLeft).to.equal(Enum.SelectionBehavior.Stop)
		expect(h.Instance.SelectionBehaviorRight).to.equal(Enum.SelectionBehavior.Stop)
		expect(h.Instance.SelectionBehaviorUp).to.equal(Enum.SelectionBehavior.Escape)
		local v = Slider.new({ app = app, Parent = gui, orientation = "vertical" })
		expect(v.Instance.SelectionBehaviorUp).to.equal(Enum.SelectionBehavior.Stop)
		expect(v.Instance.SelectionBehaviorLeft).to.equal(Enum.SelectionBehavior.Escape)
	end)

	it("ignores the pointer and arrows while disabled", function()
		local slider = Slider.new({ app = app, Parent = gui, value = 40, disabled = true })
		task.wait(0.1)
		expect(slider.Instance.Selectable).to.equal(false)
		slider:pointerDown(at(slider, 0.9))
		slider:pointerUp()
		expect(slider:nudge(1, 0, 1)).to.equal(false)
		expect(slider:get("value")).to.equal(40)
		expect(slider.Instance:HasTag("ui-disabled")).to.equal(true)
	end)

	it("shows the value through format when asked", function()
		local slider = Slider.new({
			app = app,
			Parent = gui,
			value = 30,
			showValue = true,
			format = function(value)
				return `{value}%`
			end,
		})
		expect(slider.valueLabel.Visible).to.equal(true)
		expect(slider.valueLabel.Text).to.equal("30%")
		slider:setValue(45)
		expect(slider.valueLabel.Text).to.equal("45%")
		local plain =
			Slider.new({ app = app, Parent = gui, value = 0.25, step = 0.05, max = 1, showValue = true })
		expect(plain.valueLabel.Text).to.equal("0.25")
		local hidden = Slider.new({ app = app, Parent = gui })
		expect(hidden.valueLabel.Visible).to.equal(false)
	end)

	it("has a solid white thumb", function()
		local slider = Slider.new({ app = app, Parent = gui, value = 40 })
		Harness.flush()
		expect(Harness.colorEq(Harness.styled(slider.thumb, "BackgroundColor3"), app.theme:resolve("White"))).to.equal(
			true
		)
		expect(Harness.styled(slider.thumb, "BackgroundTransparency")).to.be.near(0, 0.001)
	end)

	it("rings the thumb like every other control when focused with a pad or keys", function()
		local slider = Slider.new({ app = app, Parent = gui, value = 40 })
		local halo, ring = slider.halo, slider.ring
		expect(halo.Position).to.equal(slider.thumb.Position)
		-- Room for the ring, drawn inside the halo, all round the thumb.
		local room = slider.thumb.Size.X.Offset + 2 * app.theme:resolve("FocusRing")
		expect(halo.Size.X.Offset >= room).to.equal(true)
		expect(halo.ZIndex < slider.thumb.ZIndex).to.equal(true)
		expect(ring:IsA("UIStroke")).to.equal(true)
		Harness.flush()
		expect(Harness.styled(halo, "BackgroundTransparency")).to.be.near(1, 0.001)
		expect(Harness.styled(ring, "Transparency")).to.be.near(1, 0.001)
		app.input:setMode("gamepad")
		app.input:focus(slider.Instance)
		expect(slider.Instance:HasTag("ui-focus-visible")).to.equal(true)
		Harness.flush()
		-- The same tokens as the base focus ring, so the theme changes both.
		expect(Harness.styled(ring, "Transparency")).to.be.near(0, 0.001)
		expect(Harness.colorEq(Harness.styled(ring, "Color"), app.theme:resolve("Ring"))).to.equal(true)
		expect(Harness.styled(ring, "Thickness")).to.be.near(app.theme:resolve("FocusRing"), 0.001)
		expect(Harness.styled(ring, "BorderStrokePosition")).to.equal(Enum.BorderStrokePosition.Inner)
		slider:setValue(70)
		expect(halo.Position).to.equal(slider.thumb.Position)
	end)

	it("shows the ring while the mouse is over it or dragging", function()
		local slider = Slider.new({ app = app, Parent = gui, value = 40 })
		app.input:setMode("mouse")
		slider:_pointer(true)
		expect(slider.Instance:HasTag("ui-slider-hover")).to.equal(true)
		Harness.flush()
		expect(Harness.styled(slider.ring, "Transparency")).to.be.near(0, 0.001)
		slider:_pointer(false)
		expect(slider.Instance:HasTag("ui-slider-hover")).to.equal(false)
		Harness.flush()
		expect(Harness.styled(slider.ring, "Transparency")).to.be.near(1, 0.001)
		task.wait(0.1)
		slider:pointerDown(at(slider, 0.5))
		expect(slider.Instance:HasTag("ui-slider-hover")).to.equal(true)
		slider:pointerUp()
		expect(slider.Instance:HasTag("ui-slider-hover")).to.equal(false)
	end)

	it("shows no hover ring on touch or while disabled", function()
		local slider = Slider.new({ app = app, Parent = gui })
		app.input:setMode("touch")
		slider:_pointer(true)
		expect(slider.Instance:HasTag("ui-slider-hover")).to.equal(false)
		app.input:setMode("mouse")
		slider:set("disabled", true)
		slider:_pointer(true)
		expect(slider.Instance:HasTag("ui-slider-hover")).to.equal(false)
	end)
end
