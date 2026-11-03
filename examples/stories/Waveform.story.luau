-- A made-up song: a quiet intro, a build, a drop, a breakdown and a second drop
local function song(count: number): { number }
	local levels = table.create(count, 0)
	for index = 1, count do
		local t = index / count
		local shape = if t < 0.15
			then 0.3
			elseif t < 0.35 then 0.3 + (t - 0.15) * 3
			elseif t < 0.6 then 0.95
			elseif t < 0.72 then 0.45
			else 0.9
		levels[index] =
			math.clamp(shape + math.sin(index * 1.7) * 0.12 + math.sin(index * 0.37) * 0.08, 0.05, 1)
	end
	return levels
end

return {
	group = "Components",
	description = "Columns from levels. Played columns are lit; drag across one to seek.",
	controls = {
		progress = { min = 0, max = 100, step = 5, default = 45 },
	},
	render = function(ctx)
		local Lucy = ctx.Lucy
		local progress = function()
			return ctx.controls.progress() / 100
		end
		local seek = function(fraction: number)
			ctx.controls.progress(math.floor(fraction * 100 + 0.5))
		end
		return {
			Lucy.Text.new({
				text = "dots, a gradient up the height fading out, the unlit dots faint",
				variant = "muted",
			}),
			Lucy.Waveform.new({
				levels = song(72),
				progress = progress,
				variant = "dots",
				cells = 18,
				gradient = { "$Purple500", "$Pink500" },
				track = true,
				fade = 0.6,
				gap = 1,
				height = 110,
				onSeek = seek,
			}),
			Lucy.Text.new({ text = "blocks with peak caps", variant = "muted" }),
			Lucy.Waveform.new({
				levels = song(24),
				progress = progress,
				variant = "blocks",
				cells = 14,
				gradient = { "$Rose500", "$Amber400" },
				peaks = true,
				height = 110,
				onSeek = seek,
			}),
			Lucy.Text.new({ text = "bars, centred, a gradient from the middle out", variant = "muted" }),
			Lucy.Waveform.new({
				levels = song(96),
				progress = progress,
				variant = "bars",
				align = "center",
				gradient = { "$Sky400", "$Purple500" },
				height = 80,
				onSeek = seek,
			}),
			Lucy.Text.new({
				text = "bars, colour along the width from stops (a song's sections)",
				variant = "muted",
			}),
			Lucy.Waveform.new({
				levels = song(96),
				progress = progress,
				variant = "bars",
				stretch = true,
				stops = {
					{ 0.1, "$Zinc400" },
					{ 0.25, "$Sky400" },
					{ 0.4, "$Amber500" },
					{ 0.55, "$Pink500" },
					{ 0.75, "$Purple500" },
					{ 0.95, "$Sky400" },
				},
				height = 64,
				onSeek = seek,
			}),
		}
	end,
}
