<!-- Made by scripts/skills.ts from docs/guide/world-ui.md. Edit the doc, not this file. -->
# UI in the world

Some UI belongs in the world, not on the screen: a scoreboard on the wall, a
voting panel on a DJ booth, a name tag over a dancer. Lucy makes these guis for
you, on the client, so they follow the theme, hold components and take clicks
like the rest of your UI.

## A surface on a part

`app:createSurface` puts a SurfaceGui on a part. Build into it like a scene's
gui:

```luau
local round = app.state:ref("show.round")

local board = app:createSurface("Scoreboard", {
    adornee = workspace.Stage.Screen,
    pixelsPerStud = 50,
})

Lucy.Panel.new({
    title = "The Basement",
    children = {
        Lucy.Text.new({
            text = function()
                return `Round {round()}`
            end,
            variant = "h2",
        }),
    },
    size = UDim2.fromScale(1, 1),
    Parent = board,
})
```

The gui goes in the player's PlayerGui with its `Adornee` set to the part.
That is what lets clicks and taps reach it: a gui parented to a part draws but
never takes input.

| Option | Default | What it does |
|---|---|---|
| `adornee` | | The part to draw on. Required |
| `face` | `Front` | Which face of the part, an `Enum.NormalId` |
| `pixelsPerStud` | `50` | How many layout pixels fit in a stud |
| `canvasSize` | | A `Vector2`: a fixed canvas instead of pixels per stud |
| `lightInfluence` | `0` | How much the world's light tints it. 0 keeps the theme's colours exact |
| `brightness` | `1` | |
| `alwaysOnTop` | `false` | Draws it over the world |
| `maxDistance` | any distance | Hides it past this many studs |
| `zOffset` | `0` | |
| `enabled` | `true` | |

## A billboard over a part

`app:createBillboard` hangs a BillboardGui over a part or an attachment, such
as a character's head:

```luau
local tag = app:createBillboard("NameTag", {
    adornee = character.Head,
    size = UDim2.fromOffset(200, 50),
    studsOffset = Vector3.new(0, 2, 0),
})

Lucy.Badge.new({ text = player.DisplayName, Parent = tag })
```

It takes `adornee` (a part or an attachment), `size` (200 by 50 pixels),
`studsOffset`, and `lightInfluence`, `brightness`, `alwaysOnTop`,
`maxDistance` and `enabled` as above.

## How world guis differ from scenes

- **No screen scaling.** Scenes scale a 1280 by 720 layout to the screen (see
  [Scaling](../architecture.md#scaling)). A world gui's size comes from the
  part, so lay it out for its own size: a part 8 studs wide at 50 pixels per
  stud is 400 pixels wide.
- **Not for keyboard and gamepad navigation.** Focus moves between scenes and
  overlays on the screen, never onto a part. Give gamepad players a
  [hotkey](actions.md) or a ProximityPrompt that opens the same thing on
  screen, such as a [Sheet](../components/sheet.md).
- **Gone with its part.** A world gui is destroyed when its part leaves the
  game, and with the App. You only destroy one yourself to take it away early.
- **Density.** Control heights and text follow the device like everywhere
  else, so a touch player gets bigger buttons to tap.

## Data from the server

The server owns what world UI shows: the round, the scores, who is on stage.
Keep it in a `Lucy.Server` and each App sees it at `server.*`, so a world gui
binds to it like any other UI. See [Share state with the server](server.md).

A gui the server already made can still use the theme. Link it from the client
and bind its labels:

```luau
local screen = workspace.Stage.Screen:WaitForChild("SurfaceGui")
app.theme:link(screen)
Lucy.hydrate(screen.Title) { Tags = { "stage-title" } }
```

It can't take clicks unless it is in the player's PlayerGui; make the
interactive parts with `createSurface` instead.

## Next

- [Build screens with scenes](scenes.md)
- [Work with app state](app-state.md)
- [Add a theme](themes.md): tag your own instances and style them with tokens
