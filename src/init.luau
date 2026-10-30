--[[
	Lucy: a UI kit and app framework for Roblox.

		local Lucy = require(ReplicatedStorage.Packages.Lucy)
		local app = Lucy.App.new({ theme = "dark", baseColor = "zinc" })

		local coins = app.state:ref("player.coins")
		Lucy.new "TextLabel" {
			Text = function() return `Coins: {coins()}` end,
			Parent = gui,
		}

		app.scenes:register("Title", { build = function(scene)
			Lucy.Button.new({ text = "Play", Parent = scene.gui, onClick = function()
				app.scenes:goTo("Game")
			end })
		end })
		app.scenes:goTo("Title")
		app.toast.success("Welcome back")

	See README.md and docs/ for the full guide.
]]

local Core = script.Core
local Components = script.Components

local Reactive = require(Core.Reactive)
local Element = require(Core.Element)
local Animate = require(Core.Animate)

export type Ref<T> = Reactive.Ref<T>
export type Computed<T> = Reactive.Computed<T>
export type MaybeRef<T> = Reactive.MaybeRef<T>
export type Scope = Reactive.Scope

return {
	-- Reactivity (Core/Reactive)
	ref = Reactive.ref,
	computed = Reactive.computed,
	reactive = Reactive.reactive,
	watch = Reactive.watch,
	watchEffect = Reactive.watchEffect,
	effectScope = Reactive.effectScope,
	onCleanup = Reactive.onCleanup,
	batch = Reactive.batch,
	untrack = Reactive.untrack,
	peek = Reactive.peek,
	toValue = Reactive.toValue,
	toRaw = Reactive.toRaw,
	isRef = Reactive.isRef,
	isReactive = Reactive.isReactive,
	trigger = Reactive.trigger,
	insert = Reactive.insert,
	remove = Reactive.remove,

	-- Declarative instances (Core/Element)
	new = Element.new,
	hydrate = Element.hydrate,
	on = Element.on,
	changed = Element.changed,
	out = Element.out,
	model = Element.model,
	instance = Element.instance,
	show = Element.show,
	each = Element.each,

	-- Animation (Core/Animate)
	spring = Animate.spring,
	tween = Animate.tween,

	-- Framework
	App = require(Core.App),
	AppState = require(Core.AppState),
	Theme = require(Core.Theme),
	Tokens = require(Core.Tokens),
	Oklab = require(Core.Oklab),
	Palette = require(Core.Palette),
	SceneManager = require(Core.SceneManager),
	InputManager = require(Core.InputManager),
	Adaptive = require(Core.Adaptive),
	Responsive = require(Core.Responsive),
	Component = require(Core.Component),
	Reactive = Reactive,
	Element = Element,
	Animate = Animate,
	Signal = require(Core.Signal),
	Maid = require(Core.Maid),

	-- Components
	Badge = require(Components.Badge),
	Button = require(Components.Button),
	Checkbox = require(Components.Checkbox),
	Dialog = require(Components.Dialog),
	Input = require(Components.Input),
	Panel = require(Components.Panel),
	Progress = require(Components.Progress),
	Separator = require(Components.Separator),
	Skeleton = require(Components.Skeleton),
	Stack = require(Components.Stack),
	Switch = require(Components.Switch),
	Text = require(Components.Text),
	Toaster = require(Components.Toaster),
}
