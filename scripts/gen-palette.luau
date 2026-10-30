--[[
	Regenerates src/Core/Palette.luau from a CSS file of OKLCH colour variables
	(`--color-<hue>-<shade>: oklch(L% C H);`). The upstream source is recorded
	in docs/adr/0010.

		lune run scripts/gen-palette <path-or-url>

	A "none" hue (greys) becomes 0.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local OUT = "src/Core/Palette.luau"

local source = process.args[1]
if not source then
	print("usage: lune run scripts/gen-palette <path-or-url>   (source: see docs/adr/0010)")
	process.exit(1)
end

local css
if string.match(source, "^https?://") then
	local response = net.request(source)
	assert(response.ok, `fetch failed: {response.statusCode}`)
	css = response.body
else
	css = fs.readFile(source)
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
	"\tLucy colour palette in OKLCH. Source: docs/adr/0010.",
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
