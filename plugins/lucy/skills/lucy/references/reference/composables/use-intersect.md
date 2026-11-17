<!-- Made by scripts/skills.ts from docs/reference/composables/use-intersect.md. Edit the doc, not this file. -->
# useIntersect

`Lucy.useIntersect` tells you whether something has come near what the scroll
area around it shows. It starts `false`, turns `true` the first time the target
is shown and within a view of the visible part, and stays `true`. Use it to
build something heavy only once the player scrolls to it, the way a web page
waits for an element to intersect the viewport.

A [Stack](../../components/stack.md#long-lists) does this for its children with
`mount = "intersect"`. Reach for `useIntersect` when the layout is not a Stack:
cards placed by hand on a long track, a map of rooms, a timeline.

## Usage

```luau
local reached = Lucy.useIntersect(target, options?)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `target` | Instance, handle, or a ref or getter of one | required | What to watch. `nil` until it exists is fine |
| `options.enabled` | `MaybeRef<boolean>` | `true` | While `false`, nothing is looked at |
| `options.overscan` | `number` | `1` | How many views beyond each edge of the visible part count as near |

It returns a getter: `reached()` is `false`, then `true` for good.

The target needs a size of its own before anything is built in it, so the list
keeps its length and unbuilt things are not all in view at once. With no scroll
area around the target, `reached()` turns `true` as soon as the target shows.

Like every composable it needs an owner: call it in a component's render, a
scene's build, an effect or an effect scope.

## Example: a season track that builds its cards as you scroll

A hundred reward cards sit side by side on a track that scrolls. Each cell
holds its card's room, and the card is built when the cell is scrolled near:

```luau
local function cell(tier: number)
    local frame = Lucy.ref(nil)
    local reached = Lucy.useIntersect(frame)
    return Lucy.new("Frame")({
        Size = UDim2.fromOffset(120, 160),
        Position = UDim2.fromOffset((tier - 1) * 132, 0),
        BackgroundTransparency = 1,
        [Lucy.instance] = frame,
        Lucy.show(reached, function()
            return buildRewardCard(tier)
        end),
    })
end
```

## Example: waiting until the track has been placed

A track that opens on the player's own tier is scrolled there a moment after it
is built. Until then the cards at its start would count as in view. `enabled`
holds the looking back until the track is where it should be:

```luau
local placed = Lucy.ref(false)
local reached = Lucy.useIntersect(frame, { enabled = placed })

-- once the track has been scrolled to the player's tier
placed(true)
```
