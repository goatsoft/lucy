--!strict
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

	Preview a story in Studio (edit mode, from the command bar):

		Lucy.Preview.show("Button")

	See README.md and docs/ for the full guide.
]]

local Core = script.Core
local Components = script.Components

local Reactive = require(Core.Reactive)
local Element = require(Core.Element)
local Animate = require(Core.Animate)
local App = require(Core.App)
local AppState = require(Core.AppState)
local Component = require(Core.Component)
local SceneManager = require(Core.SceneManager)
local Theme = require(Core.Theme)
local Preview = require(Core.Preview)
local Composables = require(script.Composables)

export type Ref<T> = Reactive.Ref<T>
export type Computed<T> = Reactive.Computed<T>
export type MaybeRef<T> = Reactive.MaybeRef<T>
export type Scope = Reactive.Scope
export type App = App.App
export type AppState = AppState.AppState
export type Theme = Theme.Theme
export type Scene = SceneManager.Scene
export type Handle = Component.Handle
export type Props = Component.Props
export type Rule = Component.Rule
export type Spec = Component.Spec
export type Story = Preview.Story

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
	isWritable = Reactive.isWritable,
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

	-- Composables (ADR 0018)
	useDensity = Composables.useDensity,
	useMetric = Composables.useMetric,
	useBackHandler = Composables.useBackHandler,
	useFocusScope = Composables.useFocusScope,
	useResponsive = Composables.useResponsive,
	useUiSound = Composables.useUiSound,
	useTable = Composables.useTable,

	-- Animation (Core/Animate)
	spring = Animate.spring,
	tween = Animate.tween,

	-- Framework
	App = App,
	AppState = AppState,
	Theme = Theme,
	Tokens = require(Core.Tokens),
	Oklab = require(Core.Oklab),
	Palette = require(Core.Palette),
	SceneManager = SceneManager,
	InputManager = require(Core.InputManager),
	Adaptive = require(Core.Adaptive),
	Responsive = require(Core.Responsive),
	Scroll = require(Core.Scroll),
	Component = Component,
	Reactive = Reactive,
	Element = Element,
	Animate = Animate,
	Signal = require(Core.Signal),
	Maid = require(Core.Maid),
	Preview = Preview,

	-- Components
	Alert = require(Components.Alert),
	Avatar = require(Components.Avatar),
	Badge = require(Components.Badge),
	Button = require(Components.Button),
	Checkbox = require(Components.Checkbox),
	Dialog = require(Components.Dialog),
	Grid = require(Components.Grid),
	Icon = require(Components.Icon),
	Image = require(Components.Image),
	Input = require(Components.Input),
	Item = require(Components.Item),
	Kbd = require(Components.Kbd),
	Panel = require(Components.Panel),
	Pressable = require(Components.Pressable),
	Progress = require(Components.Progress),
	RadioGroup = require(Components.RadioGroup),
	ScrollArea = require(Components.ScrollArea),
	Select = require(Components.Select),
	Separator = require(Components.Separator),
	Sheet = require(Components.Sheet),
	Skeleton = require(Components.Skeleton),
	Spinner = require(Components.Spinner),
	Stack = require(Components.Stack),
	Switch = require(Components.Switch),
	Table = require(Components.Table),
	Tabs = require(Components.Tabs),
	Text = require(Components.Text),
	Toaster = require(Components.Toaster),
	Toggle = require(Components.Toggle),
	ToggleGroup = require(Components.ToggleGroup),
}
