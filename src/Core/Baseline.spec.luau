return function()
	local Baseline = require(script.Parent.Baseline)
	local Reactive = require(script.Parent.Reactive)

	local function label(size: number, parent: Instance): TextLabel
		local text = Instance.new("TextLabel")
		text.Text = "Hx"
		text.TextSize = size
		text.Parent = parent
		return text
	end
	local function lift(child: Instance): number?
		local padding = child:FindFirstChild(Baseline.paddingName) :: UIPadding?
		return padding and padding.PaddingBottom.Offset
	end

	describe("offsets", function()
		it("lifts each size by its descent's gap to the biggest", function()
			local out = Baseline.offsets({ 40, 18, 40 })
			expect(out[1]).to.equal(0)
			expect(math.abs(out[2] - Baseline.descent * 22) < 1e-6).to.equal(true)
			expect(out[3]).to.equal(0)
		end)

		it("caps sizes at Roblox's biggest text", function()
			local out = Baseline.offsets({ 200, 100 })
			expect(out[1]).to.equal(0)
			expect(out[2]).to.equal(0)
		end)
	end)

	describe("follow", function()
		local row, scope
		beforeEach(function()
			row = Instance.new("Frame")
		end)
		afterEach(function()
			if scope then
				scope:stop()
			end
			row:Destroy()
		end)

		it("lifts the smaller text while active, and stops lifting when not", function()
			local big, small = label(40, row), label(18, row)
			local active = Reactive.ref(true)
			scope = Reactive.effectScope(true)
			scope:run(function()
				Baseline.follow(row, active)
			end)
			expect(lift(big)).to.equal(nil)
			expect(lift(small)).to.equal(math.round(Baseline.descent * 22))
			active(false)
			expect(lift(small)).to.equal(nil)
		end)

		it("follows sizes, hidden children and new children", function()
			local big, small = label(40, row), label(18, row)
			scope = Reactive.effectScope(true)
			scope:run(function()
				Baseline.follow(row, function()
					return true
				end)
			end)
			big.TextSize = 60
			expect(lift(small)).to.equal(math.round(Baseline.descent * 42))
			big.Visible = false
			expect(lift(small)).to.equal(nil)
			-- A Marquee-like child: its text inside a frame
			local holder = Instance.new("Frame")
			label(10, holder)
			holder.Parent = row
			expect(lift(holder)).to.equal(math.round(Baseline.descent * 8))
		end)

		it("leaves a child's own padding alone", function()
			label(40, row)
			local small = label(18, row)
			Instance.new("UIPadding").Parent = small
			scope = Reactive.effectScope(true)
			scope:run(function()
				Baseline.follow(row, function()
					return true
				end)
			end)
			expect(lift(small)).to.equal(nil)
		end)
	end)
end
