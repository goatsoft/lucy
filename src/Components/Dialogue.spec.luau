return function()
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local DialogueTree = require(script.Parent.Parent.Core.DialogueTree)
	local Dialogue = require(script.Parent.Dialogue)

	it("renders a DialogueTree runner, shows locked choices, and advances on click", function()
		local app, cleanup = Harness.app({ theme = "light" })
		local parent = Harness.mount(app)
		local bb = DialogueTree.blackboard({ name = "Alex", vip = false })
		local tree: DialogueTree.Tree = {
			id = "spec_chat",
			speaker = "nova",
			entry = "hub",
			nodes = {
				hub = {
					text = "Hey {name}, ready to dance?",
					choices = {
						{ id = "yes", label = "Let's go!", next = "done", variant = "default" },
						{
							id = "vip",
							label = "VIP lounge",
							next = "done",
							when = function(b)
								return b:get("vip") == true
							end,
							locked = "disable",
							lockedReason = "VIP only",
						},
					},
				},
				done = {
					text = "See you on the floor!",
					isEnd = true,
				},
			},
		}

		local runner = DialogueTree.new(tree, bb)
		runner:start()

		local handle = Dialogue.new({
			app = app,
			runner = runner,
			instant = true,
			resolveActor = function()
				return { name = "DJ Nova", role = "Resident DJ" }
			end,
			Parent = parent,
		})

		expect(handle.speaker.Text).to.equal("DJ Nova")
		expect(handle.body.Text).to.equal("Hey Alex, ready to dance?")

		local yesBtn = handle.choices:FindFirstChild("dialogue-choice-yes")
		local vipBtn = handle.choices:FindFirstChild("dialogue-choice-vip")
		expect(yesBtn).to.be.ok()
		expect(vipBtn).to.be.ok()

		-- Choosing the unlocked option advances to the end node
		runner:choose("yes")
		expect(handle.body.Text).to.equal("See you on the floor!")
		local leaveBtn = handle.choices:FindFirstChild("dialogue-continue")
		expect(leaveBtn).to.be.ok()

		runner:close()
		expect(handle.panel.Visible).to.equal(false)

		handle:destroy()
		cleanup()
	end)
end
