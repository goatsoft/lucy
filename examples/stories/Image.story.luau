return {
	group = "Components",
	description = "One picture in each fit. The large one follows the control.",
	width = 520,
	controls = {
		fit = { "cover", "contain", "fill", "tile" },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		-- A square thumbnail in wide boxes, so each fit looks different.
		local picture = "rbxthumb://type=AvatarBust&id=156&w=420&h=420"
		local row = {}
		for _, fit in { "cover", "contain", "fill" } do
			table.insert(
				row,
				Lucy.Stack.new({
					gap = "Space1",
					align = "center",
					children = {
						Lucy.Image.new({
							image = picture,
							fit = fit,
							size = UDim2.fromOffset(120, 72),
							rounded = "md",
						}),
						Lucy.Text.new({ text = fit, variant = "muted", align = "center" }),
					},
					size = UDim2.fromOffset(120, 0),
					automaticSize = Enum.AutomaticSize.Y,
				})
			)
		end
		return {
			Lucy.Stack.new({
				gap = "Space4",
				align = "center",
				children = {
					Lucy.Image.new({
						image = picture,
						fit = c.fit,
						size = UDim2.fromOffset(240, 160),
						rounded = "lg",
					}),
					Lucy.Stack.new({ direction = "horizontal", gap = "Space3", children = row }),
				},
			}),
		}
	end,
}
