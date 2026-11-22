return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	describe("useSize", function()
		-- Layout lands a frame or more later (more under load): wait for it, up to a second
		local function settle(check: () -> boolean)
			local waited = 0
			while not check() and waited < 1 do
				waited += task.wait()
			end
		end
		local function near(a: number, b: number): boolean
			return math.abs(a - b) <= 0.5
		end

		it("follows the object's size in the units it is laid out in, without the scales above it", function()
			if not Harness.laysOutLive() then
				return -- sizes follow live layout only (Harness.laysOutLive)
			end
			local gui = Instance.new("ScreenGui")
			gui.Parent = Harness.guiParent()
			local scale = Instance.new("UIScale")
			scale.Scale = 2
			scale.Parent = gui
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(100, 40)
			frame.Parent = gui
			local scope = Reactive.effectScope(true)
			local size = scope:run(function()
				return Composables.useSize(frame)
			end)
			settle(function()
				return near(size().X, 100)
			end)
			expect(size().X).to.be.near(100, 0.5)
			expect(size().Y).to.be.near(40, 0.5)
			frame.Size = UDim2.fromOffset(60, 30)
			settle(function()
				return near(size().X, 60)
			end)
			expect(size().X).to.be.near(60, 0.5)
			-- A new scale changes the pixels, not the size in layout units
			scale.Scale = 0.5
			settle(function()
				return near(frame.AbsoluteSize.Y, 15)
			end)
			expect(size().Y).to.be.near(30, 0.5)
			scope:stop()
			gui:Destroy()
		end)

		it("leaves out a change of a tiny fraction of a point, as layout makes in a scaled panel", function()
			if not Harness.laysOutLive() then
				return -- sizes follow live layout only (Harness.laysOutLive)
			end
			local gui = Instance.new("ScreenGui")
			gui.Parent = Harness.guiParent()
			local room = Instance.new("Frame")
			room.Size = UDim2.fromOffset(300, 100)
			room.Parent = gui
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0.5, 0, 0, 40)
			frame.Parent = room
			local scope = Reactive.effectScope(true)
			local size = scope:run(function()
				return Composables.useSize(frame)
			end)
			settle(function()
				return near(size().X, 150)
			end)
			local changes = 0
			scope:run(function()
				Reactive.watch(size, function()
					changes += 1
				end)
			end)
			-- A few thousandths of a point: the object did change, but not in any way a layout
			-- that reads its size should follow (a scaled panel's layout makes such changes back
			-- and forth as it settles)
			local before = frame.AbsoluteSize.X
			frame.Size = UDim2.new(0.50001, 0, 0, 40)
			settle(function()
				return frame.AbsoluteSize.X ~= before
			end)
			expect(frame.AbsoluteSize.X).never.to.equal(before)
			expect(changes).to.equal(0)
			-- A real change still comes through
			frame.Size = UDim2.new(0.6, 0, 0, 40)
			settle(function()
				return near(size().X, 180)
			end)
			expect(size().X).to.be.near(180, 0.5)
			expect(changes).to.equal(1)
			scope:stop()
			gui:Destroy()
		end)

		it("is zero with no object, and follows a ref to one", function()
			local target = Reactive.ref(nil :: Frame?)
			local scope = Reactive.effectScope(true)
			local size = scope:run(function()
				return Composables.useSize(target)
			end)
			expect(size()).to.equal(Vector2.zero)
			if not Harness.laysOutLive() then
				scope:stop()
				return -- following the object's size needs live layout (Harness.laysOutLive)
			end
			local gui = Instance.new("ScreenGui")
			gui.Parent = Harness.guiParent()
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(80, 20)
			frame.Parent = gui
			target(frame)
			settle(function()
				return near(size().X, 80)
			end)
			expect(size().X).to.be.near(80, 0.5)
			scope:stop()
			gui:Destroy()
		end)
	end)
end
