-- Icons from the Roblox client's own textures, registered for this preview only.
-- A game registers the map its icon build writes instead.
local PREVIEW_ICONS = {
	["preview:chat"] = { image = "rbxasset://textures/ui/TopBar/chatOff@2x.png" },
	["preview:emotes"] = { image = "rbxasset://textures/ui/TopBar/emotesOff@2x.png" },
}

return {
	group = "Components",
	description = "What goes inside a badge, a button and a tab: words, icons and other components, all in the component's colours.",
	width = 460,
	controls = {
		price = "199",
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		Lucy.Icon.register(PREVIEW_ICONS)
		return {
			Lucy.Stack.new({
				gap = "Space4",
				children = {
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space2",
						align = "center",
						children = {
							-- An icon and a number after the button's own text
							Lucy.Button.new({
								text = "UNLOCK",
								disabled = ctx.controls.disabled,
								children = {
									Lucy.Icon.new({ icon = "preview:emotes" }),
									Lucy.Text.new({ text = ctx.controls.price, autoWidth = true }),
								},
							}),
							Lucy.Button.new({
								variant = "outline",
								disabled = ctx.controls.disabled,
								children = { "Crew", Lucy.Badge.new({ text = "5", variant = "secondary" }) },
							}),
							-- A badge with only an icon, and one with an icon and words
							Lucy.Badge.new({ icon = "preview:chat", variant = "secondary" }),
							Lucy.Badge.new({
								children = {
									Lucy.Icon.new({ icon = "preview:emotes" }),
									"On fire",
								},
							}),
						},
					}),
					Lucy.Tabs.new({
						items = {
							{
								value = "moves",
								text = "Moves",
								children = { Lucy.Badge.new({ text = "3" }) },
								content = function()
									return Lucy.Text.new({
										text = "Moonwalk, Robot and Twirl",
										variant = "muted",
									})
								end,
							},
							{
								value = "packs",
								text = "Packs",
								content = function()
									return Lucy.Text.new({
										text = "Club packs and bundles",
										variant = "muted",
									})
								end,
							},
						},
					}),
				},
			}),
		}
	end,
}
