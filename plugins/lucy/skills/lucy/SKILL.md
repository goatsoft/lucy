---
name: lucy
description: Build Roblox game UI with Lucy, the UI kit and app framework (Luau). Use when a game requires or installs Lucy (`require(...Lucy)`, `goatsoft/lucy` in wally.toml, a `Lucy` folder of components), or when asked to build menus, HUDs, shops, settings, dialogs, hotkeys or any screen in a Lucy game. Covers the App, scenes, app state, components, styling, input and focus, and hotkeys.
---

# Building UI with Lucy

Lucy is a UI kit and app framework for Roblox. A game makes one `Lucy.App` on
the client. The app owns the state, theme, input, scenes, overlays and toasts.
Every component works with mouse, keyboard, gamepad and touch, on desktop,
console, tablet and phone, as long as you build with Lucy's pieces.

Read the reference pages below before writing code. They are the docs, and
they are exact; this page only says where things are and what agents get wrong.

## Find Lucy in the game

- **Wally:** `ReplicatedStorage.Packages.Lucy` (see `wally.toml`).
- **Copied in:** a `Lucy` folder of source the game owns, often
  `ReplicatedStorage.Shared.Lucy`. Only the components that were added are
  there; add more with the copy-in command in
  [Getting started](references/index.md).
- Look for the existing `Lucy.App.new` call (usually a client script) and use
  that app. Never make a second one.

## How it fits together

- **App state** is one tree. Read and write it by path:
  `app.state:get("player.coins")`, `app.state:set("player.coins", 10)`.
  `app.state:ref("player.coins")` is a ref that follows the path both ways.
- **Components** are `Lucy.X.new(props)` and return a handle. Each keeps its
  state at `ui.<id>`, so game code can drive one without a reference:
  `app.state:set("ui.quit.open", true)`. Give an `id` to anything game code
  needs to reach.
- **Props take a value, a ref, a computed or a getter function.** A ref or a
  writable computed binds both ways; a getter flows in only.
- **Plain instances** come from `Lucy.new "Frame" { ... }`; properties take the
  same values, and `Lucy.show` / `Lucy.each` handle conditions and lists.
- **Scenes** own one ScreenGui each: one screen at a time, overlays (HUD) and
  stacked modal scenes above it. Dialogs, sheets and selects float on the
  overlay layer above everything.
- **Looks come from the theme.** Colours, fonts, sizes and radius are style
  rules with `$Token` values (`$Primary`, `$Card`, `$Border`, `$FontSansSemibold`,
  `ControlMd`), switched by theme (light, dark) and density (default, touch, tv).

## Rules

1. **Use a component when one exists** (list below) before building from
   instances. A Lucy Button, Select or Slider already handles focus, gamepad,
   touch and disabled states.
2. **Never hard code colours, fonts or text sizes** on instances. Use a
   component variant, or tags with style rules and `$Token` values. Setting
   `BackgroundTransparency = 1` on a layout frame is fine; a colour is not.
3. **Bind, don't watch.** A property that follows state gets a ref or a getter.
   `Lucy.watch` and `Lucy.watchEffect` are only for side effects (tweens,
   sounds, calling game code), never to set a property a binding could own.
4. **Derive with `Lucy.computed`** when more than one binding reads the result;
   a plain getter otherwise.
5. **Give every screen a `defaultFocus`** and test it with keys and a gamepad:
   a console player cannot click.
6. **Icons, not text glyphs.** Use `Lucy.Icon` with a registered name
   (`"lucide:heart"` with lucy-icons, or the game's own images). See the
   `lucy-icons` skill.
7. **Hotkeys go through `app.actions`**, never raw `UserInputService` checks.
   To block gameplay and movement while a menu or dialog is open, use
   `Lucy.useWhile` with `app:modalOpen()`, as
   [Hotkeys and modal input](references/guide/actions.md) shows. Conditions
   must be tracked: `app.state:ref(path)`, not `app.state:get(path)`.
8. **Lists in state:** use `Lucy.insert` / `Lucy.remove` or set a new table;
   `table.insert` on a reactive list is not seen.
9. **Writing a component of your own:** follow
   [Build a component](references/guide/components.md). The spec is built once
   at module level, `render` runs once and must return an Instance, and looks
   go in its `rules`.

## Check your work

- Stories render a piece of UI in Studio without pressing Play:
  `Lucy.Preview.show("Button")` from the command bar, or the game's own stories.
  See [Stories and preview](references/stories.md).
- With Studio's MCP server: run Luau with `execute_luau`, look with
  `screen_capture`, and try other screens with the device simulator.
- Styles apply a few frames after a change; read styled values with
  `instance:GetStyled("BackgroundColor3")`, not the plain property.

## Components

<!-- generated:components -->
- [Accordion](references/components/accordion.md): Sections the player opens and closes, one or several at a time.
- [Alert](references/components/alert.md): A box that calls attention to a message, such as a server notice.
- [Avatar](references/components/avatar.md): A player's headshot, or a monogram for a bot or an empty slot.
- [Badge](references/components/badge.md): A small label for a status or a count.
- [Button](references/components/button.md): A button, in six variants and four sizes.
- [Checkbox](references/components/checkbox.md): A box that can be checked, with an optional label.
- [Collapsible](references/components/collapsible.md): A header that shows or hides what is under it.
- [DataGrid](references/components/data-grid.md): A table the player can sort by pressing its headers.
- [Dialog](references/components/dialog.md): A modal window, and alert dialogs that ask for a yes or no.
- [Grid](references/components/grid.md): Rows of equal cells, such as shop items or emotes.
- [Icon](references/components/icon.md): A small picture in the theme's colours, by name or asset id.
- [Image](references/components/image.md): A picture from an asset id or a thumbnail.
- [Input](references/components/input.md): A text field, on one line or several.
- [Item](references/components/item.md): A row in a list, with media, a title, a description and actions.
- [Kbd](references/components/kbd.md): The key to press, for the player's keyboard or controller.
- [Number Field](references/components/number-field.md): A number with minus and plus buttons, typed or stepped.
- [Panel](references/components/panel.md): A card with a header, content and footer.
- [Pressable](references/components/pressable.md): A surface the player can click that holds anything, such as a card in a shop.
- [Progress](references/components/progress.md): A bar that fills from 0 to a maximum.
- [Radio Group](references/components/radio-group.md): A list of options where the player picks exactly one.
- [Scroll Area](references/components/scroll-area.md): A region that scrolls when its content does not fit.
- [Select](references/components/select.md): A button that opens a list of options to pick one from.
- [Separator](references/components/separator.md): A thin line between items.
- [Sheet](references/components/sheet.md): A panel from the side of the screen, a drawer from the bottom on touch.
- [Skeleton](references/components/skeleton.md): A pulsing placeholder while content loads.
- [Slider](references/components/slider.md): Picks a number in a range by dragging or with the arrows.
- [Spinner](references/components/spinner.md): A turning ring that shows something is loading.
- [Stack](references/components/stack.md): A row or column that lays out its children.
- [Switch](references/components/switch.md): An on and off switch, with an optional label.
- [Table](references/components/table.md): Rows and columns for leaderboards, friends lists and inventories.
- [Tabs](references/components/tabs.md): A tab bar with one panel per tab, showing the picked one.
- [Text](references/components/text.md): Headings, body copy and labels.
- [Toaster](references/components/toaster.md): Toast notifications through app.toast.
- [Toggle Group](references/components/toggle-group.md): A row of toggles where the player picks one or several.
- [Toggle](references/components/toggle.md): A button that stays pressed until it is clicked again.
<!-- /generated:components -->

## Guides and reference

<!-- generated:guides -->
- [Getting started](references/index.md): Install Lucy, create an App and build your first scene.
- [Architecture](references/architecture.md): How App, AppState, Theme, scenes and input fit together.
- [Reactivity](references/reactivity.md): ref, computed, reactive and watch; Lucy.new for declarative UI; springs and tweens.
- [Components](references/components/index.md): Every Lucy component, how to use one and how to write your own.
- [Hotkeys and modal input](references/guide/actions.md): Name your game's actions once for keyboard and gamepad, switch them off while a menu is open, and stop the character moving under a dialog.
- [Work with app state](references/guide/app-state.md): Keep game data in the app's store and bind UI to it with state:ref, state.root, lists and subscribers.
- [Build a component](references/guide/components.md): Write a Stepper component step by step, with state keys, h:ref, bindings, methods and a value bound to app state.
- [Share logic with composables](references/guide/composables.md): Use Lucy's built in composables and write your own, such as a cooldown for an ability button.
- [Stories and preview](references/stories.md): Write stories for your UI and preview them in Studio, in edit mode or in Play.
- [Composables](references/reference/composables.md): Every composable Lucy comes with, what each one takes and returns, and when to use it.
- [The store](references/reference/store.md): How app.state works, what it holds, every method, and the rules for reading, writing and following it.
<!-- /generated:guides -->
