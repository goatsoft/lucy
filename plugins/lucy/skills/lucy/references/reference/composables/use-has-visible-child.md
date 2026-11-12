<!-- Made by scripts/skills.ts from docs/reference/composables/use-has-visible-child.md. Edit the doc, not this file. -->
# useHasVisibleChild

`Lucy.useHasVisibleChild` returns a getter that is `true` while any GUI child
of a frame has `Visible` on. It follows each child's own `Visible` (not its
ancestors') and children being added and removed, so a binding that reads it
updates by itself.

Use it for a slot whose contents hide themselves: bind the slot's `Visible`
to it and, when everything in it hides, the slot drops out of its list layout,
gap and all. A visible frame with nothing showing still takes a list gap.
Lucy's [Dialog](../../components/dialog.md) does this for its `header` and
`footer` slots.

## Usage

```luau
local visible = Lucy.useHasVisibleChild(target)
```

| Argument | Type | What it is |
|---|---|---|
| `target` | `Instance?`, a ref or a getter | The frame whose children to watch. A ref or a getter is followed, so it can be set later |

### Returns

| Name | Type | What it is |
|---|---|---|
| `visible` | `() -> boolean` | Whether any of its GUI children has `Visible` on. `false` while there is no target. Layouts, paddings and other non GUI children never count |

It looks at direct children only. It needs an owner, like every composable: a
component's render, a scene's `build`, or an effect scope.

## Example: key hints that leave no gap on touch

The hints row hides itself on touch, where there are no keys to show. The bar
that holds it hides with it, so the list above it doesn't keep a gap for it:

```luau
local bar = Lucy.new "Frame" {
    Size = UDim2.fromScale(1, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Parent = panel,
}
Lucy.Stack.new({
    direction = "horizontal",
    visible = function()
        return inputMode() ~= "touch"
    end,
    children = hints,
}).Instance.Parent = bar
Lucy.hydrate(bar) { Visible = Lucy.useHasVisibleChild(bar) }
```
