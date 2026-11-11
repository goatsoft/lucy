return {
	group = "Components",
	description = "The theme's gradients on cards, top to bottom and left to right.",
	render = function(ctx)
		local Lucy = ctx.Lucy
		local function card(name, rotation)
			local frame = Lucy.new("Frame")({
				Size = UDim2.fromOffset(220, 120),
				Lucy.new("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			})
			Lucy.Gradient.new({ gradient = name, rotation = rotation, Parent = frame })
			Lucy.Stack.new({
				padding = "Space4",
				children = { Lucy.Text.new({ text = `Gradient{name} · {rotation}°`, variant = "small" }) },
				Parent = frame,
			})
			return frame
		end
		return {
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space4",
				children = { card("Surface", 90), card("Primary", 90), card("Primary", 0) },
			}),
		}
	end,
}
