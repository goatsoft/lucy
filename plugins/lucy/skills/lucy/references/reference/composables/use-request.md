<!-- Made by scripts/skills.ts from docs/reference/composables/use-request.md. Edit the doc, not this file. -->
# useRequest

`Lucy.useRequest` asks the server a question and keeps the answer as state:
a leaderboard, a shop's stock for today, a friend's profile. It asks again when
what it asks about changes. While a call is out, `loading()` is true. An answer
that comes back after the player has moved on is dropped.

## Usage

```luau
local request = Lucy.useRequest(app, name, args?, options?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `App` | required | The App, made with `server = true` |
| `name` | `string` | required | The request's name, as the server handles it |
| `args` | `function` or `table` | none | A function returning the call's arguments, read reactively, or a list of them |
| `options` | `table?` | `{}` | See below |

### Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `enabled` | `MaybeRef<boolean>` | `true` | No calls while false, such as while a dialog is closed. Turning true asks |
| `every` | `number` | | Asks again this many seconds apart while enabled, keeping the answer it has meanwhile |
| `keep` | `boolean` | `false` | Keeps the last answer while the next arguments load, instead of clearing it |

### Returns

| Name | Type | What it is |
|---|---|---|
| `data()` | `() -> any` | The server's answer. `nil` until the first one, and cleared when the arguments change unless `keep` |
| `loading()` | `() -> boolean` | `true` while a call is out |
| `error()` | `() -> string?` | The last call's error message. `nil` again once a call succeeds. The answer it had stays in `data` |
| `refresh()` | `() -> ()` | Asks again now, keeping the answer meanwhile |

When `args` reads a ref and the ref changes, it asks again. Only the newest
call's answer lands, so switching tabs quickly never leaves the wrong board
showing. Stopping the owner drops any answer still to come.

## Example: Club Lucy's Hype board

The Hype board for the week picked in the dialog, while it is open:

```luau
local period = app.state:ref("boards.period")
local open = app.state:ref("ui.leaderboards.open")

local hype = Lucy.useRequest(app, "boards.get", function()
    return "hype", period()
end, { enabled = open, every = 30 })

Lucy.Leaderboard.new({
    rows = function()
        local data = hype.data()
        return if data then data.rows else {}
    end,
    own = function()
        local data = hype.data()
        return data and data.me
    end,
    loading = function()
        return hype.data() == nil and hype.error() == nil
    end,
    Parent = hypeDialog,
})
```

The server side, `boards.get`, comes from [Lucy.Boards](../boards.md). The
[Leaderboards recipe](../../recipes/leaderboards.md) puts the two together.
