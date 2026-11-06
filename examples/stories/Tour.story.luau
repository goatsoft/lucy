return {
	group = "Components",
	description = "Lucy.Tour over three buttons: press each one as the callout asks, or press back to be asked to skip.",
	controls = {
		side = { "auto", "top", "bottom", "left", "right" },
		scrim = true,
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local app = ctx.app

		local status = Lucy.ref("Press Start tour")
		local tour

		local row = Lucy.Stack.new({
			direction = "horizontal",
			gap = "Space4",
			justify = "center",
			children = {
				Lucy.Button.new({ id = "story-tour-shop", text = "Shop", variant = "outline" }),
				Lucy.Button.new({ id = "story-tour-play", text = "Play" }),
				Lucy.Button.new({ id = "story-tour-crew", text = "Crew", variant = "outline" }),
			},
		})

		local function build()
			if tour then
				tour:destroy()
			end
			tour = Lucy.Tour.new(app, {
				id = "story",
				steps = {
					{ id = "hi", title = "Welcome!", text = "Here is a quick look around." },
					{
						id = "play",
						target = "story-tour-play",
						text = "Press Play to start a round.",
						side = c.side(),
						scrim = c.scrim(),
					},
					{
						id = "shop",
						target = "story-tour-shop",
						text = "The shop sells new looks.",
						side = c.side(),
						scrim = c.scrim(),
					},
					{
						id = "crew",
						target = "story-tour-crew",
						text = "Your crew lives here.",
						side = c.side(),
						scrim = c.scrim(),
					},
				},
				onStep = function(step)
					status(`Step: {step.id}`)
				end,
				onDone = function()
					status("Done")
				end,
				onSkip = function()
					status("Skipped")
				end,
			})
			tour:start()
		end

		Lucy.onCleanup(function()
			if tour then
				tour:destroy()
			end
		end)

		return Lucy.Stack.new({
			direction = "vertical",
			gap = "Space6",
			align = "center",
			children = {
				row,
				Lucy.Text.new({
					text = function()
						return status()
					end,
					variant = "muted",
					align = "center",
				}),
				Lucy.Button.new({ text = "Start tour", variant = "secondary", onClick = build }),
			},
		})
	end,
}
