return function()
	local Format = require(script.Parent.Format)

	it("groups a number's thousands", function()
		expect(Format.number(0)).to.equal("0")
		expect(Format.number(999)).to.equal("999")
		expect(Format.number(4200)).to.equal("4,200")
		expect(Format.number(1234567)).to.equal("1,234,567")
		expect(Format.number(-1500)).to.equal("-1,500")
	end)

	it("rounds to whole numbers unless asked for decimals", function()
		expect(Format.number(1999.6)).to.equal("2,000")
		expect(Format.number(1234.5678, 2)).to.equal("1,234.57")
		expect(Format.number(0.5, 1)).to.equal("0.5")
	end)

	it("can use another separator", function()
		expect(Format.number(1234567, 0, ".")).to.equal("1.234.567")
	end)
end
