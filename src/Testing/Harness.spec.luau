return function()
	local Harness = require(script.Parent.Harness)

	describe("allocated", function()
		it("is a round's usual heap growth, after a warm-up round it does not count", function()
			-- A collection step pulls a reading down (below zero, even), a table resize pushes
			-- one up, and the first round warms up: none of them moves the answer
			local readings = { 314, 282, -1466, 282, 3354, 282, -88, 282, 282, 282 }
			local count = 0
			local kb = Harness.allocated(function()
				count += 1
				return readings[count]
			end)
			expect(count).to.equal(10)
			expect(kb).to.equal(282)
		end)

		it("takes how many rounds to count", function()
			local count = 0
			local kb = Harness.allocated(function()
				count += 1
				return count
			end, 3)
			expect(count).to.equal(4)
			expect(kb).to.equal(3) -- rounds 2, 3 and 4 read 2, 3 and 4
		end)
	end)
end
