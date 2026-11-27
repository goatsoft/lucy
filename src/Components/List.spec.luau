return function()
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local List = require(script.Parent.List)
	local Text = require(script.Parent.Text)

	it("renders bulleted and numbered lists with arbitrary slot content", function()
		local app, cleanup = Harness.app({ theme = "light" })
		local parent = Harness.mount(app)

		local bullet = List.new({
			app = app,
			marker = "disc",
			items = {
				"Warm up on the dance floor",
				Text.new({ app = app, text = "Hit a 10x combo", variant = "muted" }),
			},
			Parent = parent,
		})

		local item1 = bullet.Instance:FindFirstChild("Item1")
		local item2 = bullet.Instance:FindFirstChild("Item2")
		expect(item1).to.be.ok()
		expect(item2).to.be.ok()
		expect(item1:FindFirstChild("Marker").Text).to.equal("\226\128\162")

		local clicked = false
		local numbered = List.new({
			app = app,
			marker = "decimal",
			items = {
				{
					id = "first",
					content = "Ask for tips",
					variant = "primary",
					onClick = function()
						clicked = true
					end,
				},
				{
					id = "locked",
					content = "VIP lounge",
					disabled = true,
					onClick = function()
						clicked = false
					end,
				},
			},
			Parent = parent,
		})

		local firstRow = numbered.Instance:FindFirstChild("first")
		local lockedRow = numbered.Instance:FindFirstChild("locked")
		expect(firstRow).to.be.ok()
		expect(firstRow:IsA("TextButton")).to.equal(true)
		expect(firstRow:FindFirstChild("Marker").Text).to.equal("1.")
		expect(lockedRow:FindFirstChild("Marker").Text).to.equal("2.")
		expect(lockedRow.Active).to.equal(false)
		expect(clicked).to.equal(false)

		bullet:destroy()
		numbered:destroy()
		cleanup()
	end)
end
