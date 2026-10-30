<!-- Made by scripts/skills.ts from docs/reference/composables.md. Edit the doc, not this file. -->
# Composables

A composable is a function named `useX` that creates refs, computeds and effects
for whatever is running now: a component's render, an effect, or `scope:run` of a
`Lucy.effectScope()`. What it creates stops with that owner. Every composable
here raises an error when there is no owner, since nothing would ever stop it.

To write your own, see [Share logic with composables](../guide/composables.md).

| Composable | What it does |
|---|---|
| [`useDensity`](#usedensity) | The device's density: `"default"`, `"touch"` or `"tv"` |
| [`useMetric`](#usemetric) | A control size in pixels, following density |
| [`useResponsive`](#useresponsive) | A value that changes with the device, such as a gap |
| [`useBackHandler`](#usebackhandler) | Escape or ButtonB calls your function while active |
| [`useFocusScope`](#usefocusscope) | Keeps keyboard and gamepad focus inside a frame while active |
| [`useUiSound`](#useuisound) | Calls your functions when components are clicked, toggled, opened or closed |
| [`useTable`](#usetable) | Sorted rows from your data and a list of columns |
| [`useWhile`](#usewhile) | Sets something up while a condition is true and cleans it up when it turns false |
| [`useCountdown`](#usecountdown) | Whole seconds left until a time, for round and event timers |

## useDensity

```lua
local density = Lucy.useDensity(app) -- "default", "touch" or "tv"
```

Returns a getter that follows the theme's density. Every caller in an app shares
one, so it costs nothing to ask for.

## useMetric

```lua
local height = Lucy.useMetric(app, "ControlMd")
```

Returns a computed with the pixel height of a control token (`ControlSm`,
`ControlMd`, `ControlLg` or `ControlIcon`) in the current density.

## useResponsive

```lua
local gap = Lucy.useResponsive(app, { touch = 16, default = 8 })
```

Returns a getter for a responsive value, picked for the player's device and input.
A plain value comes back as a getter too, so you can bind either the same way. See
[Responsive values](../components/index.md#responsive-values) for the keys it takes.

## useBackHandler

```lua
Lucy.useBackHandler(app, isOpen, function()
    isOpen(false)
    return true -- handled; stop here
end)
```

While `active` (a ref, getter or plain value) is true, Escape and ButtonB call
the function. Return `true` when you handled the press, so nothing under it
gets it too. The newest handler goes first.

## useFocusScope

```lua
Lucy.useFocusScope(app, isOpen, { root = panel, defaultFocus = playButton })
```

While `active` is true, keyboard and gamepad focus stays inside `root`, starting
on `defaultFocus` (an Instance, or a function returning one).

## useUiSound

```lua
Lucy.useUiSound(app, {
    activate = function(handle) playClick() end,
    toggle = function(handle, checked) playSwitch(checked) end,
    open = playWhoosh,
    close = playWhoosh,
})
```

Lucy plays no audio. Components report what the player did, and this calls your
functions so the game can play its own sounds. Each function gets the component's
handle, and for some events a value:

| Event | When | Value |
|---|---|---|
| `activate` | A Button or Pressable is clicked | |
| `toggle` | The player turns a Switch or Checkbox on or off | The new checked state |
| `open` | A Dialog opens | |
| `close` | A Dialog closes | |
| `select` | The player picks an option in a RadioGroup, ToggleGroup or Select | The value picked |

Which map a component uses:

- **Its own owners first.** Lucy looks from the component up through the scopes
  it was made in, and the first map that names the event wins. Call it in a
  scene to cover that scene; call it again in part of the scene to change a few
  events there.
- **`false` silences an event**, such as `{ activate = false }` for buttons that
  are pressed on every beat.
- **Components made with no owner**, by plain script code, use the newest map
  from a top level `Lucy.effectScope()`.
- **`sound = false`** in one component's props silences that component.

A function that errors is reported in the output and never breaks the click.

Your own components report events the same way, with `h:emit(event, value)`.

## useTable

Turns your data and a list of columns into sorted rows, and keeps them sorted as
the data changes. It draws nothing: [DataGrid](../components/data-grid.md) uses
it for its headers, and you can use it for any list you sort yourself.

```lua
local board = Lucy.useTable({
    data = players,             -- an array, a ref or a getter
    rowId = function(player) return player.userId end,
    columns = {
        { key = "name", header = "Player" },
        { key = "score", header = "Score", descFirst = true },
        { key = "rank", header = "Rank", invert = true },
        { id = "kd", header = "K/D", get = function(player) return player.kills / math.max(1, player.deaths) end },
        { id = "invite", sortable = false },
    },
    sorting = { id = "score", desc = true },
})

for _, row in board.rows() do
    print(row.id, row:value("score"))
end
board.toggle("name")            -- what a press on the Name header does
```

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `data` | array, ref or getter | | The rows, any tables you like |
| `columns` | table | | The columns, see below |
| `rowId` | function | the position | Gives each row an id, so lists update by id |
| `sorting` | table, ref or `false` | `false` | `{ id = "score", desc = true }`, or a ref to keep it in |
| `sortable` | boolean | `true` | `false` turns sorting off for every column |
| `removable` | boolean | `true` | A third press on a header clears the sort |
| `descFirst` | boolean | `false` | Every column sorts high to low on the first press |
| `manual` | boolean | `false` | The data comes sorted (by your server): keep its order, only track the sort |

A column has:

| Field | What it does |
|---|---|
| `key` | The field to read, and the column's id |
| `id` | The column's id, when it has no `key` |
| `get` | A function from the row to the value, instead of `key` |
| `header` | What the header shows |
| `sortable` | `false` stops this column sorting. Columns with no `key` or `get` never sort |
| `sortFn` | `"auto"`, `"number"`, `"text"` or a function `(a, b)` returning a negative number, 0 or a positive number |
| `descFirst` | The first press sorts high to low |
| `invert` | For values where lower is better, such as a rank |

`"auto"` compares numbers as numbers and anything else as text. Text sorts the
way a person reads it: `item2` comes before `item10`, and case does not count.
Rows with no value for the column always go last, and rows with equal values
keep the order of your data. One column sorts at a time.

### What it returns

| Name | What it is |
|---|---|
| `rows()` | The sorted rows. Each has `id`, `index` (its place in your data), `original` (your table) and `row:value(columnId)` |
| `sorting()` | The sort, `{ id, desc }`, or `false` |
| `toggle(columnId)` | Sorts by the column in its first direction, then the other, then not at all |
| `sortedBy(columnId)` | `"asc"`, `"desc"` or `false` |
| `canSort(columnId)` | Whether the column sorts |
| `setSorting(sort)` | Sets the sort directly |
| `columns` | The columns, with their ids worked out |

## useWhile

```lua
Lucy.useWhile(isOpen, function()
    return UserInputService.InputBegan:Connect(onInput)
end)
```

Runs the function each time the condition turns true, and cleans up what it made
when the condition turns false or the owner stops. The condition is a ref, a
getter or a value. The function can return a cleanup function or a connection,
call `Lucy.onCleanup`, or make effects of its own; all of it is cleaned up.

Only the condition starts it again: values the function reads along the way do
not.

A common use is switching gameplay keys and movement off while a menu is open
(see [Hotkeys and modal input](../guide/actions.md)):

```lua
Lucy.useWhile(function()
    return app:modalOpen()
end, function()
    return app.actions:disable("gameplay", "movement")
end)
```

## useCountdown

```lua
local timer = Lucy.useCountdown(roundEndsAt)

Lucy.Text.new({
    text = function()
        return `{timer.remaining()}s left`
    end,
})
```

Counts the whole seconds left until `endsAt`, a number, ref or getter in
`workspace:GetServerTimeNow()` time, so every player sees the same count. Send
the end time from your server once; there is no need to send every second.

| Name | What it is |
|---|---|
| `remaining` | Seconds left, never below 0. Changes once a second, on the second |
| `done` | `true` once `remaining` reaches 0 |

With no end time (`nil`), `remaining` is 0 and `done` is `false`. When the end
time changes, the count follows it.
