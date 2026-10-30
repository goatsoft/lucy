return {
	group = "Components",
	description = "A settings menu in sections. Open one, or several with type multiple.",
	width = 440,
	controls = {
		type = { "single", "multiple" },
		variant = { "default", "details" },
		disabled = false,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local function switches(names: { string })
			return function()
				local list = {}
				for i, name in names do
					table.insert(list, Lucy.Switch.new({ label = name, checked = i == 1 }))
				end
				return Lucy.Stack.new({ gap = "Space2", children = list })
			end
		end
		local function build(kind: string)
			return function()
				return Lucy.Accordion.new({
					type = kind,
					value = if kind == "multiple" then { "audio" } else "audio",
					variant = c.variant,
					disabled = c.disabled,
					items = {
						{
							value = "audio",
							text = "Audio",
							content = switches({ "Music", "Footsteps", "Crowd" }),
						},
						{ value = "video", text = "Video", content = switches({ "Shadows", "Bloom" }) },
						{
							value = "controls",
							text = "Controls",
							content = function()
								return Lucy.Slider.new({ value = 50, showValue = true })
							end,
						},
						{ value = "account", text = "Account", disabled = true },
					},
				})
			end
		end
		-- type is fixed at mount, so a new accordion is built when it changes.
		return Lucy.new("Frame")({
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Lucy.show(function()
				return c.type() == "multiple"
			end, build("multiple"), build("single")),
		})
	end,
}
