--!strict
--[[
	InlineConfirm: asks "Are you sure?" in place. Its content steps aside for the
	question and YES / NO; NO puts the content back, YES answers. For a choice
	that should not cover the screen with a dialog (skipping a tour, clearing a
	routine from a panel).

		local confirm = Lucy.InlineConfirm.new({
			question = "Are you sure?",
			yes = "YES",
			no = "NO",
			yesVariant = "default",    -- a Button variant for YES (destructive for a loss)
			noVariant = "outline",     -- and for NO (make NO the solid one to steer players to it)
			children = { text, footer },  -- the content shown until it asks
			onYes = function(confirm) end,
			onNo = function(confirm) end,
			Parent = panel,
		})
		confirm:ask()      -- swap the content for the question
		confirm:answer(true | false)
		confirm:cancel()   -- put the content back without an answer
		confirm.asking()   -- tracked

	State keys: question, yes, no, yesVariant, noVariant, asking, visible.
	Parts: confirm.content, confirm.prompt, confirm.question, confirm.yes and
	confirm.no (Buttons).

	While it asks, back answers NO. With a gamepad, asking focuses NO, and NO
	gives focus back to whatever had it.
]]

local Button = require(script.Parent.Button)
local Component = require(script.Parent.Parent.Core.Component)
local Element = require(script.Parent.Parent.Core.Element)
local Reactive = require(script.Parent.Parent.Core.Reactive)

local InlineConfirm = {}

InlineConfirm.rules = {
	{
		selector = ".ui-inline-confirm-question",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$Foreground",
			FontFace = "$FontSansSemibold",
			TextSize = "$TextBase",
		},
	},
} :: { Component.Rule }

local spec: Component.Spec = {
	kind = "inline-confirm",
	defaults = {
		question = "Are you sure?",
		yes = "YES",
		no = "NO",
		yesVariant = "default",
		noVariant = "outline",
		asking = false,
		visible = true,
	},
	rules = InlineConfirm.rules,
	render = function(h)
		local p: Component.Props = h.props
		local app = h.app
		local asking = h:ref("asking")
		h.asking = function(): boolean
			return asking() == true
		end

		local content = Element.new("Frame", {
			Name = "Content",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = function()
				return not asking()
			end,
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
		}) :: Frame
		Component.adopt(content, p.children, 1)

		local question = Element.new("TextLabel", {
			Name = "Question",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = h:ref("question"),
			Tags = { "ui-inline-confirm-question" },
			Element.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		}) :: TextLabel

		local prompt = Element.new("Frame", {
			Name = "Prompt",
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = function()
				return asking() == true
			end,
			Element.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			question,
		}) :: Frame

		h.yes = Button.new({
			app = app,
			text = h:ref("yes"),
			variant = h:ref("yesVariant"),
			size = "sm",
			layoutOrder = 2,
			Parent = prompt,
			onClick = function()
				h:answer(true)
			end,
		})
		h.no = Button.new({
			app = app,
			text = h:ref("no"),
			variant = h:ref("noVariant"),
			size = "sm",
			layoutOrder = 3,
			Parent = prompt,
			onClick = function()
				h:answer(false)
			end,
		})
		h.content, h.prompt, h.question = content, prompt, question

		-- Back answers NO while it asks; the handler goes when it stops asking.
		Reactive.watch(asking, function(on)
			if h._dropBack then
				h._dropBack()
				h._dropBack = nil
			end
			if on then
				h._dropBack = app.input:pushBack(function(): boolean?
					h:answer(false)
					return true
				end)
			end
		end, { immediate = true })
		Reactive.onCleanup(function()
			if h._dropBack then
				h._dropBack()
				h._dropBack = nil
			end
		end)

		return Element.new("Frame", {
			Name = "InlineConfirm",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = h:ref("visible"),
			Tags = {
				"ui-inline-confirm" :: any,
				["ui-inline-confirm-asking"] = function()
					return asking() == true
				end,
			},
			Element.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			content,
			prompt,
		})
	end,
}

function InlineConfirm.new(props: { [string]: any }?)
	local handle = Component.mount(spec, props)

	function handle.ask(h)
		if h.destroyed or h:get("asking") then
			return
		end
		local input = h.app.input
		h._opener = input:focused()
		h:set("asking", true)
		if input:isNavigating() then
			task.defer(function()
				if not h.destroyed and h:get("asking") then
					input:focus(h.no.Instance)
				end
			end)
		end
	end

	function handle.cancel(h)
		h._opener = nil
		if not h.destroyed then
			h:set("asking", false)
		end
	end

	function handle.answer(h, yes: boolean)
		if h.destroyed or not h:get("asking") then
			return
		end
		local opener = h._opener
		h._opener = nil
		h:set("asking", false)
		local input = h.app.input
		if yes then
			if h.props.onYes then
				h.props.onYes(h)
			end
		else
			if input:isNavigating() and opener and input:_usable(opener) then
				input:focus(opener)
			end
			if h.props.onNo then
				h.props.onNo(h)
			end
		end
	end
	return handle
end

return InlineConfirm
