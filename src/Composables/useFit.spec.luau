return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	describe("useFit", function()
		local function settle(check: () -> boolean)
			local waited = 0
			while not check() and waited < 1 do
				waited += task.wait()
			end
		end
		-- A frame `natural` wide in a room `room` wide with `pad` of padding each side
		local function setup(natural: number, room: number, pad: number?)
			local gui = Instance.new("ScreenGui")
			gui.Parent = Harness.guiParent()
			local holder = Instance.new("Frame")
			holder.Size = UDim2.fromOffset(room, 100)
			holder.Parent = gui
			if pad then
				local padding = Instance.new("UIPadding")
				padding.PaddingLeft = UDim.new(0, pad)
				padding.PaddingRight = UDim.new(0, pad)
				padding.Parent = holder
			end
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(natural, 20)
			frame.Parent = holder
			return gui, frame
		end

		it("scales an object down to the width its parent has, less the parent's padding", function()
			if not Harness.laysOutLive() then
				return -- sizes follow live layout only (Harness.laysOutLive)
			end
			local gui, frame = setup(400, 220, 10)
			local scope = Reactive.effectScope(true)
			local fit = scope:run(function()
				return Composables.useFit(frame, { min = 0.1 })
			end)
			settle(function()
				return math.abs(fit() - 0.5) < 0.01
			end)
			expect(fit()).to.be.near(0.5, 0.01)
			-- It keeps reading the object's own size, not the size its scale leaves it
			local scale = Instance.new("UIScale")
			scale.Scale = fit()
			scale.Parent = frame
			task.wait()
			task.wait()
			expect(fit()).to.be.near(0.5, 0.01)
			scope:stop()
			gui:Destroy()
		end)

		it("holds still once it fits text, inside the room", function()
			if not Harness.laysOutLive() then
				return
			end
			local gui = Instance.new("ScreenGui")
			gui.Parent = Harness.guiParent()
			local holder = Instance.new("Frame")
			holder.Size = UDim2.fromOffset(110, 60)
			holder.Parent = gui
			local label = Instance.new("TextLabel")
			label.Text = "OVERDRIVE"
			label.TextSize = 40
			label.Font = Enum.Font.GothamBold
			label.AutomaticSize = Enum.AutomaticSize.XY
			label.Size = UDim2.fromOffset(0, 0)
			label.Parent = holder
			local scope = Reactive.effectScope(true)
			local fit = scope:run(function()
				local f = Composables.useFit(label, { min = 0.1 })
				local s = Instance.new("UIScale")
				Reactive.watchEffect(function()
					s.Scale = f()
				end)
				s.Parent = label
				return f
			end)
			-- Settle, then watch it for half a second: it must not move, and must stay inside
			local waited = 0
			while waited < 0.5 do
				waited += task.wait()
			end
			local first = fit()
			local low, high = first, first
			waited = 0
			while waited < 0.5 do
				waited += task.wait()
				low, high = math.min(low, fit()), math.max(high, fit())
				expect(label.AbsoluteSize.X <= holder.AbsoluteSize.X + 1).to.equal(true)
			end
			expect(first < 1).to.equal(true)
			expect(high - low < 0.001).to.equal(true)
			scope:stop()
			gui:Destroy()
		end)

		it("is 1 when the object fits, and never goes under min", function()
			if not Harness.laysOutLive() then
				return
			end
			local gui, frame = setup(100, 300)
			local scope = Reactive.effectScope(true)
			local fit = scope:run(function()
				return Composables.useFit(frame)
			end)
			task.wait()
			task.wait()
			expect(fit()).to.equal(1)
			frame.Size = UDim2.fromOffset(3000, 20)
			settle(function()
				return fit() < 1
			end)
			expect(fit()).to.equal(0.6)
			scope:stop()
			gui:Destroy()
		end)
	end)
end
