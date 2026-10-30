--[[
	Custom UI with Lucy.new: refs, a computed, a spring and components fed by getters.
	Nothing re-renders; only the bindings that read `count` run again.
]]
return {
	group = "Reactivity",
	description = "A counter built with Lucy.new, a computed and a spring.",
	controls = {
		step = { options = { 1, 5, 10 }, default = 1 },
		goal = { min = 10, max = 100, step = 10, default = 50 },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local c = ctx.controls
		local count = Lucy.ref(0)
		local progress = Lucy.computed(function()
			return math.clamp(count() / c.goal(), 0, 1)
		end)
		local fill = Lucy.spring(progress, 5, 0.7)
		-- Token colours that follow theme switches (app.state "theme" is a reactive path).
		local theme = ctx.app.state:ref("theme")
		local function token(name: string)
			return function()
				theme()
				return ctx.app.theme:resolve(name)
			end
		end
		local track = token("Muted")

		return {
			Lucy.Text.new({
				variant = "h1",
				align = "center",
				text = function()
					return tostring(count())
				end,
			}),
			Lucy.new("Frame")({
				Name = "Track",
				Size = UDim2.new(1, 0, 0, 12),
				BorderSizePixel = 0,
				BackgroundColor3 = track,
				Lucy.new("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				Lucy.new("Frame")({
					Name = "Fill",
					BorderSizePixel = 0,
					Size = function()
						return UDim2.fromScale(fill(), 1)
					end,
					BackgroundColor3 = Lucy.tween(function()
						theme()
						return ctx.app.theme:resolve(if progress() >= 1 then "Emerald500" else "Primary")
					end),
					Lucy.new("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				}),
			}),
			Lucy.Stack.new({
				direction = "horizontal",
				gap = "Space2",
				justify = "center",
				children = {
					Lucy.Button.new({
						text = function()
							return `-{c.step()}`
						end,
						variant = "outline",
						disabled = function()
							return count() <= 0
						end,
						onClick = function()
							count(math.max(0, count() - c.step()))
						end,
					}),
					Lucy.Button.new({
						text = function()
							return `+{c.step()}`
						end,
						onClick = function()
							count(count() + c.step())
						end,
					}),
				},
			}),
			Lucy.Text.new({
				variant = "muted",
				align = "center",
				text = function()
					return if progress() >= 1 then "Goal reached" else `{c.goal() - count()} to go`
				end,
			}),
		}
	end,
}
