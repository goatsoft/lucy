--!strict
--[[
	Effect: a little animated picture that celebrates something (a reward, a level up, a prize),
	behind or over it. One component with the plumbing, and effect types that only draw (ADR 0039).

		Effect.new({
			type = "rays",            -- a registered type (built in: rays)
			variant = "primary",      -- primary | warning | success | foreground
			size = UDim2.fromScale(1, 1),
			visible = true,
			Parent = frame,
			-- and the type's own options, e.g. rays: count, spin, width
		})
		effect:play()                 -- plays the opening again (the moment a reward lands)

	The picture fills a square stage, as big as the smaller side of its box and centred in it.
	It plays its opening each time it is shown; a looping type keeps moving after it while
	visible. Nothing runs while hidden, and it stops on destroy. With reduced motion
	(Core/Preferences) the picture is simply there, still.

	State keys: variant, visible. handle.stage is the square stage, handle.content the type's
	picture, handle.running whether it is animating; a type may expose its parts on the handle.

	A type: Effect.register(name, {
		intro = 0.8,           -- seconds the opening takes
		loop = true,           -- keeps running after the opening (ctx.elapsed advances)
		defaults = { ... },    -- the type's options
		rules = { ... },       -- its looks, by $Token
		render = function(ctx) return instance end,
	})
	render builds the picture once and binds it to the context: ctx.intro() seconds into the
	opening (stops at intro), ctx.elapsed() seconds running (loop types only), ctx.variant(),
	ctx.option(name) and ctx.handle.
]]

local Animate = require(script.Parent.Parent.Core.Animate)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local Effect = {}

Effect.variants = { "primary", "warning", "success", "foreground" }

export type Context = {
	handle: any,
	props: { [string]: any },
	intro: () -> number,
	elapsed: () -> number,
	variant: () -> string,
	option: (name: string) -> any,
}

export type Definition = {
	intro: number,
	loop: boolean?,
	defaults: { [string]: any }?,
	rules: { Component.Rule }?,
	render: (ctx: Context) -> Instance,
}

Effect.types = {} :: { [string]: Definition }

-- Adds an effect type (or replaces one of the same name)
function Effect.register(name: string, definition: Definition)
	assert(type(name) == "string" and name ~= "", "[Lucy] an effect type needs a name")
	assert(type(definition.render) == "function", `[Lucy] effect type "{name}" needs a render`)
	Effect.types[name] = definition
end

local rules: { Component.Rule } = {
	{ selector = ".ui-effect", priority = 0, properties = { BackgroundTransparency = 1 } },
}
Effect.rules = rules

local function checkVariant(variant: string)
	if not table.find(Effect.variants, variant) then
		error(`[Lucy] unknown Effect variant "{variant}" (expected {table.concat(Effect.variants, ", ")})`, 0)
	end
end

local function definitionOf(name: any): Definition
	local definition = if type(name) == "string" then Effect.types[name] else nil
	if not definition then
		local known = {}
		for key in Effect.types do
			table.insert(known, key)
		end
		table.sort(known)
		error(`[Lucy] unknown Effect type "{tostring(name)}" (known: {table.concat(known, ", ")})`, 0)
	end
	return definition
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "effect",
	defaults = { variant = "primary", visible = true },
	rules = Effect.rules,
	render = function(h)
		local p: Component.Props = h.props
		local name = p.type
		local definition = definitionOf(name)
		if definition.rules then
			h.app.theme:addRules("effect-" .. name, definition.rules)
		end
		checkVariant(h:get("variant"))
		local variant, visible = h:ref("variant"), h:ref("visible")
		local intro = Reactive.ref(0)
		local elapsed = Reactive.ref(0)
		local length = math.max(tonumber(definition.intro) or 0, 0)
		local defaults = definition.defaults or {}

		local ctx: Context = {
			handle = h,
			props = p,
			intro = function()
				return intro()
			end,
			elapsed = function()
				return elapsed()
			end,
			variant = function()
				local v = variant()
				checkVariant(v)
				return v
			end,
			option = function(key: string): any
				local value = p[key]
				if value == nil then
					return defaults[key]
				end
				return value
			end,
		}
		local content = definition.render(ctx)
		h.content = content

		local stage = Element.new("Frame", {
			Name = "Stage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Element.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
			content,
		})
		h.stage = stage

		-- The one driver: the opening, then (a loop type) running on, while visible
		h.running = false
		local stopDrive: (() -> ())? = nil
		local function halt()
			if stopDrive then
				stopDrive()
				stopDrive = nil
			end
			h.running = false
		end
		local function start()
			halt()
			intro(0)
			if Preferences.reducedMotion() then
				intro(length) -- simply there, still
				return
			end
			h.running = true
			stopDrive = Animate.drive(function(dt: number): boolean
				if intro() < length then
					intro(math.min(intro() + dt, length))
				end
				if definition.loop then
					elapsed(elapsed() + dt)
					return false
				end
				if intro() >= length then
					stopDrive = nil
					h.running = false
					return true
				end
				return false
			end)
		end

		function h.play(_self)
			if visible() then
				start()
			else
				intro(0)
			end
		end

		Reactive.watch(visible, function(shown)
			if shown then
				start()
			else
				halt()
			end
		end, { immediate = true })
		Reactive.onCleanup(halt)

		return Element.new("Frame", {
			Size = p.size or UDim2.fromScale(1, 1),
			Visible = visible,
			Tags = {
				"ui-effect" :: any,
				"ui-effect-" .. name,
				function()
					local v = variant()
					checkVariant(v)
					return "ui-effect-" .. v
				end,
			},
			stage,
		})
	end,
}

function Effect.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

-- Built-in types
Effect.register("rays", require(script.Parent.Effects.Rays))

-- The shared textures (white, shape in the alpha) for effect types to draw with: streak, glow
Effect.textures = require(script.Parent.Effects.Textures)

return Effect
