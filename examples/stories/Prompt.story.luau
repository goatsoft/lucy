return {
	group = "Components",
	description = "World interaction prompt with key caps, hold progress and nearest-prompt exclusivity.",
	width = 480,
	controls = {
		variant = { "default", "inverse", "primary", "secondary", "outline", "destructive", "overlay" },
		size = { "sm", "md", "lg" },
		input = { "keyboard", "gamepad", "touch" },
		hold = { min = 0, max = 1.5, step = 0.1, default = 0.6 },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		ctx.app.actions:define("booth", {
			interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
			dance = { Enum.KeyCode.G, Enum.KeyCode.ButtonY },
		})

		Lucy.watch(ctx.controls.input, function(mode)
			ctx.app.input:setMode(mode)
		end, { immediate = true })

		local progress = Lucy.ref(0.45)

		local livePrompt = Lucy.Prompt.new({
			action = "interact",
			actionText = "Play a set",
			objectText = "DJ Booth",
			hold = ctx.controls.hold,
			progress = progress,
			variant = ctx.controls.variant,
			size = ctx.controls.size,
			onTrigger = function()
				ctx.app.toast.success("Entered the DJ Booth")
			end,
		})

		local variants = {}
		for _, v in { "default", "inverse", "primary", "overlay" } do
			table.insert(
				variants,
				Lucy.Prompt.new({
					action = "dance",
					actionText = v,
					variant = v,
				})
			)
		end

		local vipPrompt = Lucy.Prompt.new({
			action = "interact",
			actionText = "Change outfit",
			objectText = "Wardrobe Mirror",
			variant = "secondary",
			children = { Lucy.Badge.new({ text = "VIP", variant = "outline" }) },
		})

		local controls = Lucy.Stack.new({
			direction = "horizontal",
			gap = "Space2",
			justify = "center",
			children = {
				Lucy.Button.new({
					text = "Trigger",
					size = "sm",
					onClick = function()
						livePrompt:trigger()
					end,
				}),
				Lucy.Button.new({
					text = "Fill Hold",
					size = "sm",
					variant = "outline",
					onClick = function()
						local nextVal = progress() + 0.25
						if nextVal > 1 then
							nextVal = 0
						end
						progress(nextVal)
					end,
				}),
			},
		})

		return {
			Lucy.Stack.new({
				gap = "Space4",
				align = "center",
				children = {
					livePrompt,
					controls,
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space2",
						wrap = true,
						justify = "center",
						children = variants,
					}),
					vipPrompt,
				},
			}),
		}
	end,
}
