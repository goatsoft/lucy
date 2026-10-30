--!strict
--[[
	Icon: a small picture that takes the theme's colours, by name or asset id.

		Lucy.Icon.register(require(ReplicatedStorage.Shared.Icons)) -- once, at start
		Icon.new({
			icon = "lucide:heart",    -- a registered name, an asset id or a url
			size = "md",              -- sm | md | lg, or pixels; larger on TV
			variant = "default",      -- default | muted | primary | destructive | success | warning | info
			Parent = button,
		})

	A game registers its own icons: a map of name to
		{ image = 123 | "rbxassetid://...", rect = { x, y, width, height }?, tint = false? }
	`rect` picks a cell of a sprite sheet; `tint = false` keeps an icon's own
	colours (logos, emoji). Icon.register returns a function that removes those
	names again. An unknown name fails the mount.

	Lucy's own components draw a few slots, which Lucy fills from its own sheet
	(Core/IconSheet): lucy:close, lucy:check, lucy:chevron-down / up / left /
	right, lucy:minus and lucy:plus. Register a slot's name to change it
	everywhere; unregistering puts Lucy's back.

	State keys: icon, size, variant, visible.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)
local IconSheet = require(script.Parent.Parent.Core.IconSheet)
local Image = require(script.Parent.Image)

local Icon = {}

Icon.variants = { "default", "muted", "primary", "destructive", "success", "warning", "info" }
Icon.sizes = { sm = 16, md = 20, lg = 24 }
-- Sizes grow with density, like the type scale.
Icon.scale = { default = 1, touch = 1, tv = 1.25 }

local COLOURS = {
	muted = "$MutedForeground",
	primary = "$Primary",
	destructive = "$Destructive",
	success = "$Success",
	warning = "$Warning",
	info = "$Info",
}

local rules: { Component.Rule } = {
	{
		selector = ".ui-icon",
		priority = 0,
		properties = { BackgroundTransparency = 1, BorderSizePixel = 0, ImageColor3 = "$Foreground" },
	},
	{ selector = ".ui-icon-untinted", priority = 20, properties = { ImageColor3 = "$White" } },
}
for variant, colour in COLOURS do
	table.insert(rules, {
		selector = `.ui-icon-variant-{variant}`,
		priority = 10,
		properties = { ImageColor3 = colour },
	})
end
Icon.rules = rules

export type Entry = { image: number | string, rect: { number }?, tint: boolean? }
export type Resolved = { image: string, offset: Vector2, size: Vector2, tint: boolean }

-- name -> resolved entry; the newest registration of a name wins.
local registry: { [string]: Resolved } = {}

local function resolveEntry(name: string, entry: Entry): Resolved
	local url = Image.url(entry.image)
	if url == "" then
		error(`[Lucy] icon "{name}" has no image`, 3)
	end
	local rect = entry.rect
	return {
		image = url,
		offset = if rect then Vector2.new(rect[1], rect[2]) else Vector2.zero,
		size = if rect then Vector2.new(rect[3], rect[4]) else Vector2.zero,
		tint = entry.tint ~= false,
	}
end

-- Lucy's slots and the sheet icon that fills each by default.
local slots: { [string]: string } = {
	["lucy:close"] = "lucide:x",
	["lucy:check"] = "lucide:check",
	["lucy:chevron-down"] = "lucide:chevron-down",
	["lucy:chevron-up"] = "lucide:chevron-up",
	["lucy:chevron-left"] = "lucide:chevron-left",
	["lucy:chevron-right"] = "lucide:chevron-right",
	["lucy:minus"] = "lucide:minus",
	["lucy:plus"] = "lucide:plus",
}

Icon.slots = slots

-- What a slot shows when no game has registered its name.
local defaults: { [string]: Resolved } = {}
for slot, source in slots do
	defaults[slot] = resolveEntry(slot, (IconSheet :: any)[source])
end

-- Adds named icons. Returns a function that removes exactly these (if not replaced since).
function Icon.register(map: { [string]: Entry }): () -> ()
	local added: { [string]: Resolved } = {}
	for name, entry in map do
		local resolved = resolveEntry(name, entry)
		registry[name] = resolved
		added[name] = resolved
	end
	return function()
		for name, resolved in added do
			if registry[name] == resolved then
				registry[name] = nil
			end
		end
		table.clear(added)
	end
end

function Icon.has(name: string): boolean
	return registry[name] ~= nil or defaults[name] ~= nil
end

-- A registered name, an asset id or a url, as what to draw. Nil for an unknown name.
function Icon.resolve(value: any): Resolved?
	if type(value) == "string" then
		local entry = registry[value] or defaults[value]
		if entry then
			return entry
		end
		if string.find(value, "://", 1, true) or string.match(value, "^%d+$") then
			return { image = Image.url(value), offset = Vector2.zero, size = Vector2.zero, tint = true }
		end
		return nil
	end
	if type(value) == "number" then
		return { image = Image.url(value), offset = Vector2.zero, size = Vector2.zero, tint = true }
	end
	return nil
end

local EMPTY: Resolved = { image = "", offset = Vector2.zero, size = Vector2.zero, tint = true }

local function lookup(value: any): Resolved
	local resolved = Icon.resolve(value)
	if resolved == nil then
		if value == nil or value == "" then
			return EMPTY
		end
		error(`[Lucy] unknown icon "{tostring(value)}" (register it with Lucy.Icon.register)`, 0)
	end
	return resolved
end

local function pixels(size: any): number
	if type(size) == "number" then
		return size
	end
	local px = Icon.sizes[size]
	if px == nil then
		error(`[Lucy] unknown Icon size "{tostring(size)}" (expected sm, md, lg or pixels)`, 0)
	end
	return px
end

local function checkVariant(variant: string)
	if not table.find(Icon.variants, variant) then
		error(`[Lucy] unknown Icon variant "{variant}" (expected {table.concat(Icon.variants, ", ")})`, 0)
	end
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "icon",
	defaults = { icon = "", size = "md", variant = "default", visible = true },
	rules = Icon.rules,
	render = function(h)
		-- Bad values fail the mount; later writes report like any effect.
		lookup(h:get("icon"))
		pixels(h:get("size"))
		checkVariant(h:get("variant"))
		local icon, size, variant = h:ref("icon"), h:ref("size"), h:ref("variant")
		local density = Composables.useDensity(h.app)
		local function current(): Resolved
			return lookup(icon())
		end
		return Element.new("ImageLabel", {
			ScaleType = Enum.ScaleType.Fit,
			Size = function()
				local px = math.round(pixels(size()) * (Icon.scale[density()] or 1))
				return UDim2.fromOffset(px, px)
			end,
			Image = function()
				return current().image
			end,
			ImageRectOffset = function()
				return current().offset
			end,
			ImageRectSize = function()
				return current().size
			end,
			Visible = h:ref("visible"),
			Tags = {
				"ui-icon" :: any,
				function()
					local v = variant()
					checkVariant(v)
					return "ui-icon-variant-" .. v
				end,
				["ui-icon-untinted"] = function()
					return not current().tint
				end,
			},
		})
	end,
}

function Icon.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Icon
