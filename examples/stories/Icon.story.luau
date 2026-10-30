-- Icons from the Roblox client's own textures, registered for this preview only.
-- A game registers the map its icon build writes instead.
local PREVIEW_ICONS = {
	["preview:chat"] = { image = "rbxasset://textures/ui/TopBar/chatOff@2x.png" },
	["preview:close"] = { image = "rbxasset://textures/ui/TopBar/close@2x.png" },
	["preview:emotes"] = { image = "rbxasset://textures/ui/TopBar/emotesOff@2x.png" },
	["preview:logo"] = { image = "rbxasset://textures/ui/TopBar/coloredlogo@2x.png", tint = false },
}

return {
	group = "Components",
	description = "Icons that take the theme's colours. The first row follows the controls.",
	width = 420,
	controls = {
		variant = { "default", "muted", "primary", "destructive", "success", "warning", "info" },
		size = { options = { "sm", "md", "lg" }, default = "lg" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		Lucy.Icon.register(PREVIEW_ICONS)
		local controlled = {}
		for _, name in { "preview:chat", "preview:close", "preview:emotes", "preview:logo" } do
			table.insert(controlled, Lucy.Icon.new({ icon = name, variant = c.variant, size = c.size }))
		end
		local colours = {}
		for _, variant in { "default", "muted", "primary", "destructive", "success", "warning", "info" } do
			table.insert(colours, Lucy.Icon.new({ icon = "preview:emotes", variant = variant, size = "lg" }))
		end
		return {
			Lucy.Stack.new({
				gap = "Space4",
				align = "center",
				children = {
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space4",
						align = "center",
						children = controlled,
					}),
					Lucy.Stack.new({
						direction = "horizontal",
						gap = "Space3",
						align = "center",
						children = colours,
					}),
				},
			}),
		}
	end,
}
