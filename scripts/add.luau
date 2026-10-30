--[[
	Lucy component installer.

	Copies components (and what they depend on) into your project as plain source
	you own and can edit. Core is always copied. An init.luau index listing what
	is installed is regenerated each time.

		lune run <lucy>/scripts/add -- button dialog --out src/shared/Lucy
		lune run <lucy>/scripts/add -- --all --out src/shared/Lucy --specs
		lune run <lucy>/scripts/add -- --list

	Options:
		--out <dir>     destination (default: src/shared/Lucy)
		--from <dir>    Lucy checkout (default: $LUCY_HOME, else the current directory)
		--all           every component
		--specs         also copy the *.spec.luau tests
		--overwrite     replace files that already exist (default: keep your edits)
		--dry-run       print what would happen
		--list          list available components
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local function fail(message: string)
	print("error: " .. message)
	process.exit(1)
end

local function join(...: string): string
	local parts = {}
	for _, part in { ... } do
		if part ~= "" then
			table.insert(parts, (string.gsub(part, "/+$", "")))
		end
	end
	return table.concat(parts, "/")
end

local function dirname(path: string): string
	return string.match(path, "^(.*)/[^/]*$") or "."
end

-- Arguments -----------------------------------------------------------------

local args = process.args
local options = { out = "src/shared/Lucy", from = process.env.LUCY_HOME or process.cwd, names = {} }
local i = 1
while i <= #args do
	local arg = args[i]
	if arg == "--out" or arg == "--from" then
		options[string.sub(arg, 3)] = args[i + 1] or fail(`{arg} needs a value`)
		i += 1
	elseif arg == "--all" or arg == "--specs" or arg == "--overwrite" or arg == "--list" then
		options[string.sub(arg, 3)] = true
	elseif arg == "--dry-run" then
		options.dryRun = true
	elseif arg == "--" then
		-- separator from `lune run`
	elseif string.sub(arg, 1, 2) == "--" then
		fail(`unknown option {arg}`)
	else
		table.insert(options.names, string.lower(arg))
	end
	i += 1
end

local registryPath = join(options.from, "registry.json")
if not fs.isFile(registryPath) then
	fail(`no registry.json in {options.from} (pass --from or set LUCY_HOME)`)
end
local registry = serde.decode("json", fs.readFile(registryPath))
local source = join(options.from, "src")

if options.list then
	local names = {}
	for name in registry.components do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		print(string.format("  %-10s %s", name, registry.components[name].description))
	end
	return
end

if options.all then
	for name in registry.components do
		table.insert(options.names, name)
	end
end
if #options.names == 0 then
	fail("name at least one component, or pass --all (see --list)")
end

-- Resolve dependencies --------------------------------------------------------

local selected, order = {}, {}
local function visit(name: string, from: string?)
	local entry = registry.components[name]
	if not entry then
		fail(`unknown component "{name}"` .. (if from then ` (needed by {from})` else ""))
	end
	if selected[name] then
		return
	end
	selected[name] = true
	for _, dependency in entry.dependencies do
		visit(dependency, name)
	end
	table.insert(order, name)
end
for _, name in options.names do
	visit(name)
end

-- Copy -------------------------------------------------------------------------

local copied, kept = 0, 0
local function copy(relative: string)
	local from = join(source, relative)
	local to = join(options.out, relative)
	if not fs.isFile(from) then
		fail(`registry lists missing file {relative}`)
	end
	if fs.isFile(to) and not options.overwrite then
		kept += 1
		return
	end
	if options.dryRun then
		print("  would copy " .. relative)
	else
		fs.writeDir(dirname(to))
		fs.writeFile(to, fs.readFile(from))
	end
	copied += 1
end

for _, file in registry.core.files do
	copy(file)
end
if options.specs then
	for _, file in registry.core.specs do
		copy(file)
	end
end
for _, name in order do
	local module = registry.components[name].module
	copy(`Components/{module}.luau`)
	if options.specs then
		copy(`Components/{module}.spec.luau`)
	end
end

-- Regenerate the index from what is installed (not just this run) ---------------

local function installed(): { string }
	local out = {}
	local dir = join(options.out, "Components")
	if fs.isDir(dir) then
		for _, file in fs.readDir(dir) do
			local module = string.match(file, "^(%w+)%.luau$")
			if module then
				table.insert(out, module)
			end
		end
	end
	if options.dryRun then
		for _, name in order do
			local module = registry.components[name].module
			if not table.find(out, module) then
				table.insert(out, module)
			end
		end
	end
	table.sort(out)
	return out
end

local core = {
	"App",
	"AppState",
	"Theme",
	"Tokens",
	"Oklab",
	"Palette",
	"SceneManager",
	"InputManager",
	"Adaptive",
	"Responsive",
	"Component",
	"Signal",
	"Maid",
}
local lines = {
	"-- Generated by Lucy's scripts/add. Re-run it after adding components; edits here are overwritten.",
	"local Core = script.Core",
	"local Components = script.Components",
	"",
	"return {",
}
for _, module in core do
	table.insert(lines, `\t{module} = require(Core.{module}),`)
end
for _, module in installed() do
	table.insert(lines, `\t{module} = require(Components.{module}),`)
end
table.insert(lines, "}")
table.insert(lines, "")

if options.dryRun then
	print("  would write init.luau")
else
	fs.writeDir(options.out)
	fs.writeFile(join(options.out, "init.luau"), table.concat(lines, "\n"))
end

print(`Lucy: {copied} file(s) copied, {kept} kept (use --overwrite to replace) into {options.out}`)
print("Installed: " .. table.concat(order, ", "))
