local DocIcons = require(script.Parent.Parent.DocIcons)

return {
	group = "Components",
	description = "Floating labels and rich cards attached to controls on hover, focus, press, click or always.",
	width = 480,
	controls = {
		variant = { "default", "inverse", "primary", "secondary", "outline", "destructive", "overlay" },
		size = { "sm", "md", "lg" },
		side = { "top", "bottom", "left", "right" },
		arrow = true,
		border = true,
		open = true,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		Lucy.Icon.register(DocIcons)

		local mainBtn = Lucy.Button.new({
			text = "Buy Emote",
			icon = "lucide-extended:sparkles-filled",
		})
		Lucy.Tooltip.new({
			target = mainBtn,
			text = "<b>100</b> coins in the Emote Shop",
			textProps = { richText = true },
			trigger = "manual",
			open = ctx.controls.open,
			variant = ctx.controls.variant,
			size = ctx.controls.size,
			side = ctx.controls.side,
			arrow = ctx.controls.arrow,
			border = ctx.controls.border,
		})

		local hoverBtn = Lucy.Button.new({
			text = "Hover me",
			variant = "outline",
		})
		Lucy.Tooltip.new({
			target = hoverBtn,
			text = "Neon Nights by DJ Lucy (124 BPM)",
			trigger = "hover",
			side = "bottom",
		})

		local holdBtn = Lucy.Button.new({
			text = "Hold to peek",
			variant = "secondary",
		})
		Lucy.Tooltip.new({
			target = holdBtn,
			trigger = "press",
			side = "bottom",
			content = function()
				return Lucy.Stack.new({
					direction = "horizontal",
					gap = "Space2",
					align = "center",
					children = {
						Lucy.Badge.new({ text = "VIP", variant = "secondary" }),
						Lucy.Text.new({ text = "Unlock at level 15", autoWidth = true }),
					},
				})
			end,
		})

		local variantPills = {}
		for _, v in { "default", "inverse", "primary", "secondary", "outline", "destructive", "overlay" } do
			table.insert(
				variantPills,
				Lucy.Tooltip.new({
					text = v,
					variant = v,
					arrow = ctx.controls.arrow,
					border = ctx.controls.border,
					side = ctx.controls.side,
				})
			)
		end

		local richInline = Lucy.Tooltip.new({
			variant = "inverse",
			side = "bottom",
			content = function()
				return Lucy.Stack.new({
					direction = "horizontal",
					gap = "Space2",
					align = "center",
					children = {
						Lucy.Kbd.new({ keyboard = Enum.KeyCode.G, gamepad = Enum.KeyCode.ButtonX }),
						Lucy.Text.new({ text = "Pick a dance", autoWidth = true }),
						Lucy.Badge.new({ text = "Club Lucy", variant = "secondary" }),
					},
				})
			end,
		})

		return {
			Lucy.Stack.new({
				gap = "Space5",
				align = "center",
				children = {
					mainBtn,
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space3",
						children = { hoverBtn, holdBtn },
					}),
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space2",
						wrap = true,
						justify = "center",
						children = variantPills,
					}),
					richInline,
				},
			}),
		}
	end,
}
