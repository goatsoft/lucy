--!strict
--[[
	Lucy: a UI and app framework for Roblox.

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

	Look at a running UI from Studio, or press a button as a player would:

		Lucy.Devtools.tree()
		Lucy.Devtools.press("buy")

	See README.md and docs/ for the full guide.
]]

local Core = script.Core
local Components = script.Components

local Reactive = require(Core.Reactive)
local Element = require(Core.Element)
local Animate = require(Core.Animate)
local App = require(Core.App)
local Server = require(Core.Server)
local DataQueue = require(Core.DataQueue)
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
export type Server = Server.Server
export type AppState = AppState.AppState
export type Theme = Theme.Theme
export type Scene = SceneManager.Scene
export type Handle = Component.Handle
export type Props = Component.Props
export type Rule = Component.Rule
export type Spec = Component.Spec
export type Story = Preview.Story

local Lucy = {
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
	useFocusZone = Composables.useFocusZone,
	useHoldArrows = Composables.useHoldArrows,
	useSize = Composables.useSize,
	useHasVisibleChild = Composables.useHasVisibleChild,
	useResponsive = Composables.useResponsive,
	useUiSound = Composables.useUiSound,
	useTable = Composables.useTable,
	useSort = Composables.useSort,
	useWhile = Composables.useWhile,
	useCountdown = Composables.useCountdown,
	useDrag = Composables.useDrag,
	useReveal = Composables.useReveal,
	useCount = Composables.useCount,
	useRequest = Composables.useRequest,

	-- Animation (Core/Animate)
	spring = Animate.spring,
	tween = Animate.tween,

	-- Images (Core/Preload): fetch pictures before they are shown
	preload = require(Core.Preload).preload,
	Preload = require(Core.Preload),

	-- Framework
	App = App,
	Server = Server,
	DataQueue = DataQueue,
	Boards = require(Core.Boards),
	AppState = AppState,
	Theme = Theme,
	Tokens = require(Core.Tokens),
	Oklab = require(Core.Oklab),
	Format = require(script.Utils.Format),
	Preferences = require(Core.Preferences),
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

	-- In the world (Core/Aura): effects worn on characters or at points
	Aura = require(Core.Aura),

	-- Components
	Accordion = require(Components.Accordion),
	Alert = require(Components.Alert),
	Arrow = require(Components.Arrow),
	Attribution = require(Components.Attribution),
	Avatar = require(Components.Avatar),
	Badge = require(Components.Badge),
	Slot = require(Components.Slot),
	Button = require(Components.Button),
	Checkbox = require(Components.Checkbox),
	Collapsible = require(Components.Collapsible),
	DataGrid = require(Components.DataGrid),
	Dialog = require(Components.Dialog),
	Effect = require(Components.Effect),
	Gradient = require(Components.Gradient),
	Grid = require(Components.Grid),
	Icon = require(Components.Icon),
	Image = require(Components.Image),
	InlineConfirm = require(Components.InlineConfirm),
	Input = require(Components.Input),
	Item = require(Components.Item),
	Kbd = require(Components.Kbd),
	Leaderboard = require(Components.Leaderboard),
	Marquee = require(Components.Marquee),
	Menu = require(Components.Menu),
	NumberField = require(Components.NumberField),
	Panel = require(Components.Panel),
	PanelCorner = require(Components.PanelCorner),
	Pressable = require(Components.Pressable),
	Progress = require(Components.Progress),
	RadioGroup = require(Components.RadioGroup),
	ScrollArea = require(Components.ScrollArea),
	Select = require(Components.Select),
	Separator = require(Components.Separator),
	Sheet = require(Components.Sheet),
	Skeleton = require(Components.Skeleton),
	Slider = require(Components.Slider),
	SortButton = require(Components.SortButton),
	Spinner = require(Components.Spinner),
	Stack = require(Components.Stack),
	Switch = require(Components.Switch),
	Table = require(Components.Table),
	Tabs = require(Components.Tabs),
	Text = require(Components.Text),
	Toaster = require(Components.Toaster),
	Toggle = require(Components.Toggle),
	ToggleGroup = require(Components.ToggleGroup),
	Tour = require(Components.Tour),
	Waveform = require(Components.Waveform),
}

-- Lucy.Devtools is required the first time it is read (ADR 0027).
type Devtools = typeof(require(Core.Devtools))
local lazy: any = setmetatable(Lucy, {
	__index = function(self: any, key: string): any
		if key == "Devtools" then
			local devtools = require(Core.Devtools)
			rawset(self, key, devtools)
			return devtools
		end
		return nil
	end,
})
return lazy :: typeof(Lucy) & { Devtools: Devtools }
