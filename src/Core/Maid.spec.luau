return function()
	local Maid = require(script.Parent.Maid)

	describe("Maid", function()
		it("cleans every kind of task, in reverse order", function()
			local maid = Maid.new()
			local order = {}
			local frame = Instance.new("Frame")
			maid:give(frame)
			maid:give(function()
				table.insert(order, "first")
			end)
			maid:give({
				destroy = function()
					table.insert(order, "second")
				end,
			})
			maid:clean()
			expect(table.concat(order, ",")).to.equal("second,first")
			expect(frame.Parent).to.equal(nil)
			expect(pcall(function()
				frame.Parent = workspace
			end)).to.equal(false) -- destroyed: Parent is locked
			maid:clean()
			expect(#order).to.equal(2)
		end)

		it("keeps a task given during a clean for the next clean", function()
			local maid = Maid.new()
			local ran = {}
			maid:give(function()
				table.insert(ran, "a")
			end)
			maid:give(function()
				table.insert(ran, "b")
				maid:give(function()
					table.insert(ran, "late")
				end)
			end)
			maid:clean()
			expect(table.concat(ran, ",")).to.equal("b,a")
			maid:clean()
			expect(table.concat(ran, ",")).to.equal("b,a,late")
		end)

		it("cleans another maid from inside a cleanup", function()
			local outer, inner = Maid.new(), Maid.new()
			local ran = {}
			inner:give(function()
				table.insert(ran, "inner 1")
			end)
			inner:give(function()
				table.insert(ran, "inner 2")
			end)
			outer:give(function()
				table.insert(ran, "outer 1")
			end)
			outer:give(inner)
			outer:give(function()
				table.insert(ran, "outer 3")
			end)
			outer:clean()
			expect(table.concat(ran, ",")).to.equal("outer 3,inner 2,inner 1,outer 1")
		end)

		it("keeps cleaning after a task errors", function()
			local maid = Maid.new()
			local ran = false
			maid:give(function()
				ran = true
			end)
			maid:give(function()
				error("boom")
			end)
			maid:clean()
			expect(ran).to.equal(true)
		end)

		it("is one table", function()
			local least = math.huge
			for _ = 1, 5 do
				local maids = table.create(1000)
				local before = gcinfo()
				for i = 1, 1000 do
					maids[i] = Maid.new()
				end
				least = math.min(least, gcinfo() - before)
			end
			expect(least < 80).to.equal(true) -- bytes per empty maid (KB over 1,000)
		end)
	end)
end
