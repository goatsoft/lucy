--!strict
--[[
	Kbd: the key to press, for the input the player is using.

		Kbd.new({
			keyboard = Enum.KeyCode.E,      -- a KeyCode or text
			gamepad = Enum.KeyCode.DPadUp,  -- shown as the controller's own picture
			touch = "Hold",                 -- optional; hidden on touch without it
			action = "dance",               -- or: the keys of an action, kept up to date
			variant = "color",              -- color | mono
			Parent = row,
		})

	Keyboard and mouse players see the keyboard key, gamepad players the
	controller's button (the engine's picture for their controller, or text),
	touch players the touch label or nothing. It hides itself when there is no
	key for the current input. With variant "color" (the default) the face
	buttons take their controller's colours (Xbox A green, PlayStation cross
	blue...); "mono" draws every button in the text colour.

	With `action`, the action's keys (app.actions:keys) stand in for keyboard
	and gamepad, and follow a rebind. Define the action first.

	State keys: keyboard, gamepad, touch, action, variant, visible.
	Parts: kbd.text (the label), kbd.glyph (the controller picture).
	Kbd.label(key) and Kbd.glyph(keyCode) are the helpers it uses.
]]

local UserInputService = game:GetService("UserInputService")

local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local Element = require(script.Parent.Parent.Core.Element)

local Kbd = {}

-- Names for keys the engine has no printable text for, and short gamepad names.
Kbd.names = {
	Escape = "Esc",
	Return = "Enter",
	KeypadEnter = "Enter",
	Space = "Space",
	Tab = "Tab",
	Backspace = "Backspace",
	Delete = "Del",
	LeftShift = "Shift",
	RightShift = "Shift",
	LeftControl = "Ctrl",
	RightControl = "Ctrl",
	LeftAlt = "Alt",
	RightAlt = "Alt",
	LeftSuper = "Cmd",
	RightSuper = "Cmd",
	Up = "Up",
	Down = "Down",
	Left = "Left",
	Right = "Right",
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "LS",
	ButtonR3 = "RS",
	ButtonSelect = "View",
	ButtonStart = "Menu",
	DPadUp = "D-Pad Up",
	DPadDown = "D-Pad Down",
	DPadLeft = "D-Pad Left",
	DPadRight = "D-Pad Right",
	MouseLeftButton = "Click",
	MouseRightButton = "Right click",
}

Kbd.variants = { "color", "mono" }

-- Face buttons by controller, and the colour each is printed in.
Kbd.faces = {
	xbox = { ButtonA = "a", ButtonB = "b", ButtonX = "x", ButtonY = "y" },
	playstation = { ButtonA = "cross", ButtonB = "circle", ButtonX = "square", ButtonY = "triangle" },
}
Kbd.faceColours = {
	["xbox-a"] = "$Green500",
	["xbox-b"] = "$Red500",
	["xbox-x"] = "$Blue500",
	["xbox-y"] = "$Amber400",
	["playstation-cross"] = "$Blue400",
	["playstation-circle"] = "$Red500",
	["playstation-square"] = "$Pink400",
	["playstation-triangle"] = "$Emerald400",
}

Kbd.glyphSize = 20
Kbd.scale = { default = 1, touch = 1, tv = 1.25 }

Kbd.rules = {
	{
		selector = ".ui-kbd",
		priority = 0,
		properties = { BackgroundColor3 = "$Muted", BorderSizePixel = 0 },
	},
	{ selector = ".ui-kbd::UICorner", priority = 0, properties = { CornerRadius = "$RadiusSm" } },
	{
		selector = ".ui-kbd::UIPadding",
		priority = 0,
		properties = { PaddingLeft = "$Space1", PaddingRight = "$Space1" },
	},
	-- A controller picture brings its own shape.
	{ selector = ".ui-kbd.ui-kbd-glyph", priority = 10, properties = { BackgroundTransparency = 1 } },
	{
		selector = ".ui-kbd.ui-kbd-glyph::UIPadding",
		priority = 10,
		properties = { PaddingLeft = "$Space0", PaddingRight = "$Space0" },
	},
	{
		selector = ".ui-kbd-text",
		priority = 0,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSansMedium",
			TextSize = "$TextXs",
		},
	},
	-- Controller pictures are one colour, so they take the text colour.
	{
		selector = ".ui-kbd-image",
		priority = 0,
		properties = { BackgroundTransparency = 1, ImageColor3 = "$Foreground" },
	},
} :: { Component.Rule }
-- Above every rule a Button hint adds, so a coloured face stays coloured there.
for face, colour in Kbd.faceColours do
	table.insert(Kbd.rules, {
		selector = `.ui-kbd-face-{face}`,
		priority = 40,
		properties = { ImageColor3 = colour },
	})
end

local function keyCode(value: any): EnumItem?
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		return value
	end
	return nil
end

-- Plain text for a key: the name above, the engine's text for the key on this
-- keyboard layout, or the KeyCode's name. Text passes through; nil gives "".
function Kbd.label(value: any): string
	if type(value) == "string" then
		return value
	end
	local code = keyCode(value)
	if code == nil then
		return ""
	end
	local named = Kbd.names[code.Name]
	if named then
		return named
	end
	local ok, text = pcall(UserInputService.GetStringForKeyCode, UserInputService, code :: any)
	if ok and type(text) == "string" and string.match(text, "%S") then
		return string.upper(text)
	end
	return code.Name
end

-- The engine's picture of a gamepad button for the player's controller, or "".
function Kbd.glyph(value: any): string
	local code = keyCode(value)
	if code == nil or string.sub(code.Name, 1, 6) ~= "Button" and string.sub(code.Name, 1, 4) ~= "DPad" then
		return ""
	end
	local ok, image = pcall(UserInputService.GetImageForKeyCode, UserInputService, code :: any)
	return if ok and type(image) == "string" then image else ""
end

-- The player's controller family, from the engine's own button names and pictures.
function Kbd.platform(): string
	local ok, name = pcall(UserInputService.GetStringForKeyCode, UserInputService, Enum.KeyCode.ButtonA)
	if ok and type(name) == "string" and string.find(name, "Cross", 1, true) then
		return "playstation"
	end
	local image = string.lower(Kbd.glyph(Enum.KeyCode.ButtonA))
	for _, mark in { "playstation", "ps4", "ps5" } do
		if string.find(image, mark, 1, true) then
			return "playstation"
		end
	end
	return "xbox"
end

-- "xbox-a", "playstation-cross"...: the face a button has on a controller, or nil.
function Kbd.face(value: any, platform: string): string?
	local code = keyCode(value)
	local faces = Kbd.faces[platform]
	if code == nil or faces == nil then
		return nil
	end
	local face = faces[code.Name]
	return if face then `{platform}-{face}` else nil
end

local function checkVariant(variant: string)
	if not table.find(Kbd.variants, variant) then
		error(`[Lucy] unknown Kbd variant "{variant}" (expected color or mono)`, 0)
	end
end

-- Built once and shared by every mount (h.props holds each mount's props).
local spec: Component.Spec = {
	kind = "kbd",
	defaults = { keyboard = "", gamepad = "", touch = "", action = "", variant = "color", visible = true },
	rules = Kbd.rules,
	render = function(h)
		checkVariant(h:get("variant"))
		local rawKeyboard, rawGamepad, touch, visible =
			h:ref("keyboard"), h:ref("gamepad"), h:ref("touch"), h:ref("visible")
		local action = h:ref("action")
		-- With an action, its first key for the current input stands in for the
		-- keyboard and gamepad keys (keys() is tracked: input mode and rebinds).
		local function fromAction(raw: () -> any): () -> any
			return function(): any
				local name = action()
				if name ~= "" and name ~= nil then
					return h.app.actions:keys(name)[1] or ""
				end
				return raw()
			end
		end
		local keyboard, gamepad = fromAction(rawKeyboard), fromAction(rawGamepad)
		local variant = h:ref("variant")
		local mode = h.app.state:ref("input.mode")
		local density = Composables.useDensity(h.app)

		-- The key for the current input, and its picture when it has one.
		local function key(): any
			local m = mode()
			if m == "gamepad" then
				return gamepad()
			elseif m == "touch" then
				return touch()
			end
			return keyboard()
		end
		local function image(): string
			return if mode() == "gamepad" then Kbd.glyph(gamepad()) else ""
		end
		local function hasImage(): boolean
			return image() ~= ""
		end

		local text = Element.new("TextLabel", {
			Name = "Key",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Text = function()
				return Kbd.label(key())
			end,
			Visible = function()
				return not hasImage()
			end,
			Tags = { "ui-kbd-text" },
		})
		local glyph = Element.new("ImageLabel", {
			Name = "Glyph",
			Size = function()
				local px = math.round(Kbd.glyphSize * (Kbd.scale[density()] or 1))
				return UDim2.fromOffset(px, px)
			end,
			ScaleType = Enum.ScaleType.Fit,
			Image = image,
			Visible = hasImage,
			Tags = {
				"ui-kbd-image" :: any,
				function(): string?
					local v = variant()
					checkVariant(v)
					if v ~= "color" then
						return nil
					end
					local face = Kbd.face(gamepad(), Kbd.platform())
					return if face then "ui-kbd-face-" .. face else nil
				end,
			},
		})
		h.text, h.glyph = text, glyph

		return Element.new("Frame", {
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = function()
				return visible() and Kbd.label(key()) ~= ""
			end,
			Tags = { "ui-kbd" :: any, ["ui-kbd-glyph"] = hasImage },
			Element.new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Element.new("UISizeConstraint", {
				MinSize = function()
					local px = math.round(Kbd.glyphSize * (Kbd.scale[density()] or 1))
					return Vector2.new(px, px)
				end,
			}),
			text,
			glyph,
		})
	end,
}

function Kbd.new(props: { [string]: any }?)
	return Component.mount(spec, props)
end

return Kbd
