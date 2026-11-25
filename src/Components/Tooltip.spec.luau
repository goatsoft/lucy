return function()
	local Badge = require(script.Parent.Badge)
	local Button = require(script.Parent.Button)
	local Harness = require(script.Parent.Parent.Testing.Harness)
	local Kbd = require(script.Parent.Kbd)
	local Reactive = require(script.Parent.Parent.Core.Reactive)
	local Stack = require(script.Parent.Stack)
	local Text = require(script.Parent.Text)
	local Tooltip = require(script.Parent.Tooltip)

	local app, cleanup, gui
	beforeEach(function()
		app, cleanup = Harness.app({
			colors = { sky = "$Sky400" },
		})
		gui = Harness.mount(app)
	end)
	afterEach(function()
		cleanup()
	end)

	local function makeButton()
		return Button.new({
			app = app,
			text = "Dance",
			Parent = gui,
		})
	end

	describe("Tooltip", function()
		it("starts closed on hover and opens and closes with enter, leave, show, hide and toggle", function()
			local btn = makeButton()
			btn.Instance.Position = UDim2.fromOffset(300, 300)
			local changes = {}
			local tip = Tooltip.new({
				app = app,
				id = "danceTip",
				target = btn,
				text = "Pick a dance move",
				delay = 0,
				closeDelay = 0,
				onOpenChange = function(open)
					table.insert(changes, open)
				end,
			})
			expect(tip:get("open")).to.equal(false)
			expect(app.state:get("ui.danceTip.open")).to.equal(false)
			expect(tip.floating.visible()).to.equal(false)

			tip.hover.enter()
			expect(tip:get("open")).to.equal(true)
			expect(tip.floating.visible()).to.equal(true)
			tip.hover.leave()
			expect(tip:get("open")).to.equal(false)

			tip:show()
			expect(tip:get("open")).to.equal(true)
			tip:hide()
			expect(tip:get("open")).to.equal(false)
			tip:toggle()
			expect(tip:get("open")).to.equal(true)
			tip:toggle()
			expect(tip:get("open")).to.equal(false)
			expect(#changes).to.equal(6)
			tip:destroy()
		end)

		it("binds open two ways with a ref", function()
			local btn = makeButton()
			local open = Reactive.ref(false)
			local tip = Tooltip.new({
				app = app,
				target = btn,
				text = "Bound",
				trigger = "manual",
				open = open,
			})
			open(true)
			expect(tip:get("open")).to.equal(true)
			tip:hide()
			expect(open()).to.equal(false)
			tip:destroy()
		end)

		it("supports focus, press/hold, click/toggle, always, proximity and manual triggers", function()
			local btn = makeButton()

			-- focus
			local onFocus = Tooltip.new({ app = app, target = btn, text = "Focus", trigger = "focus" })
			app.input:markFocus(btn.Instance)
			expect(onFocus:get("open")).to.equal(true)
			app.input:markFocus(nil)
			expect(onFocus:get("open")).to.equal(false)
			onFocus:destroy()

			-- press / hold: shows on press, hides on release
			local onPress = Tooltip.new({ app = app, target = btn, text = "Hold", trigger = "press" })
			onPress.press.press()
			expect(onPress:get("open")).to.equal(true)
			onPress.press.release()
			expect(onPress:get("open")).to.equal(false)
			onPress:destroy()

			-- click / toggle: flips on click, dismisses on back or outside press
			local onClick = Tooltip.new({ app = app, target = btn, text = "Click", trigger = "click" })
			onClick.press.press()
			onClick.press.release()
			expect(onClick:get("open")).to.equal(true)
			expect(app.input:back()).to.equal(true)
			expect(onClick:get("open")).to.equal(false)
			onClick.press.press()
			expect(onClick:get("open")).to.equal(true)
			onClick.dismiss.press(Vector2.new(900, 500))
			expect(onClick:get("open")).to.equal(false)
			onClick:destroy()

			-- always: starts open and stays open
			local always = Tooltip.new({ app = app, target = btn, text = "Always", trigger = "always" })
			expect(always:get("open")).to.equal(true)
			expect(always.floating.visible()).to.equal(true)
			always:destroy()

			-- manual: ignores hover/focus
			local manual = Tooltip.new({ app = app, target = btn, text = "Manual", trigger = "manual" })
			app.input:markFocus(btn.Instance)
			expect(manual:get("open")).to.equal(false)
			manual:show()
			expect(manual:get("open")).to.equal(true)
			manual:destroy()
		end)

		it("falls back to focus on gamepad for hover tooltips", function()
			local btn = makeButton()
			app.input:setMode("gamepad")
			local tip = Tooltip.new({ app = app, target = btn, text = "Gamepad hover", delay = 0 })
			app.input:markFocus(btn.Instance)
			expect(tip:get("open")).to.equal(true)
			app.input:markFocus(nil)
			expect(tip:get("open")).to.equal(false)
			tip:destroy()
		end)

		it("supports proximity trigger with a distance in studs and world billboard", function()
			local part = Instance.new("Part")
			part.Position = Vector3.new(0, 0, 0)
			part.Size = Vector3.new(4, 4, 4)
			part.Parent = workspace
			local at = Vector3.new(25, 0, 0)
			local tip = Tooltip.new({
				app = app,
				target = part,
				trigger = "proximity",
				distance = 12,
				origin = function()
					return at
				end,
				text = "DJ Booth",
			})
			expect(tip.floating.world).to.equal(true)
			tip.proximity.check()
			expect(tip:get("open")).to.equal(false)
			at = Vector3.new(10, 0, 0)
			tip.proximity.check()
			expect(tip:get("open")).to.equal(true)
			at = Vector3.new(12.5, 0, 0)
			tip.proximity.check()
			expect(tip:get("open")).to.equal(true)
			at = Vector3.new(15, 0, 0)
			tip.proximity.check()
			expect(tip:get("open")).to.equal(false)
			tip:destroy()
			part:Destroy()
		end)

		it("points the arrow toward the target for every side and hides when arrow = false", function()
			local btn = makeButton()
			btn.Instance.Position = UDim2.fromOffset(500, 300)
			local tip = Tooltip.new({
				app = app,
				target = btn,
				text = "Arrow check",
				trigger = "always",
				side = "top",
				flip = false,
			})
			expect(tip.arrow.Visible).to.equal(true)
			expect(tip.arrowDirection()).to.equal("down")
			tip:set("side", "bottom")
			expect(tip.arrowDirection()).to.equal("up")
			tip:set("side", "left")
			expect(tip.arrowDirection()).to.equal("right")
			tip:set("side", "right")
			expect(tip.arrowDirection()).to.equal("left")
			tip:set("arrow", false)
			expect(tip.arrow.Visible).to.equal(false)
			tip:destroy()
		end)

		it("centres the arrow on the target even inside a scaled screen", function()
			local scale = Instance.new("UIScale")
			scale.Scale = 1.4
			scale.Parent = gui
			local modalScale = Instance.new("UIScale")
			modalScale.Scale = 1.4
			modalScale.Parent = app:portal("modal")

			local btn = Button.new({
				app = app,
				text = "Moonwalk",
				Parent = gui,
			})
			btn.Instance.Position = UDim2.fromOffset(300, 260)
			local tip = Tooltip.new({
				app = app,
				target = btn,
				text = "100 coins in the Emote Shop",
				trigger = "always",
				side = "top",
				flip = false,
			})
			Harness.flush()
			expect(tip.floating.arrowCenter()).to.equal(0)
			expect(tip.arrow.Position).to.equal(UDim2.fromScale(0.5, 1))
			tip:destroy()
			scale:Destroy()
			modalScale:Destroy()
		end)

		it("accepts Floating UI positioning props sideOffset, alignOffset and avoidCollisions", function()
			local btn = makeButton()
			btn.Instance.Position = UDim2.fromOffset(400, 10)
			local tip = Tooltip.new({
				app = app,
				target = btn,
				text = "Fixed top",
				trigger = "always",
				side = "top",
				sideOffset = 14,
				alignOffset = 10,
				avoidCollisions = false,
			})
			expect(tip.side()).to.equal("top")
			expect(tip:get("offset")).to.equal(14)
			expect(tip:get("alignOffset")).to.equal(10)
			tip:destroy()
		end)

		it("accepts placement shorthand like top-start", function()
			local btn = makeButton()
			btn.Instance.Position = UDim2.fromOffset(400, 300)
			local tip = Tooltip.new({
				app = app,
				target = btn,
				text = "Placement",
				trigger = "always",
				placement = "bottom-start",
				flip = false,
			})
			expect(tip:get("side")).to.equal("bottom")
			expect(tip:get("align")).to.equal("start")
			expect(tip.arrowDirection()).to.equal("up")
			tip:destroy()
		end)

		it("styles variants, sizes, border, fill, transparency and custom variants", function()
			local btn = makeButton()
			for _, variant in Tooltip.variants do
				local tip = Tooltip.new({
					app = app,
					target = btn,
					text = variant,
					variant = variant,
					trigger = "always",
				})
				expect(tip.body:HasTag("ui-tooltip-variant-" .. variant)).to.equal(true)
				tip:destroy()
			end

			expect(function()
				Tooltip.new({ app = app, target = btn, text = "Bad", variant = "nope" })
			end).to.throw()
			expect(function()
				Tooltip.new({ app = app, target = btn, text = "Bad", size = "huge" })
			end).to.throw()

			-- Border on/off and fill/transparency overrides
			local custom = Tooltip.new({
				app = app,
				target = btn,
				text = "Custom",
				trigger = "always",
				fill = "$Card",
				border = "$Ring",
				transparency = 0.25,
			})
			Harness.flush()
			expect(
				Harness.colorEq(Harness.styled(custom.body, "BackgroundColor3"), app.theme:resolve("Card"))
			).to.equal(true)
			expect(
				Harness.colorEq(Harness.styled(custom.arrow, "BackgroundColor3"), app.theme:resolve("Card"))
			).to.equal(true)
			expect(Harness.styled(custom.body, "BackgroundTransparency")).to.be.near(0.25, 0.01)
			expect(Harness.styled(custom.arrow, "BackgroundTransparency")).to.be.near(0.25, 0.01)
			expect(Harness.colorEq(Harness.styled(custom.stroke, "Color"), app.theme:resolve("Ring"))).to.equal(
				true
			)
			custom:destroy()

			local borderless = Tooltip.new({
				app = app,
				target = btn,
				text = "Borderless",
				trigger = "always",
				border = false,
			})
			Harness.flush()
			expect(borderless.body:HasTag("ui-tooltip-no-border")).to.equal(true)
			expect(Harness.styled(borderless.stroke, "Thickness")).to.equal(0)
			borderless:destroy()

			-- Named colour on primary variant
			local coloured = Tooltip.new({
				app = app,
				target = btn,
				text = "Sky",
				variant = "primary",
				color = "sky",
				trigger = "always",
			})
			Harness.flush()
			expect(
				Harness.colorEq(Harness.styled(coloured.body, "BackgroundColor3"), app.theme:resolve("Sky"))
			).to.equal(true)
			coloured:destroy()

			-- Registered variant (ADR 0022)
			Tooltip.addVariant("vip", {
				{
					selector = "",
					properties = { BackgroundColor3 = "$Warning", TextColor3 = "$WarningForeground" },
				},
				{ selector = "::UIStroke", properties = { Color = "$Warning" } },
			})
			local vip = Tooltip.new({
				app = app,
				target = btn,
				text = "VIP",
				variant = "vip",
				trigger = "always",
			})
			Harness.flush()
			expect(
				Harness.colorEq(Harness.styled(vip.body, "BackgroundColor3"), app.theme:resolve("Warning"))
			).to.equal(true)
			expect(Harness.colorEq(Harness.styled(vip.stroke, "Color"), app.theme:resolve("Warning"))).to.equal(
				true
			)
			vip:destroy()
		end)

		it("supports all Lucy Text options and any Lucy component inside", function()
			local btn = makeButton()
			local rich = Tooltip.new({
				app = app,
				target = btn,
				text = "<b>100</b> coins",
				textProps = {
					richText = true,
					variant = "small",
					align = "center",
				},
				trigger = "always",
			})
			expect(rich.label).to.be.ok()
			expect((rich.label.Instance :: TextLabel).RichText).to.equal(true)
			expect(rich.label:get("variant")).to.equal("small")
			expect(rich.label:get("align")).to.equal("center")
			rich:destroy()

			-- Custom components inside via content / children
			local card = Tooltip.new({
				app = app,
				target = btn,
				trigger = "always",
				variant = "primary",
				content = function()
					return Stack.new({
						app = app,
						direction = "horizontal",
						gap = "Space2",
						align = "center",
						children = {
							Kbd.new({ app = app, keyboard = Enum.KeyCode.G, gamepad = Enum.KeyCode.ButtonX }),
							Badge.new({ app = app, text = "Dance" }),
						},
					})
				end,
			})
			expect(card.body:FindFirstChild("stack")).to.be.ok()
			expect(card.label.Instance.Visible).to.equal(false)
			card:destroy()
		end)

		it(
			"inherits Tooltip variant on text by default, and lets a different Text variant override it",
			function()
				local btn = makeButton()

				local inherited = Tooltip.new({
					app = app,
					target = btn,
					text = "Inherited",
					variant = "inverse",
					trigger = "always",
				})
				Harness.flush()
				expect(
					Harness.colorEq(
						Harness.styled(inherited.label.Instance, "TextColor3"),
						app.theme:resolve("Background")
					)
				).to.equal(true)

				inherited.label:set("variant", "destructive")
				Harness.flush()
				expect(
					Harness.colorEq(
						Harness.styled(inherited.label.Instance, "TextColor3"),
						app.theme:resolve("Destructive")
					)
				).to.equal(true)
				inherited:destroy()

				local overridden = Tooltip.new({
					app = app,
					target = btn,
					text = "Overridden",
					variant = "inverse",
					textProps = { variant = "muted" },
					trigger = "always",
					children = {
						Text.new({ app = app, text = "Default child" }),
						Text.new({ app = app, text = "Warning child", variant = "warning" }),
					},
				})
				Harness.flush()
				expect(
					Harness.colorEq(
						Harness.styled(overridden.label.Instance, "TextColor3"),
						app.theme:resolve("MutedForeground")
					)
				).to.equal(true)
				local defaultChild = overridden.body:FindFirstChild("text", true) :: TextLabel
				local childrenText = {}
				for _, d in overridden.body:GetDescendants() do
					if d:IsA("TextLabel") and d ~= overridden.label.Instance then
						childrenText[d.Text] = d
					end
				end
				expect(defaultChild).to.be.ok()
				expect(
					Harness.colorEq(
						Harness.styled(childrenText["Default child"], "TextColor3"),
						app.theme:resolve("Background")
					)
				).to.equal(true)
				expect(
					Harness.colorEq(
						Harness.styled(childrenText["Warning child"], "TextColor3"),
						app.theme:resolve("Warning")
					)
				).to.equal(true)
				overridden:destroy()
			end
		)
	end)
end
