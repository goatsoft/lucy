--[[
	Regenerates src/Core/Palette.luau from Tailwind's theme.css.

		lune run scripts/gen-palette                 -- fetch from GitHub (main)
		lune run scripts/gen-palette path/to/theme.css

	Tailwind v4 declares every colour as oklch(L% C H); "none" hue (greys) becomes 0.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local SOURCE = "https://raw.githubusercontent.com/tailwindlabs/tailwindcss/main/packages/tailwindcss/theme.css"
local OUT = "src/Core/Palette.luau"

local css
if process.args[1] then
	css = fs.readFile(process.args[1])
else
	local response = net.request(SOURCE)
	assert(response.ok, `fetch failed: {response.statusCode}`)
	css = response.body
end

local hues, byHue = {}, {}
for name, shade, l, c, h in string.gmatch(css, "%-%-color%-(%a+)%-(%d+):%s*oklch%(([%d%.]+)%%%s+([%d%.]+)%s+([%w%.]+)%)") do
	if not byHue[name] then
		byHue[name] = {}
		table.insert(hues, name)
	end
	local hue = tonumber(h) or 0
	table.insert(byHue[name], { tonumber(shade), tonumber(l) / 100, tonumber(c), hue })
end
assert(#hues > 0, "no colours found")

local function num(n: number): string
	local s = string.format("%.4g", n)
	return s
end

local out = {
	"--[[",
	"\tTailwind CSS v4 colour palette in OKLCH, generated from",
	"\ttailwindcss/packages/tailwindcss/theme.css (https://tailwindcss.com/docs/colors).",
	"",
	"\tPalette[hue][shade] = { L, C, H }  -- L 0..1, C chroma, H degrees",
	"\tConvert with Oklab.fromOklch(L, C, H). Do not edit: run `lune run scripts/gen-palette`.",
	"]]",
	"",
	"local Palette = {",
}
for _, name in hues do
	table.insert(out, `\t{name} = \{`)
	for _, row in byHue[name] do
		table.insert(out, `\t\t[{row[1]}] = \{ {num(row[2])}, {num(row[3])}, {num(row[4])} \},`)
	end
	table.insert(out, "\t},")
end
table.insert(out, "}")
table.insert(out, "")
local quoted = {}
for _, name in hues do
	table.insert(quoted, `"{name}"`)
end
table.insert(out, `Palette.hues = \{ {table.concat(quoted, ", ")} \}`)
table.insert(out, "Palette.shades = { 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950 }")
table.insert(out, "")
table.insert(out, "return Palette")
table.insert(out, "")

fs.writeFile(OUT, table.concat(out, "\n"))
print(`wrote {OUT}: {#hues} hues`)
