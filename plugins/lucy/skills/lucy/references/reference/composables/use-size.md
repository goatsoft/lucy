<!-- Made by scripts/skills.ts from docs/reference/composables/use-size.md. Edit the doc, not this file. -->
# useSize

`Lucy.useSize` returns a getter for a GUI object's size in the units you lay
it out in: its `AbsoluteSize` without the `UIScale`s on it and above it. Lucy
[scales every scene](../../architecture.md#scaling) to the device, so a
measured `AbsoluteSize` is in screen pixels and does not compare with the
offsets you write; this does. The getter follows the object as it resizes and
as the scene rescales, so a binding that reads it updates by itself.

Use it when a size depends on the room something ends up with: cards as tall
as the body under a header, a column that takes what a row leaves. Don't
listen to `AbsoluteSize` and work out the scale yourself.

## Usage

```luau
local size = Lucy.useSize(target)
```

| Argument | Type | What it is |
|---|---|---|
| `target` | `GuiObject?`, a ref or a getter | The object to measure. A ref or a getter is followed, so it can be set later |

### Returns

| Name | Type | What it is |
|---|---|---|
| `size` | `() -> Vector2` | Its size in layout units. `Vector2.zero` while there is no object or it is not laid out yet |

It needs an owner, like every composable: a component's render, a scene's
`build`, or an effect scope.

## Example: Club Lucy's reward cards fill the body

The body under the header takes whatever height the screen leaves. The cards
are two rows, as tall as that allows:

```luau
local body = Lucy.new "Frame" {
    Position = UDim2.fromOffset(0, HEADER),
    Size = UDim2.new(1, 0, 1, -HEADER),
    BackgroundTransparency = 1,
    Parent = panel,
}
local room = Lucy.useSize(body)
local function card(): number
    return math.max(72, (room().Y - GAP) // 2)
end

Lucy.new "Frame" {
    Size = function()
        return UDim2.fromOffset(card(), card())
    end,
    Parent = body,
}
```
