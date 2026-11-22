return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Harness = require(script.Parent.Parent.Testing.Harness)

	describe("useHasVisibleChild", function()
		-- Visible and child signals may be deferred: wait for each change
		local function becomes(shown: () -> boolean, value: boolean): boolean
			return Harness.waitFor(function()
				return shown() == value
			end)
		end

		it("needs an owner", function()
			expect(function()
				Composables.useHasVisibleChild(Instance.new("Frame"))
			end).to.throw()
		end)

		it("is true while any GUI child is visible, following Visible, adds and removes", function()
			local parent = Instance.new("Frame")
			Instance.new("UIListLayout").Parent = parent -- not a GUI object: never counts
			local scope = Reactive.effectScope(true)
			local shown = scope:run(function()
				return Composables.useHasVisibleChild(parent)
			end)
			expect(shown()).to.equal(false)
			local a = Instance.new("Frame")
			a.Visible = false
			a.Parent = parent
			task.wait()
			expect(shown()).to.equal(false)
			a.Visible = true
			expect(becomes(shown, true)).to.equal(true)
			local b = Instance.new("Frame")
			b.Parent = parent
			a.Visible = false
			task.wait()
			expect(shown()).to.equal(true)
			b:Destroy()
			expect(becomes(shown, false)).to.equal(true)
			scope:stop()
			a.Visible = true
			task.wait()
			expect(shown()).to.equal(false) -- stopped with its owner
		end)

		it("follows a target given as a ref", function()
			local target = Reactive.ref(nil :: Frame?)
			local scope = Reactive.effectScope(true)
			local shown = scope:run(function()
				return Composables.useHasVisibleChild(target)
			end)
			expect(shown()).to.equal(false)
			local parent = Instance.new("Frame")
			Instance.new("Frame").Parent = parent
			target(parent)
			expect(shown()).to.equal(true)
			scope:stop()
		end)
	end)
end
