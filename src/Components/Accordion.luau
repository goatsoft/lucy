--!strict
--[[
	Accordion: a stack of sections; the player opens the ones they want to see.

		Accordion.new({
			items = {
				{ value = "audio", text = "Audio", content = audioSettings },
				{ value = "video", text = "Video", content = function() return buildVideo() end },
			},
			type = "single",        -- single | multiple
			value = "audio",        -- single: the open section or false; multiple: a list
			variant = "default",    -- default | details (the sections' look)
			disabled = false,
			visible = true,
			onValueChange = function(value, accordion) end,
			Parent = panel,
		})
		accordion:toggle("video")

	Each section is a Collapsible (accordion.sections[value]). With type "single"
	opening a section closes the open one, and pressing the open one closes it, so
	all can be closed. With "multiple" any number stay open and the value lists
	them in item order. `type` is fixed at mount.

	State keys: value, variant, disabled, visible.
	Events: each section reports "toggle" with its open state, for Lucy.useUiSound.
]]

local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Collapsible = require(script.Parent.Collapsible)
local ToggleGroup = require(script.Parent.ToggleGroup)

local Accordion = {}

Accordion.types = { "single", "multiple" }

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "accordion",
	defaults = { value = false, variant = "default", disabled = false, visible = true },
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local multiple = p._accordionMultiple == true
		local items = ToggleGroup.normalize(p.items, "Accordion")
		local disabled = h:ref("disabled")

		-- A list is changed in place, which its key alone does not report, so a
		-- multiple accordion follows a snapshot of the whole list.
		local value: () -> any = h:ref("value")
		if multiple then
			local state = app.state
			local segments = state:_segments(h.path .. ".value")
			value = Reactive.computed(function(): any
				return state:_tracked(segments)
			end)
		end

		local function has(current: any, itemValue: any): boolean
			if multiple then
				return type(current) == "table" and table.find(current, itemValue) ~= nil
			end
			return current == itemValue
		end

		if p.onValueChange then
			Reactive.watch(value, function(new)
				p.onValueChange(new, h)
			end)
		end

		local sections: { [any]: any } = {}
		local children: { any } = { Component.list({}) }
		for index, item in items do
			local itemValue = item.value
			local open = Reactive.computed({
				get = function(): boolean
					return has(value(), itemValue)
				end,
				set = function(on: boolean)
					local current = h:get("value")
					if not multiple then
						if on then
							h:set("value", itemValue)
						elseif current == itemValue then
							h:set("value", false)
						end
						return
					end
					local list = {}
					for _, entry in items do
						local isOn = if entry.value == itemValue then on else has(current, entry.value)
						if isOn then
							table.insert(list, entry.value)
						end
					end
					h:set("value", list)
				end,
			})
			local section = Collapsible.new({
				app = app,
				name = `Section{index}`,
				layoutOrder = index,
				text = item.text,
				content = item.content,
				open = open,
				variant = h:ref("variant"),
				disabled = Reactive.computed(function(): boolean
					return item.disabled or disabled()
				end),
			})
			sections[itemValue] = section
			table.insert(children, section.Instance)
		end
		h.sections = sections

		local props: { [any]: any } = {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			Tags = { "ui-accordion" },
		}
		for _, child in children do
			table.insert(props, child)
		end
		return Element.new("Frame", props)
	end,
}

function Accordion.new(props: { [string]: any }?)
	local given: { [string]: any } = table.clone(props or {})
	local kind = given.type or "single"
	if not table.find(Accordion.types, kind) then
		error(`[Lucy] unknown Accordion type "{kind}" (expected {table.concat(Accordion.types, ", ")})`, 2)
	end
	local multiple = kind == "multiple"
	if multiple and given.value == nil then
		given.value = {}
	end
	given._accordionMultiple = multiple
	local handle = Component.mount(spec, given)

	-- The player pressed the header of the section with this value.
	function handle.toggle(h, itemValue: any)
		local section = h.sections[itemValue]
		if section then
			section:toggle()
		end
	end
	return handle
end

return Accordion
