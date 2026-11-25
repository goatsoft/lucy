<!-- Made by scripts/skills.ts from docs/reference/composables/use-proximity.md. Edit the doc, not this file. -->
# useProximity

`Lucy.useProximity` tracks whether the player's character is within `distance`
studs of a `BasePart`, `Attachment`, `Model` or `Vector3`, with hysteresis so
it does not flicker on the boundary. Every `useProximity` in an app shares one
Heartbeat loop that stops when the last watcher stops.

## Usage

```luau
local near = Lucy.useProximity(app, workspace.Booth.Console, {
    distance = 10,
    hysteresis = 1,
    lineOfSight = false,
})
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `app` | `App` | required | The app |
| `target` | `BasePart \| Attachment \| Model \| Vector3` | required | World position or instance (or getter) |
| `options.distance` | `MaybeRef<number>?` | `10` | Activation radius in studs |
| `options.hysteresis` | `number?` | `1` | Extra studs required to leave once active |
| `options.lineOfSight` | `boolean?` | `false` | Require an unobstructed raycast from the character |
| `options.origin` | `(() -> Vector3?)?` | character root | Custom origin getter (useful in specs) |

Returns `{ active, distance, check }`.

## Example: showing a Dance Floor prompt

```luau
local nearFloor = Lucy.useProximity(app, workspace.DanceFloor, { distance = 18 })

Lucy.watch(nearFloor.active, function(inside)
    floorStatus(if inside then "On the floor" else "Lobby")
end)
```
