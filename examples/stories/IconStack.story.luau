-- Icons from the Roblox client's own textures, registered for this preview only.
-- A game registers the map its icon build writes instead.
local PREVIEW_ICONS = {
	["preview:emotes"] = { image = "rbxasset://textures/ui/TopBar/emotesOff@2x.png" },
	["preview:chat"] = { image = "rbxasset://textures/ui/TopBar/chatOff@2x.png" },
}

return {
	group = "Components",
	description = "Icons drawn as one. The first stack follows the controls; the last places its layers by hand.",
	width = 420,
	controls = {
		arrange = { "fan", "row", "pile" },
		count = { min = 1, max = 6, step = 1, default = 3 },
		size = { options = { "sm", "md", "lg", "xl" }, default = "xl" },
		variant = { "default", "muted", "primary", "destructive", "success", "warning", "info" },
		cutout = true,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		Lucy.Icon.register(PREVIEW_ICONS)
		return {
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space6",
				align = "center",
				children = {
					Lucy.IconStack.new({
						icon = "preview:emotes",
						arrange = c.arrange,
						count = c.count,
						size = c.size,
						variant = c.variant,
						cutout = c.cutout,
					}),
					Lucy.IconStack.new({
						size = c.size,
						cutout = c.cutout,
						layers = {
							{ icon = "preview:chat", variant = "primary" },
							{ icon = "preview:emotes", x = 0.4, y = 0.35, size = 0.5, variant = "warning" },
						},
					}),
				},
			}),
		}
	end,
}
