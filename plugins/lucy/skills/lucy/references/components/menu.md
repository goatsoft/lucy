<!-- Made by scripts/skills.ts from docs/components/menu.md. Edit the doc, not this file. -->
# Menu

A set of actions that opens when the player asks for it and closes once they
pick one: a game's main actions, a player's options, a build tool's modes. The
same menu can be a list on mouse and keyboard, a ring on a controller and a fan
from a corner button on touch, so each player gets the shape that suits their
hands, and none of its actions need a button of their own.

```luau
local button = Lucy.Button.new({ text = "Club", variant = "outline", Parent = parent })
Lucy.Menu.new({
    id = "club",
    open = true,
    anchor = button,
    items = {
        { value = "join", label = "Join show", icon = "lucy:plus" },
        { value = "dj", label = "DJ request" },
        { value = "lab", label = "The Lab" },
        { value = "dances", label = "Dances" },
        { value = "exit", label = "Exit", icon = "lucy:close" },
    },
    onSelect = function(value)
        app.toast(`Picked {value}`)
    end,
    Parent = parent,
})
```

A menu has no button of its own: give it an `anchor` and open it from a button,
a key or anything else.

```luau
button.Activated:Connect(function()
    menu:toggle()
end)
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `items` | table | | | The actions, see [Items](#items) |
| `variant` | string or responsive | `"list"` | | `list`, `radial` or `arc`, see [Variants](#variants) |
| `anchor` | instance, handle or getter | | | What it opens from. With none, a ring opens in the middle of the screen |
| `returnFocus` | object, handle, getter or `false` | | | Where keyboard and gamepad focus goes when it closes, in place of its anchor. `false` leaves nothing selected, for a menu or panel opened from a HUD whose buttons must not keep the left stick |
| `open` | boolean | `false` | yes | Whether it is open |
| `side` | string | `"auto"` | | List: `auto`, `bottom`, `top`, `left` or `right`, see [Where it opens](#where-it-opens) |
| `align` | string | `"start"` | | List: `start`, `center` or `end`: how the list lines up with the anchor |
| `width` | number | `220` | | List: at least this wide (and at least the anchor's width when above or below it) |
| `radius` | number | by item count, `900` for a fan | | Ring: the distance from the centre to each button. Fan: the radius of its curve (larger is straighter) |
| `shape` | string or responsive | `"round"` | | Ring and fan buttons: `round`, `squircle` or `square`, see [Button shapes](#button-shapes) |
| `size` | string or responsive | `"md"` | | `md` or `lg`, like a [Button](button.md)'s: `lg` rows are as tall as a large button with larger text, and `lg` ring and fan buttons are bigger, with larger icons and labels |
| `onSelect` | function | | | Called with `(value, handle)` when the player picks an action |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

### Items

An item is a value, shown as its text, or a table with `value`, and optionally:

- `label` (or `text`): what it says.
- `icon`: any name [Icon](icon.md) draws, a `lucy:` icon or one of your own.
  A ring or fan button shows it, or the label's initials when there is none.
- `hint`: the name of an [action](../guide/actions.md). The list shows its key
  beside the item, so a player learns the shortcut.
- `disabled`: shown faded, and cannot be picked.

## Variants

- **`list`:** a list next to its anchor, like a dropdown. On touch it is a
  drawer from the bottom of the screen, where a thumb can reach it.
- **`radial`:** a ring of round buttons around the anchor, or the middle of the
  screen with no anchor. When the ring does not fit around an anchor by the
  edge of the screen (a button in a bottom bar), it opens clear of the anchor,
  toward the middle, so it never covers it. On a controller the left stick
  points at a button, and A picks it.
- **`arc`:** a fan like a dock's stack: buttons one above another from the
  anchor along a gentle curve, each tilted a little more than the last, with
  its label in a pill beside it. It rises from an anchor in the lower half of
  the screen and drops from one in the upper half; the labels sit on the side
  toward the middle and the curve bends away from them. It moves in when a
  button or label would be off the screen. The first item sits nearest the
  anchor, and up and down on a controller walk the stack.

Ring buttons show their label under them.

```luau
Lucy.Menu.new({
    open = true,
    variant = "radial",
    items = {
        { value = "join", label = "Join show", icon = "lucy:plus" },
        { value = "dj", label = "DJ request" },
        { value = "lab", label = "The Lab" },
        { value = "dances", label = "Dances" },
        { value = "items", label = "Items" },
        { value = "exit", label = "Exit", icon = "lucy:close" },
    },
    Parent = parent,
})
```

### A variant for each input

`variant` takes a [responsive value](index.md#responsive-values), so one menu
can be a different variant for each input, and changes shape when the player
picks up a controller or puts it down:

```luau
Lucy.Menu.new({
    items = actions,
    variant = { gamepad = "radial", touch = "arc", default = "list" },
    anchor = clubButton,
})
```

### Button shapes

`shape` sets the outline of ring and fan buttons, to match the rest of a
game's buttons:

- **`round`:** circles (the default).
- **`squircle`:** rounded squares, softer than a square and firmer than a
  circle.
- **`square`:** squares with the theme's medium corner radius.

Like `variant`, it takes a responsive value.

```luau
Lucy.Menu.new({
    open = true,
    variant = "radial",
    shape = "squircle",
    items = {
        { value = "join", label = "Join show", icon = "lucy:plus" },
        { value = "dj", label = "DJ request" },
        { value = "lab", label = "The Lab" },
        { value = "dances", label = "Dances" },
        { value = "exit", label = "Exit", icon = "lucy:close" },
    },
    Parent = parent,
})
```

## Where it opens

A list opens beside its anchor on the side you ask for, and moves to the other
side when that has more room. With `side = "auto"` (the default) it opens below
if it fits, then above, then to the right or left, so a menu from a top bar
drops down and one from a bottom bar pops up. It stays inside the screen: a
list near the right edge shifts left, and one beside its anchor shifts up or
down to fit.

A ring is moved in from the edges until all of it shows. A fan always opens
away from the edges, toward the middle of the screen.

## Input

It opens on the app's overlay layer, above everything opened before it, and
holds keyboard and gamepad focus while open:

- **Mouse and touch:** press an action. A press outside closes it.
- **Keyboard and D-pad:** move between actions and press Enter or A.
- **Stick:** on a ring or fan, point the left stick at a button to select it.
- **Back:** B, Backspace or Escape closes it without picking anything.

On a ring or fan, the focus ring goes round the whole action, its button and
its label, following the button's shape: a pill round a round button, a rounded
box round a squircle or square one.

When it closes, the anchor is selected again on a controller.

## Methods and events

| Name | What it does |
|---|---|
| `menu:open()` | Opens it |
| `menu:close()` | Closes it |
| `menu:toggle()` | Opens it if closed, closes it if open |
| `menu:select(value)` | Picks `value` as if the player had, and closes it |
| `menu.variant()` | The variant in use: `list`, `radial` or `arc` |
| `menu.shape()` | The button shape in use: `round`, `squircle` or `square` |
| `menu.size()` | The size in use: `md` or `lg` |
| `menu.presentation()` | For a list, `"popup"` or `"drawer"`, for this opening |

It reports `open` and `close`, and `select` with the value picked, for
[game sounds](../reference/composables/use-ui-sound.md).

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Menu")`.
