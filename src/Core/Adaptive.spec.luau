return function()
	local Adaptive = require(script.Parent.Adaptive)

	describe("computeScale", function()
		local base = Vector2.new(1280, 720)

		it("is 1 at the base resolution", function()
			expect(Adaptive.computeScale(base, { base = base })).to.equal(1)
		end)

		it("fits to the tighter axis by default", function()
			-- Wide screen: height is the constraint.
			expect(Adaptive.computeScale(Vector2.new(2560, 1080), { base = base })).to.equal(1.5)
			-- Tall screen: width is the constraint.
			expect(Adaptive.computeScale(Vector2.new(640, 1080), { base = base })).to.equal(0.5)
		end)

		it("can follow one axis", function()
			expect(Adaptive.computeScale(Vector2.new(2560, 720), { base = base, mode = "width" })).to.equal(2)
			expect(Adaptive.computeScale(Vector2.new(2560, 720), { base = base, mode = "height" })).to.equal(
				1
			)
		end)

		it("clamps to min and max", function()
			expect(Adaptive.computeScale(Vector2.new(320, 180), { base = base, min = 0.6 })).to.equal(0.6)
			expect(Adaptive.computeScale(Vector2.new(5120, 2880), { base = base, max = 2 })).to.equal(2)
		end)

		it("returns 1 for a zero viewport", function()
			expect(Adaptive.computeScale(Vector2.zero, { base = base })).to.equal(1)
		end)
	end)

	describe("breakpointFor", function()
		it("picks the band a width falls in", function()
			expect(Adaptive.breakpointFor(500)).to.equal("Compact")
			expect(Adaptive.breakpointFor(1000)).to.equal("Regular")
			expect(Adaptive.breakpointFor(1600)).to.equal("Wide")
		end)
	end)

	describe("instances", function()
		it("adds a UIAspectRatioConstraint", function()
			local frame = Instance.new("Frame")
			local constraint = Adaptive.aspect(frame, 16 / 9)
			expect(constraint:IsA("UIAspectRatioConstraint")).to.equal(true)
			expect(constraint.Parent).to.equal(frame)
			expect(math.abs(constraint.AspectRatio - 16 / 9) < 1e-4).to.equal(true)
			frame:Destroy()
		end)

		it("adds a UISizeConstraint", function()
			local frame = Instance.new("Frame")
			local constraint = Adaptive.clamp(frame, Vector2.new(100, 50), Vector2.new(400, 300))
			expect(constraint.MinSize).to.equal(Vector2.new(100, 50))
			expect(constraint.MaxSize).to.equal(Vector2.new(400, 300))
			frame:Destroy()
		end)

		it("attaches a UIScale driven by a viewport source", function()
			local gui = Instance.new("ScreenGui")
			local viewport = Vector2.new(2560, 1440)
			local handle = Adaptive.attach(gui, {
				base = Vector2.new(1280, 720),
				getViewport = function()
					return viewport
				end,
				watch = false,
			})
			expect(handle.scale:IsA("UIScale")).to.equal(true)
			expect(handle.scale.Scale).to.equal(2)
			viewport = Vector2.new(1280, 720)
			handle:refresh()
			expect(handle.scale.Scale).to.equal(1)
			handle:destroy()
			expect(gui:FindFirstChildOfClass("UIScale")).to.equal(nil)
			gui:Destroy()
		end)

		it("scales a gui not yet in the game from the camera, not its placeholder size", function()
			-- An unparented ScreenGui reports a made-up 800x600, and App attaches before parenting
			local camera = workspace.CurrentCamera
			if not camera or camera.ViewportSize.X <= 0 then
				return
			end
			local gui = Instance.new("ScreenGui")
			local options = { base = Vector2.new(1280, 720), min = 0.1, max = 4, watch = false }
			local handle = Adaptive.attach(gui, options)
			local want = Adaptive.computeScale(camera.ViewportSize, options)
			expect(math.abs(handle.scale.Scale - want) < 1e-4).to.equal(true)
			handle:destroy()
			gui:Destroy()
		end)

		it("can be reconfigured with another profile", function()
			local gui = Instance.new("ScreenGui")
			local handle = Adaptive.attach(gui, {
				base = Vector2.new(1280, 720),
				getViewport = function()
					return Vector2.new(960, 540)
				end,
				watch = false,
			})
			expect(handle.scale.Scale).to.equal(0.75)
			local profile = table.clone(Adaptive.profiles.mobile)
			profile.getViewport = handle.options.getViewport
			handle:configure(profile)
			expect(handle.scale.Scale).to.equal(1)
			handle:destroy()
			gui:Destroy()
		end)

		it("shrinks a phone's UI to fit, but not past what stays readable", function()
			local phone = Adaptive.computeScale(Vector2.new(735, 413), Adaptive.profiles.mobile)
			expect(phone).to.be.near(0.765, 0.01)
			local tiny = Adaptive.computeScale(Vector2.new(480, 270), Adaptive.profiles.mobile)
			expect(tiny).to.equal(Adaptive.profiles.mobile.min)
		end)

		it("fits a panel into its room, never growing it, never past min", function()
			expect(Adaptive.fitScale(Vector2.new(200, 400), Vector2.new(1000, 1000))).to.equal(1)
			expect(Adaptive.fitScale(Vector2.new(200, 400), Vector2.new(1000, 300))).to.equal(0.75)
			expect(Adaptive.fitScale(Vector2.new(200, 400), Vector2.new(50, 1000))).to.equal(0.5)
			expect(Adaptive.fitScale(Vector2.new(200, 400), Vector2.new(50, 1000), 0.2)).to.equal(0.25)
			expect(Adaptive.fitScale(Vector2.zero, Vector2.new(10, 10))).to.equal(1)
		end)

		it("never shrinks console UI", function()
			local scale = Adaptive.computeScale(Vector2.new(960, 540), Adaptive.profiles.console)
			expect(scale).to.equal(1)
		end)

		it("creates StyleQuery breakpoints", function()
			local gui = Instance.new("ScreenGui")
			local queries = Adaptive.breakpoints(gui)
			expect(queries.Compact:IsA("StyleQuery")).to.equal(true)
			expect(queries.Regular.Parent).to.equal(gui)
			expect(queries.Wide.Name).to.equal("Wide")
			gui:Destroy()
		end)
	end)
end
