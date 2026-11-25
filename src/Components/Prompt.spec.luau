return function()
	local Badge = require(script.Parent.Badge)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Prompt = require(script.Parent.Prompt)
	local Reactive = require(script.Parent.Parent.Core.Reactive)

	local app, cleanup
	beforeEach(function()
		app, cleanup = Harness.app()
		app.actions:define("gameplay", {
			interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
			dance = { Enum.KeyCode.G, Enum.KeyCode.ButtonY },
		})
	end)
	afterEach(function()
		cleanup()
	end)

	local function makePart(pos: Vector3?)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = pos or Vector3.zero
		part.Size = Vector3.new(4, 4, 4)
		part.Parent = workspace
		return part
	end

	describe("Prompt", function()
		it("shows within distance and hides when out of range or disabled", function()
			local booth = makePart(Vector3.zero)
			local playerAt = Vector3.new(25, 0, 0)
			local enabled = Reactive.ref(true)

			local prompt = Prompt.new({
				app = app,
				id = "boothPrompt",
				target = booth,
				action = "interact",
				actionText = "Play a set",
				objectText = "DJ Booth",
				distance = 10,
				enabled = enabled,
				origin = function()
					return playerAt
				end,
			})

			expect(prompt.floating.world).to.equal(true)
			prompt:check()
			expect(prompt.inRange()).to.equal(false)
			expect(prompt.active()).to.equal(false)
			expect(prompt:get("open")).to.equal(false)

			playerAt = Vector3.new(8, 0, 0)
			prompt:check()
			expect(prompt.inRange()).to.equal(true)
			expect(prompt.active()).to.equal(true)
			expect(prompt:get("open")).to.equal(true)
			expect((prompt.actionLabel.Instance :: TextLabel).Text).to.equal("Play a set")
			expect((prompt.objectLabel.Instance :: TextLabel).Text).to.equal("DJ Booth")
			expect(prompt.objectLabel.Instance.Visible).to.equal(true)

			enabled(false)
			expect(prompt.active()).to.equal(false)
			expect(prompt:get("open")).to.equal(false)

			enabled(true)
			expect(prompt.active()).to.equal(true)

			playerAt = Vector3.new(15, 0, 0)
			prompt:check()
			expect(prompt.active()).to.equal(false)

			prompt:destroy()
			booth:Destroy()
		end)

		it("triggers an instant prompt when its action is pressed", function()
			local booth = makePart(Vector3.zero)
			local triggered = 0
			local signalCount = 0
			local prompt = Prompt.new({
				app = app,
				target = booth,
				action = "interact",
				actionText = "Open",
				distance = 10,
				origin = function()
					return Vector3.new(4, 0, 0)
				end,
				onTrigger = function()
					triggered += 1
				end,
			})
			prompt.Triggered:Connect(function()
				signalCount += 1
			end)
			prompt:check()
			expect(prompt.active()).to.equal(true)
			expect(prompt.kbd:get("action")).to.equal("interact")

			app.actions:_press("interact")
			app.actions:_release("interact")
			expect(triggered).to.equal(1)
			expect(signalCount).to.equal(1)

			prompt:destroy()
			booth:Destroy()
		end)

		it("supports hold duration, progress bar, cancel on release and cancel on leaving range", function()
			local booth = makePart(Vector3.zero)
			local playerAt = Vector3.new(4, 0, 0)
			local triggered, began, ended = 0, 0, 0
			local prompt = Prompt.new({
				app = app,
				target = booth,
				action = "interact",
				actionText = "Play a set",
				distance = 10,
				hold = 0.6,
				origin = function()
					return playerAt
				end,
				onHoldBegin = function()
					began += 1
				end,
				onHoldEnd = function()
					ended += 1
				end,
				onTrigger = function()
					triggered += 1
				end,
			})
			prompt:check()

			-- Start hold and release early -> cancels
			app.actions:_press("interact")
			expect(prompt.holding()).to.equal(true)
			expect(began).to.equal(1)
			prompt:stepHold(0.3)
			expect(prompt.progress()).to.be.near(0.5, 0.01)
			expect(prompt.kbd.Instance:HasTag("ui-kbd-circle")).to.equal(true)
			expect(prompt.progressRing.Instance:HasTag("ui-progress-circle")).to.equal(true)
			expect(prompt.progressBar).to.equal(prompt.progressRing)
			expect(prompt.kbd.Instance:IsDescendantOf(prompt.progressRing.Instance)).to.equal(true)
			expect(prompt.progressRing.rightGradient.Rotation).to.be.near(180, 0.01)
			app.actions:_release("interact")
			expect(prompt.holding()).to.equal(false)
			expect(prompt.progress()).to.equal(0)
			expect(ended).to.equal(1)
			expect(triggered).to.equal(0)

			-- Start hold and walk out of range -> cancels
			app.actions:_press("interact")
			expect(prompt.holding()).to.equal(true)
			playerAt = Vector3.new(20, 0, 0)
			prompt:check()
			expect(prompt.holding()).to.equal(false)
			expect(prompt.progress()).to.equal(0)
			expect(triggered).to.equal(0)

			-- Back in range and hold all the way -> triggers
			playerAt = Vector3.new(4, 0, 0)
			prompt:check()
			app.actions:_press("interact")
			prompt:stepHold(0.6)
			expect(triggered).to.equal(1)
			expect(prompt.holding()).to.equal(false)
			expect(prompt.progress()).to.equal(0)

			prompt:destroy()
			booth:Destroy()
		end)

		it("activates only the nearest in-range exclusive prompt per action", function()
			local a = makePart(Vector3.new(0, 0, 0))
			local b = makePart(Vector3.new(10, 0, 0))
			local playerAt = Vector3.new(2, 0, 0)
			local origin = function()
				return playerAt
			end
			local hits = {}
			local first = Prompt.new({
				app = app,
				target = a,
				action = "interact",
				actionText = "Booth A",
				distance = 12,
				origin = origin,
				onTrigger = function()
					table.insert(hits, "a")
				end,
			})
			local second = Prompt.new({
				app = app,
				target = b,
				action = "interact",
				actionText = "Booth B",
				distance = 12,
				origin = origin,
				onTrigger = function()
					table.insert(hits, "b")
				end,
			})

			first:check()
			second:check()
			expect(first.active()).to.equal(true)
			expect(second.active()).to.equal(false)
			app.actions:_press("interact")
			app.actions:_release("interact")
			expect(table.concat(hits, ",")).to.equal("a")

			-- Move closer to B
			playerAt = Vector3.new(8, 0, 0)
			first:check()
			second:check()
			expect(first.active()).to.equal(false)
			expect(second.active()).to.equal(true)
			app.actions:_press("interact")
			app.actions:_release("interact")
			expect(table.concat(hits, ",")).to.equal("a,b")

			first:destroy()
			second:destroy()
			a:Destroy()
			b:Destroy()
		end)

		it("supports variants, sizes, border, fill, transparency and custom content", function()
			local part = makePart(Vector3.zero)
			local prompt = Prompt.new({
				app = app,
				target = part,
				action = "dance",
				actionText = "Dance",
				variant = "primary",
				size = "lg",
				fill = "$Card",
				border = "$Ring",
				transparency = 0.2,
				children = {
					Badge.new({ app = app, text = "VIP" }),
				},
			})
			Harness.flush()
			expect(prompt.body:HasTag("ui-prompt-variant-primary")).to.equal(true)
			expect(prompt.body:HasTag("ui-prompt-size-lg")).to.equal(true)
			expect(
				Harness.colorEq(Harness.styled(prompt.body, "BackgroundColor3"), app.theme:resolve("Card"))
			).to.equal(true)
			expect(Harness.colorEq(Harness.styled(prompt.stroke, "Color"), app.theme:resolve("Ring"))).to.equal(
				true
			)
			expect(Harness.styled(prompt.body, "BackgroundTransparency")).to.be.near(0.2, 0.01)
			expect(prompt.body:FindFirstChild("badge", true)).to.be.ok()
			prompt:destroy()

			Prompt.addVariant("club", {
				{
					selector = "",
					properties = { BackgroundColor3 = "$Warning", TextColor3 = "$WarningForeground" },
				},
				{ selector = "::UIStroke", properties = { Color = "$Warning" } },
			})
			local custom = Prompt.new({
				app = app,
				target = part,
				action = "dance",
				actionText = "VIP",
				variant = "club",
				border = false,
			})
			Harness.flush()
			expect(
				Harness.colorEq(Harness.styled(custom.body, "BackgroundColor3"), app.theme:resolve("Warning"))
			).to.equal(true)
			expect(custom.body:HasTag("ui-prompt-no-border")).to.equal(true)
			expect(Harness.styled(custom.stroke, "Thickness")).to.equal(0)
			custom:destroy()
			part:Destroy()
		end)

		it("restyles a Roblox ProximityPrompt instance", function()
			local part = makePart(Vector3.zero)
			local raw = Instance.new("ProximityPrompt")
			raw.ActionText = "Enter Club"
			raw.ObjectText = "Lobby Door"
			raw.KeyboardKeyCode = Enum.KeyCode.F
			raw.GamepadKeyCode = Enum.KeyCode.ButtonY
			raw.HoldDuration = 0.5
			raw.Parent = part

			local styled, stop = Prompt.restyleOne(app, raw, { variant = "inverse" })
			expect(raw.Style).to.equal(Enum.ProximityPromptStyle.Custom)
			expect(styled:get("actionText")).to.equal("Enter Club")
			expect(styled:get("objectText")).to.equal("Lobby Door")
			expect(styled:get("hold")).to.equal(0.5)
			expect(styled:get("variant")).to.equal("inverse")

			raw.ActionText = "Exit Club"
			task.wait()
			expect(styled:get("actionText")).to.equal("Exit Club")

			stop()
			expect(styled.destroyed).to.equal(true)
			part:Destroy()
		end)
	end)
end
