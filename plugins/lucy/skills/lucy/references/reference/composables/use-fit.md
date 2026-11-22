<!-- Made by scripts/skills.ts from docs/reference/composables/use-fit.md. Edit the doc, not this file. -->
# useFit

`Lucy.useFit` returns the scale that makes a GUI object fit the width its
parent has, less the parent's padding: 1 while it fits, less when it is
wider, and never under a floor (0.6 unless you give `min`) so it stays
readable. Bind it to a `UIScale` on the object and it shrinks just enough.

Text's and Stack's `fit` prop use it, so most of the time you set `fit = true`
and never call it yourself. Reach for it for anything else that sizes to its
content and has to keep inside a narrow card: a row of icons, a badge with a
long name.

## Usage

```luau
local scale = Lucy.useFit(target, { min = 0.5 })
```

| Argument | Type | What it is |
|---|---|---|
| `target` | `GuiObject?`, a ref or a getter | The object to fit. A ref or a getter is followed, so it can be set later |
| `options.min` | number | The smallest it goes. Default `0.6` |

### Returns

| Name | Type | What it is |
|---|---|---|
| `scale` | `() -> number` | 1 while it fits, less to fit its parent's width, never under `min` |

The object should size itself to its content (`AutomaticSize`), and its
parent should have a width of its own. A parent that grows with the object
would shrink as the object shrinks, and they would chase each other down to
the floor.

It needs an owner, like every composable: a component's render, a scene's
`build`, or an effect scope.

## Example: Club Lucy's DJ name on the booth sign

The sign is a fixed width; a long DJ name shrinks to fit it rather than
running off the edge:

```luau
local sign = Lucy.new "Frame" {
    Size = UDim2.fromOffset(220, 48),
    BackgroundTransparency = 1,
    Parent = booth,
}
local name = Lucy.new "TextLabel" {
    Text = function() return djName() end,
    AutomaticSize = Enum.AutomaticSize.XY,
    Size = UDim2.fromOffset(0, 0),
    BackgroundTransparency = 1,
    Parent = sign,
}
Lucy.new "UIScale" {
    Scale = Lucy.useFit(name),
    Parent = name,
}
```
